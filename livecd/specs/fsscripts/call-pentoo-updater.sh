#!/bin/sh
set -ex
source /tmp/envscript

bash -x "$(portageq get_repo_path / pentoo)/scripts/pentoo-updater.sh"
# only python -O and -OO use these
find /usr \( -name '*.opt-1.pyc' -o -name '*.opt-2.pyc' \) -delete
rm -rf /tmp/*
