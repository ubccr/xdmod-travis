#!/usr/bin/env bash

# Travis helper functions and variables that can be included by other shell scripts.
#
# For all variables to be set properly, this must be run with the repo's
# directory as the current directory.

script_dir="$(cd "$(dirname $0)" || exit 2; pwd -P)"
repo_type="$("$script_dir/check-repo-type.sh" 2>/dev/null)"

# Start a foldable section of output in the Travis log.
#
# Args:
#     $1: An identifier for the foldable section.
function start_travis_fold() {
    echo "travis_fold:start:$1"
}

# End a foldable section of output in the Travis log.
#
# Args:
#     $1: The identifier for the foldable section to end.
function end_travis_fold() {
    echo "travis_fold:end:$1"
}

# Print the results for a section of tests.
#
# Args:
#     $1: The name of the section.
#     $2: The exit code for the section.
function print_section_results() {
    section_name="$1"
    section_exit_code=$2

    if [ $section_exit_code == 0 ]; then
        echo -e "$(tput setaf 2)$section_name succeeded"'!'"$(tput sgr0)\n"
    else
        echo -e "$(tput setaf 1)$section_name failed.$(tput sgr0)\n"
    fi
}

function array_contains() {
    local haystack="$1[@]"
    local needle=$2
    local in=1
    for element in "${!haystack}"; do
        if [[ $element == $needle ]]; then
            in=0
            break
        fi
    done
    return $in
}

# Set the location of the Open XDMoD source code.
if [ -z "$XDMOD_SOURCE_DIR" ]; then
    XDMOD_SOURCE_DIR="$(pwd)"
    if [ "$repo_type" == "module" ]; then
        XDMOD_SOURCE_DIR="$(dirname "$XDMOD_SOURCE_DIR")/xdmod"
    fi
    export XDMOD_SOURCE_DIR
fi

# Set the location where Open XDMoD will be installed.
if [ -z "$XDMOD_INSTALL_DIR" ]; then
    XDMOD_INSTALL_DIR="$HOME/xdmod-install"
    export XDMOD_INSTALL_DIR
fi
