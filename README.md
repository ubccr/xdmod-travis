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

### [Travis CI](https://travis-ci.org)

Create a `.travis.yml` file in the root of your module's repository. You can use the template below to get started.

```yaml
# Use container-based environment for quicker initialization
sudo: false

# Specify the build matrix
language: php
php:
    - '5.4'
    - '7.0'
    - '7.1.6'
env:
    global:
        - NODE_VERSION=6
        - XDMOD_TEST_ARTIFACTS_MIRROR="$HOME/xdmod-test-artifacts.git"
        - XDMOD_MODULE_DIR="mymodule"
        - XDMOD_MODULE_NAME="My Module"

# Add dependency directories to the Travis cache
cache:
    directories:
        - $HOME/.npm
        - $HOME/.composer/cache
        - /tmp/pear/cache
        - $XDMOD_TEST_ARTIFACTS_MIRROR

# Obtain the shared QA assets before using them.
before_install: git clone --depth=1 --branch="v1" https://github.com/ubccr/xdmod-qa.git .qa

# Delegate the installation step to the shared Travis installation script
install: .qa/travis/install.sh

# Delegate the build step to the shared Travis build script
script: .qa/travis/build.sh
```

In `.travis.yml`, set the following environment variables to values applicable to your module:

- `XDMOD_MODULE_DIR`: The name of the module's subdirectory inside of Open XDMoD directory `open_xdmod/modules`. (e.g. `appkernels`)
- `XDMOD_MODULE_NAME`: The reader-friendly name for your module. (e.g. Application Kernels)

#### Custom Test Hooks

If your module needs to perform custom tests or tasks not run by this repo's scripts, you can create custom scripts in your repo with the following paths and they will be run for you at the specified times. (Remember to make your script files executable!)

- `/.travis/post-install-test.sh`: This will be run after Travis has built and installed Open XDMoD and your module. It will not run if building or installing failed. The script's exit code will be used to determine if post-install tests succeeded or failed.

## Versioning

This repository loosely follows [Semantic Versioning](http://semver.org). While exact version numbers will not be assigned to commits, branches will be named for a major version number (e.g. `v1`, `v2`). When breaking changes need to be made, a new branch will be created with the next available major version number and the changes will be made there.
