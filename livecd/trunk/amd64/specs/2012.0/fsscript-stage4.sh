#!/bin/sh
source /tmp/envscript
emerge --deep --update --newuse @world
python-updater
