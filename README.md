# Open XDMoD Quality Assurance Repository

This repository contains scripts and other assets for testing [Open XDMoD](http://open.xdmod.org) and Open XDMoD modules.

## Usage

### Linters

To make use of the linters used by Open XDMoD on your local system, perform the steps below.

1. Clone this repo onto your local system.
1. Install dependencies declared by files in the repo's base directory.
    1. To install Composer dependencies, run `composer install` in the repo's base directory. The programs Composer downloads will then be available in `[xdmod-qa]/vendor/bin`.
    1. To install npm dependencies, run `npm install` in the repo's base directory. The programs npm downloads will then be available in `[xdmod-qa]/node_modules/.bin`.
1. Install the style linter config files to a parent directory of your Open XDMoD repos. Run `[xdmod-qa]/style/install.sh [parent-dir]` to do this easily.

### [Shippable](https://www.shippable.com)

Create a `shippable.yml` file in the root of your module's repository. You can copy / use the template at path [`scripts/template.yml`](scripts/template.yml) to get started.

In `shippable.yml` make sure the following environment variables are set with values applicable to your module:

  - `XDMOD_REALMS`: a comma delimited list of the XDMoD realms your module requires and or provides. 
  - `XDMOD_SOURCE_DIR`: The directory that the XDMoD source code will be checked out to.
  - `XDMOD_INSTALL_DIR`: The directory that the qa scripts will attempt to perform a source install of XDMoD to.
  - `XDMOD_MODULE_DIR`: The directory that contains the XDMoD module source code.
  - `XDMOD_MODULE_NAME`: The name of the XDMoD module that is being tested.
  
Optionally you can set the following (`qa-test-setup.sh` is a helper script that resides in the base XDMoD repo that takes care of checking out & running the qa scripts ): 
  - `QA_BRANCH`: The branch of the qa repo that will be checked out by `qa-test-setup.sh`.
  - `QA_GIT_URL`: The git repo that will be cloned / used by `qa-test-setup.sh` 

#### Custom Test Hooks

If your module needs to perform custom tests or tasks not run by this repo's scripts, you can create custom scripts in your repo with the following paths and they will be run for you at the specified times. (Remember to make your script files executable!)

- `scripts/post-install-test.sh`: This will be run after Shippable has built and installed Open XDMoD and your module. It will not run if building or installing failed. The script's exit code will be used to determine if post-install tests succeeded or failed.

## Versioning

This repository loosely follows [Semantic Versioning](http://semver.org). While exact version numbers will not be assigned to commits, branches will be named for a major version number (e.g. `v1`, `v2`). When breaking changes need to be made, a new branch will be created with the next available major version number and the changes will be made there.
