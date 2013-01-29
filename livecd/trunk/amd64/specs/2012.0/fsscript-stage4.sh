#!/bin/sh
source /tmp/envscript
USE="-directfb" emerge -1 libsdl DirectFB || exit 1
emerge --deep --update --newuse @world || exit 1
python-updater || exit 1
