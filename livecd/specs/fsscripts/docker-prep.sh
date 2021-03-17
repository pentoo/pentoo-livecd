#!/bin/sh
source /etc/profile
env-update
source /tmp/envscript
echo 'VIDEO_CARDS=""' >> /etc/portage/make.conf
emerge --deep --update --newuse @world
emerge --depclean --with-bdeps=n
