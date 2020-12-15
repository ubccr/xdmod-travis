#!/usr/bin/env bash
#
# Perform travis tests. Use cases:
#
# 1. Compare files between two commits (e.g., a current and previous commit on a pull request)
# 2. Compare files that are staged but not yet commited to the latest commit of an upstream branch
#    (e.g., prior to committing)

script_dir="$(cd "$(dirname $0)" || exit 2; pwd -P)"
qa_dir="$(dirname "$script_dir")"

source "$script_dir/helpers.sh"

# Remote branch that we want to compare against. This is used if travis has not specified a commit
# or commit range
remote_branch=

# 1 = run only style and syntax tests
only_style_tests=0

function usage() {
    cat <<USAGE
Usage: $0
    -r | --remote <remote_git_branch>
    Set the remote git branch to compare against. Defaults to the upstream HEAD.

    -s | --only-style-tests
    Run syntax and style tests only.
USAGE
}

while [ "$1" != "" ]; do
    case $1 in
        -r | --remote )
            shift
            remote_branch=$1
            git rev-parse --verify --quiet $remote_branch &> /dev/null
            if [ $? -ne 0 ]; then
                echo "Could not resolve remote branch: $remote_branch" >&2
                exit 1
            fi
            ;;
        -s | --only-style-tests )
            echo "Running only style tests"
            only_style_tests=1
            ;;
        * )
            usage
            exit 1
            ;;
    esac
    shift
done

# Check to see if there is a `COMMIT_RANGE` env variable defined already, if not then we'll attempt to construct one.
if [ -z "$COMMIT_RANGE" ]; then

    # If `remote_branch` is not not specified on the command line, then attempt to identify if the repo has an `upstream`
    # branch that we can use instead.
    if [ -z "$remote_branch" ]; then
        # Not specified
        upstream=$(git remote|grep upstream)
        if [ $? -eq 0 ]; then
            # Note that sed on OSX is bsd and not GNU so we must use [[:space:]] instead of \s
            remote_branch=$(git remote -v show $upstream | grep 'HEAD branch' | sed 's/[[:space:]]*HEAD branch:[[:space:]]*//')
            # Be sure to include the full path to the upstream remote in the branch name or we might
            # be looking at a local branch of the same name!
            echo $remote_branch | egrep "^$upstream"
            if [ $? -eq 1 ]; then
                remote_branch="$upstream/$remote_branch"
            else
                echo "Could not discover branch for comparison, no remote 'upstream' configured." >&2
                echo "Specify with --remote" >&2
                exit 1
            fi
        else
            echo "Could not discover branch for comparison, no remote 'upstream' configured." >&2
            echo "Specify with --remote" >&2
            exit 1
        fi
    fi

    # We must update the local metadata for the remote or we may not get the latest commit
    git remote update $upstream &> /dev/null

    # attempt to retrieve the remote_branch commit to be used in the COMMIT_RANGE
    remote_branch_commit=$(git rev-parse --verify --quiet $remote_branch)

    if [ $? != "0" ]; then
      echo "Unable to continue, failed to determine commit for remote branch: $remote_branch"
      exit 1
    fi

    # The range is the latest commit on the remote branch and HEAD on this branch
    COMMIT_RANGE="$remote_branch_commit...HEAD"

    echo "Comparing HEAD to $remote_branch ($remote_branch_commit)"
fi

# Get the type of this XDMoD repository.
repo_type="$("$script_dir/check-repo-type.sh")"

new_bin_paths="$(pwd)/vendor/bin:$(pwd)/node_modules/.bin"
if [ "$repo_type" == "module" ]; then
    new_bin_paths="$new_bin_paths:$XDMOD_SOURCE_DIR/vendor/bin"
fi
new_bin_paths="$new_bin_paths:$qa_dir/vendor/bin:$qa_dir/node_modules/.bin"
PATH="$new_bin_paths:$PATH"
export PATH

# Check whether the start of the commit range is available.
# If it is not available, try fetching the complete history.
commit_range_start="$(echo "$COMMIT_RANGE" | sed -E 's/^([a-fA-F0-9]+).*/\1/')"
if ! git show --format='' --no-patch "$commit_range_start" &>/dev/null; then
    git fetch --unshallow

    # If it's still unavailable (likely due a push build caused by a force push),
    # tests based on what has changed cannot be run.
    if ! git show --format='' --no-patch "$commit_range_start" &>/dev/null; then
        echo "Could not find commit range start ($commit_range_start)." >&2
        echo "Tests based on changed files cannot run." >&2
        exit 1
    fi
fi

# Extra tests will also get tested when checking for POSIX compliance
# so initialize it here
posix_fails=()
extra_exit_value=0

# Get the files changed by this commit (excluding deleted files). If there is no COMMIT_RANGE
# then it will show currently staged files. This is equivalent to HEAD.
files_changed=()
while IFS= read -r -d $'\0' file; do
  if file $file | grep -q "text" ; then
      last_char=$(tail -c 1 "$file")
      if [ -n "$last_char" ]; then
          posix_fails+=("$file")
          extra_exit_value=2
      fi
  fi
    # Do not include test artifact files
    if [[ ! $file =~ ^tests/artifacts ]]; then
        files_changed+=("$file")
    fi
done < <(git -c diff.renameLimit=6000 diff --name-only --diff-filter=dar -z "$COMMIT_RANGE")

# Separate the changed files by language.
php_files_changed=()
js_files_changed=()
json_files_changed=()
other_files_changed=()
php_regex='\bphp script\b'
for file in "${files_changed[@]}"; do
    if [[ "$file" == *.php ]] || [[ "$(file -b -k "$file")" =~ $php_regex ]]; then
        php_files_changed+=("$file")
    elif [[ "$file" == *.js ]]; then
        js_files_changed+=("$file")
    elif [[ "$file" == *.json ]]; then
        json_files_changed+=("$file")
    else
        other_files_changed+=("$file")
    fi
done

# Get any added files by language
php_files_added=()
js_files_added=()
json_files_added=()
while IFS= read -r -d $'\0' file; do
    if file $file | grep -q "text" ; then
        last_char=$(tail -c 1 "$file")
        if [ -n "$last_char" ]; then
            posix_fails+=("$file")
            extra_exit_value=2
        fi
    fi
    # Do not include test artifact files
    if [[ $file =~ ^tests/artifacts ]]; then
        continue
    fi
    if [[ "$file" == *.php ]]; then
        php_files_added+=("$file")
    elif [[ "$file" == *.js ]]; then
        js_files_added+=("$file")
    elif [[ "$file" == *.json ]]; then
        json_files_added+=("$file")
    fi
done < <(git -c diff.renameLimit=6000 diff --name-only --diff-filter=AR -z "$COMMIT_RANGE")

# Find tracked files that were added (staged) or modified but not staged

if [ -n "$remote_branch" ]; then
    while IFS= read -r -d $'\0' line; do
        # Note that a new file that has been added and subsequently modfified will be "AM" and we
        # will treat these as added.

        # Note that $line must be quoted when echoed or echo will remove leading spaces!
        file=$(echo "$line" | egrep '^[[:space:]]*(A|M)' | cut -c 4-)
        operation=$(echo "$line" | egrep '^[[:space:]]*(A|M)' | cut -c -2)

        if [ "A" = "$(echo "$operation" | cut -c 1)" ]; then
            if [[ "$file" == *.php ]]; then
                php_files_added+=("$file")
            elif [[ "$file" == *.js ]]; then
                js_files_added+=("$file")
            elif [[ "$file" == *.json ]]; then
                json_files_added+=("$file")
            fi
        elif [ "M" = "$(echo "$operation" | cut -c 2)" ]; then
            if [[ "$file" == *.php ]]; then
                php_files_changed+=("$file")
            elif [[ "$file" == *.js ]]; then
                js_files_changed+=("$file")
            elif [[ "$file" == *.json ]]; then
                json_files_changed+=("$file")
            fi
        fi

    done < <(git status -sz -uno)
fi

# Set up exit value for whole script and function for updating it.
script_exit_value=0

# Updates the exit value for the script as a whole.
#
# Args:
#     $1: The section exit value to consider.
function update_script_exit_value() {
    if [ $1 == 0 ]; then
        return 0
    fi
    script_exit_value=$1
}

# Perform syntax tests.
start_travis_fold syntax
echo "Running syntax tests..."

syntax_exit_value=0
for file in "${php_files_changed[@]}" "${php_files_added[@]}"; do
    php -l "$file" >/dev/null
    if [ $? != 0 ]; then
        syntax_exit_value=2
    fi
done

eslint_args=""
#if [ -n "$XDMOD_SOURCE_DIR" ]; then
#  eslint_args="-o ./shipppable/testresults/xdmod-eslint-$(basename "$file").xml -f junit"
#fi

for file in "${js_files_changed[@]}" "${js_files_added[@]}"; do
    eslint "$file" "$eslint_args"
    if [ $? != 0 ]; then
        syntax_exit_value=2
    fi
done
for file in "${json_files_changed[@]}" "${json_files_added[@]}"; do
    jsonlint --quiet --compact "$file"
    if [ $? != 0 ]; then
        syntax_exit_value=2
    fi
done

update_script_exit_value $syntax_exit_value
end_travis_fold syntax

print_section_results "Syntax tests" $syntax_exit_value

# Perform style tests.
start_travis_fold style
echo "Running style tests..."

# Install style files.
"$qa_dir/style/install.sh" .

style_exit_value=0
for file in "${php_files_changed[@]}"; do
    phpcs "$file" --report=json > "$file.lint.new.json"
    if [ $? != 0 ]; then
        git show "$commit_range_start:$file" | phpcs --stdin-path="$file" --report=json > "$file.lint.orig.json"
        lint-diff "$file.lint.orig.json" "$file.lint.new.json"
        if [ $? != 0 ]; then
            style_exit_value=2
        fi
        rm "$file.lint.orig.json"
    fi
    rm "$file.lint.new.json"
done
for file in "${php_files_added[@]}"; do
    phpcs "$file"
    if [ $? != 0 ]; then
        style_exit_value=2
    fi
done
for file in "${js_files_changed[@]}"; do
    eslint_rule_override='{no-underscore-dangle: 0, indent: 0}'
    eslint --rule "$eslint_rule_override" "$file" -f json > "$file.lint.new.json"
    if [ $? != 0 ]; then
        git show "$commit_range_start:$file" | eslint --rule "$eslint_rule_override" --stdin --stdin-filename "$file" -f json > "$file.lint.orig.json"
        lint-diff "$file.lint.orig.json" "$file.lint.new.json"
        if [ $? != 0 ]; then
            style_exit_value=2
        fi
        rm "$file.lint.orig.json"
    fi
    rm "$file.lint.new.json"
done
for file in "${js_files_added[@]}"; do
    eslint "$file"
    if [ $? != 0 ]; then
        style_exit_value=2
    fi
done

update_script_exit_value $style_exit_value
end_travis_fold style

print_section_results "Style tests" $style_exit_value

# Perform extra tests
start_travis_fold extra
echo "Running extra tests..."

for file in "${php_files_changed[@]}" "${js_files_changed[@]}" "${json_files_changed[@]}"; do
    gdiff=$(git diff -w --ignore-blank-lines $commit_range_start -- $file)
    if [ -z "$gdiff" ]; then
        echo "$file only contains whitespace changes"
        extra_exit_value=2
    fi
done

if ! git diff --check $COMMIT_RANGE ':(exclude)*.sql';
then
    echo "git diff --check failed"
    extra_exit_value=2
fi

if array_contains json_files_changed 'composer.json'; then
    # retrieve what composer looked like originally
    git show "$commit_range_start:composer.json" > composer.orig.json

    # determine whether or not `composer.json` has been changed. If the script
    # exits w/ a 0 then there has been no change. If it exits with anything
    # else then we need to make sure that `composer.lock` has been updated.
    python "$script_dir/composer_check.py"

    if [ $? != 0 ]; then
        if ! array_contains other_files_changed 'composer.lock'; then
            echo "composer.json file changed, but no corresponding change to the lock file"
            extra_exit_value=2
        fi
    fi

    # Make sure to remove the previously generated `original` file.
    rm composer.orig.json
fi

for file in "${posix_fails[@]}"; do
  echo "$file is not POSIX compliant (missing EOF newline)"
done

update_script_exit_value $extra_exit_value
end_travis_fold extra

print_section_results "Extra tests" $extra_exit_value

if [ $only_style_tests -eq 1 ]; then
    exit 0
fi

# Perform unit tests.
start_travis_fold unit
echo "Running unit tests..."

unit_exit_value=0
php_unit_test_path="tests/unit/runtests.sh"
php_unit_test_args=""

if [ "$repo_type" != "core" ]; then
    php_unit_test_path="tests/unit_tests/runtests.sh"
fi

if [ -n "$SHIPPABLE_BUILD_DIR" ]; then
  php_unit_test_path="$SHIPPABLE_BUILD_DIR/tests/unit/runtests.sh"
  php_unit_test_args="--junit-output-dir $SHIPPABLE_BUILD_DIR/shippable/testresults"
fi

if [ -e "$php_unit_test_path" ]; then
    $php_unit_test_path "$php_unit_test_args"
    if [ $? != 0 ]; then
        unit_exit_value=2
    fi
fi

phantom_unit_test_path="html/unit_tests/phantom.js"
if [ -e "$phantom_unit_test_path" ]; then
    phantomjs "$phantom_unit_test_path"
    if [ $? != 0 ]; then
        unit_exit_value=2
    fi
fi

update_script_exit_value $unit_exit_value
end_travis_fold unit

print_section_results "Unit tests" $unit_exit_value

# Perform build test.
start_travis_fold build
echo "Running build test..."

build_exit_value=0

echo "Building Open XDMoD..."
build_package_path="$XDMOD_SOURCE_DIR/open_xdmod/build_scripts/build_package.php"
"$build_package_path" --module xdmod
if [ $? != 0 ]; then
    build_exit_value=2
fi

if [ "$repo_type" == "module" ]; then
    echo "Building $XDMOD_MODULE_NAME module..."
    "$build_package_path" --module "$XDMOD_MODULE_NAME"
    if [ $? != 0 ]; then
        build_exit_value=2
    fi
fi

update_script_exit_value $build_exit_value
end_travis_fold build

print_section_results "Build" $build_exit_value

# If build failed, skip remaining tests.
if [ $build_exit_value != 0 ]; then
    echo "Skipping remaining tests."
    exit $script_exit_value
fi

# Perform installation test.
start_travis_fold install
echo "Running installation test..."

pushd . >/dev/null # Preserve starting directory in stack

install_exit_value=0

echo "Installing Open XDMoD..."
build_dir="$XDMOD_SOURCE_DIR/open_xdmod/build"
cd "$build_dir" || exit 2
xdmod_tar="$(find . -regex '^\./xdmod-[0-9]+[^/]*\.tar\.gz$')"
tar -xf "$xdmod_tar"
cd "$(basename "$xdmod_tar" .tar.gz)" || exit 2
./install --prefix="$XDMOD_INSTALL_DIR"
if [ $? != 0 ]; then
    install_exit_value=2
fi

if [ "$repo_type" == "module" ]; then
    echo "Installing $XDMOD_MODULE_NAME module..."
    cd .. || exit 2
    module_tar="$(find . -regex "^\./xdmod-${XDMOD_MODULE_NAME}-[0-9]+[^/]*\.tar\.gz$")"
    tar -xf "$module_tar"
    cd "$(basename "$module_tar" .tar.gz)" || exit 2
    ./install --prefix="$XDMOD_INSTALL_DIR"
    if [ $? != 0 ]; then
        install_exit_value=2
    fi
fi

popd >/dev/null # Return to starting directory

update_script_exit_value $install_exit_value
end_travis_fold install

print_section_results "Installation" $install_exit_value

# If installation failed, skip remaining tests.
if [ $install_exit_value != 0 ]; then
    echo "Skipping remaining tests."
    exit $script_exit_value
fi

# Perform post-install tests, if any.
post_install_path=".travis/post-install-test.sh"
if [ -e "$post_install_path" ]; then
    start_travis_fold post-install
    echo "Running repo-specific post-install tests..."

    "$post_install_path"
    post_install_exit_value=$?

    update_script_exit_value $post_install_exit_value
    end_travis_fold post-install

    print_section_results "Repo-specific post-install tests" $post_install_exit_value
fi

# Exit with the overall script exit code.
exit $script_exit_value
