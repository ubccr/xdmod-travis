#!/usr/bin/env bash

# Determine the type of repo this is being run in using environment variables.
#
# Types expected are core (Open XDMoD) or module (App Kernels, SUPReMM, etc.).
# If the type cannot be determined or required variables are missing, this
# script will report type "unknown" and exit with a non-zero exit code.
#
# Output: String representing type of repo. ("core", "module", or "unknown")
# Exit Code: 0 if repo type known; 2 if repo type unknown.

# Determine if a variable is a truthy value.
#
# Truthy is defined as case-insensitive equal to "true", "yes", or "on".
#
# Args:
#     $1: The variable to check.
# Returns:
#     0 if variable is truthy, otherwise non-zero number.
function var_is_true() {
    lowercase_variable="$(echo "$1" | tr "[:upper:]" "[:lower:]")"
    for truth_value in "true" "yes" "on"; do
        if [ "$lowercase_variable" == "$truth_value" ]; then
            return 0
        fi
    done

    return 2
}

exit_code=0
if [ -n "$XDMOD_IS_CORE" ] && var_is_true "$XDMOD_IS_CORE"; then
    repo_type="core"
elif [ -n "$XDMOD_MODULE_NAME" ] && [ -n "$XDMOD_MODULE_DIR" ]; then
    repo_type="module"
else
    repo_type="unknown"
    exit_code=2
fi

echo "$repo_type"
exit $exit_code
