#!/usr/bin/env bash

# Install style config files into the given directory.
#
# Style configs will be installed by creating symbolic links in the given
# directory to the actual files in the style subfolder. Installation will be
# skipped for any linter which already has a style file in the directory.
# Broken symbolic links do not count as existing files and will be removed.
#
# Args:
#     $1: The directory to place the links in.

script_dir="$(cd "$(dirname $0)" || exit 2; pwd -P)"

# Check the validity of the command-line arguments.
target_dir="$1"
if [ -z "$target_dir" ]; then
    echo "No target directory given." >&2
    exit 1
fi
if ! [ -d "$target_dir" ]; then
    echo "Target directory given is not a directory." >&2
    exit 1
fi

# Check if the given file paths exist in the target directory.
#
# If any path is a broken symbolic link, it will be removed.
#
# Args:
#     $1...$n Paths to check within the target directory.
# Returns:
#     0 if any paths exist, non-zero otherwise.
function check_paths_in_target_dir() {
    for path in "$@"; do
        target_path="$target_dir/$path"
        if [ -h "$target_path" ] && ! [ -e "$target_path" ]; then
            rm "$target_path"
            continue
        fi
        if [ -e "$target_path" ]; then
            return 0
        fi
    done
    return 2
}

# Install PHP_CodeSniffer files.
if ! check_paths_in_target_dir '.phpcs.xml' '.phpcs.xml.dist' 'phpcs.xml' 'phpcs.xml.dist'; then
    ln -s "$script_dir/configs/phpcs.xml" "$target_dir/phpcs.xml"
fi

# Install ESLint files.
if ! check_paths_in_target_dir '.eslintrc.js' '.eslintrc.yaml' '.eslintrc.yml' '.eslintrc.json' '.eslintrc'; then
    ln -s "$script_dir/configs/.eslintrc.json" "$target_dir/.eslintrc.json"
fi
