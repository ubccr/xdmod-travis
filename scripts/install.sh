#!/usr/bin/env bash

script_dir="$(cd "$(dirname $0)" || exit 2; pwd -P)"
qa_dir="$(dirname "$script_dir")"

source "$script_dir/helpers.sh"

# Check that this repo has been set up for Travis correctly and exit if not.
repo_type="$("$script_dir/check-repo-type.sh")"
if [ "$repo_type" == "unknown" ]; then
    echo "Repository has not been properly set up to use XDMoD Travis scripts." >&2
    exit 2
fi

# For the remainder of this script, quit immediately if a command fails.
set -e

# Make sure that we're in the QA directory before continuing...
pushd "$qa_dir" >/dev/null || exit 1
echo "Installing dependencies for '$qa_dir' ..."

echo "Installing Composer dependencies..."
composer install

# Install repo's npm dependencies.
echo "Installing npm dependencies..."
npm install

popd >/dev/null || exit 1
