#!/bin/sh
. /etc/profile
env-update
. /tmp/envscript
echo 'VIDEO_CARDS=""' >> /etc/portage/make.conf
emerge --deep --update --newuse @world
emerge --depclean --with-bdeps=n
emerge --buildpkg=y --usepkg=n @preserved-rebuild

if [ "${clst_subarch}" = "pentium-m" ]; then
  PROFILE_ARCH="x86"
elif [ "${clst_subarch}" = "amd64" ]; then
  PROFILE_ARCH="amd64_r1"
else
	echo "failed to handle arch"
	/bin/bash
fi
if gcc -v 2>&1 | grep -q Hardened
then
	hardening=hardened
else
  hardening=default
fi
eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH}/binary
eselect news read
