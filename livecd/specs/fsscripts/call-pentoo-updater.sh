#!/bin/sh
set -ex
source /tmp/envscript

bash -x "$(portageq get_repo_path / pentoo)/scripts/pentoo-updater.sh"
