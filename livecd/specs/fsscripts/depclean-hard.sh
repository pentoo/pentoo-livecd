#!/bin/sh
source /etc/profile
env-update
source /tmp/envscript
emerge --depclean --with-bdeps=n
