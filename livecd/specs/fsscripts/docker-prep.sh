#!/bin/sh
set -ex
HOME=/tmp
. /etc/profile
env-update
. /tmp/envscript
echo 'VIDEO_CARDS=""' >> /etc/portage/make.conf
emerge --deep --update --newuse --changed-deps @world
emerge --depclean --with-bdeps=n
emerge --buildpkg=y --usepkg=n @preserved-rebuild

if [ "${clst_subarch}" = "pentium-m" ]; then
  PROFILE_ARCH="x86"
elif [ "${clst_subarch}" = "amd64" ]; then
  PROFILE_ARCH="amd64"
else
	echo "failed to handle arch"
  exit 1
fi
if gcc -v 2>&1 | grep -q Hardened
then
	hardening=hardened
else
  hardening=default
fi
eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH}/23.0/split-usr/binary
eselect news read
# only python -O and -OO use these
find /usr \( -name '*.opt-1.pyc' -o -name '*.opt-2.pyc' \) -delete
rm -rf /tmp/*
DISTDIR="$(portageq envvar DISTDIR)"
if [ -d "${DISTDIR:-}" ]; then rm -rf "${DISTDIR:?}"/* ; fi
PKGDIR="$(portageq envvar PKGDIR)"
if [ -d "${PKGDIR:-}" ]; then rm -rf "${PKGDIR:?}"/* ; fi
true
