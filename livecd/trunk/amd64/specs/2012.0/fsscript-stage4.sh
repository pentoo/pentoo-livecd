#!/bin/sh
unlink /etc/make.profile
eselect python set 2.7
eselect python set 1
python-updater
