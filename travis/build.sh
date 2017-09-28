#!/usr/bin/env bash

# Perform Travis tests.

script_dir="$(cd "$(dirname $0)" || exit 2; pwd -P)"
qa_dir="$(dirname "$script_dir")"

source "$script_dir/helpers.sh"

# Get the type of this XDMoD repository.
repo_type="$("$script_dir/check-repo-type.sh")"

new_bin_paths="$(pwd)/vendor/bin:$(pwd)/node_modules/.bin"
if [ "$repo_type" == "module" ]; then
    new_bin_paths="$new_bin_paths:$XDMOD_SOURCE_DIR/vendor/bin"
fi
new_bin_paths="$new_bin_paths:$qa_dir/vendor/bin:$qa_dir/node_modules/.bin"
PATH="$new_bin_paths:$PATH"
export PATH

if [ -n "$NODE_VERSION" ]; then
    source ~/.nvm/nvm.sh
    nvm use "$NODE_VERSION"
    echo
fi

# Fix for Travis not specifying a range if testing the first commit of
# a new branch on push
if [ -z "$TRAVIS_COMMIT_RANGE" ]; then
    TRAVIS_COMMIT_RANGE="$(git rev-parse --verify --quiet "${TRAVIS_COMMIT}^1")...${TRAVIS_COMMIT}"
fi

# Check whether the start of the commit range is available.
# If it is not available, try fetching the complete history.
commit_range_start="$(echo "$TRAVIS_COMMIT_RANGE" | sed -E 's/^([a-fA-F0-9]+).*/\1/')"
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

# Get the files changed by this commit (excluding deleted files).
files_changed=()
while IFS= read -r -d $'\0' file; do
    files_changed+=("$file")
done < <(git diff --name-only --diff-filter=da -z "$TRAVIS_COMMIT_RANGE")

# Separate the changed files by language.
php_files_changed=()
js_files_changed=()
json_files_changed=()
for file in "${files_changed[@]}"; do
    if [[ "$file" == *.php ]]; then
        php_files_changed+=("$file")
    elif [[ "$file" == *.js ]]; then
        js_files_changed+=("$file")
    elif [[ "$file" == *.json ]]; then
        json_files_changed+=("$file")
    fi
done

# Get any added files by language
php_files_added=()
js_files_added=()
json_files_added=()
while IFS= read -r -d $'\0' file; do
    if [[ "$file" == *.php ]]; then
        php_files_added+=("$file")
    elif [[ "$file" == *.js ]]; then
        js_files_added+=("$file")
    elif [[ "$file" == *.json ]]; then
        json_files_added+=("$file")
    fi
done < <(git diff --name-only --diff-filter=A -z "$TRAVIS_COMMIT_RANGE")

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
for file in "${js_files_changed[@]}" "${js_files_added[@]}"; do
    eslint --no-eslintrc "$file"
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

npm install https://github.com/jpwhite4/lint-diff/tarball/master

style_exit_value=0
for file in "${php_files_changed[@]}"; do
    phpcs "$file" --report=json > "$file.lint.new.json"
    if [ $? != 0 ]; then
        git show "$commit_range_start:$file" | phpcs --stdin-path="$file" --report=json > "$file.lint.orig.json"
        ./node_modules/.bin/lint-diff "$file.lint.orig.json" "$file.lint.new.json"
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
    eslint "$file" -f json > "$file.lint.new.json"
    if [ $? != 0 ]; then
        git show "$commit_range_start:$file" | eslint --stdin --stdin-filename "$file" -f json > "$file.lint.orig.json"
        ./node_modules/.bin/lint-diff "$file.lint.orig.json" "$file.lint.new.json"
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

# Perform unit tests.
start_travis_fold unit
echo "Running unit tests..."

unit_exit_value=0
php_unit_test_path="tests/unit_tests/runtests.sh"
if [ "$repo_type" == "core" ]; then
    php_unit_test_path="open_xdmod/modules/xdmod/$php_unit_test_path"
    if ! [ -e "$php_unit_test_path" ]; then
        php_unit_test_path="open_xdmod/modules/xdmod/tests/runtests.sh"
    fi
fi
if [ -e "$php_unit_test_path" ]; then
    "$php_unit_test_path"
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
    "$build_package_path" --module "$XDMOD_MODULE_DIR"
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
    module_tar="$(find . -regex "^\./xdmod-${XDMOD_MODULE_DIR}-[0-9]+[^/]*\.tar\.gz$")"
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
