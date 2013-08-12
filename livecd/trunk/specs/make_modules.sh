#!/bin/sh
rm -rf /usr/src/pentoo/livecd/trunk/isoroot/modules/*

##make the gentoo portage module
mkdir -p /dev/shm/portage/rootfs/usr/
mkdir -p /catalyst/tmp/portage/portage/distfiles
mkdir -p /catalyst/tmp/portage/portage/metadata
rsync -aEXu --delete /catalyst/tmp/portage/portage /dev/shm/portage/rootfs/usr/ || exit
mksquashfs /dev/shm/portage/rootfs/ /usr/src/pentoo/livecd/trunk/isoroot/modules/portage-`awk '/snapshot:/ {print $3}' build_spec.sh`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || exit
rm -rf /catalyst/tmp/portage/portage/distfiles
rm -rf /catalyst/tmp/portage/portage/metadata

##make the pentoo portage module
layman -s pentoo
mkdir -p /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/ || exit
rsync -aEXu --delete /var/lib/layman/pentoo/ /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/ || exit
mksquashfs /dev/shm/pentoo_portage/rootfs/ /usr/src/pentoo/livecd/trunk/isoroot/modules/pentoo_overlay-`date "+%Y%m%d"`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || exit

##make the zdistfiles module, just one for now, too ugly to make two
mkdir -p /dev/shm/distfiles/rootfs/usr/portage/distfiles/
DISTDIR=/dev/shm/distfiles/ emerge -FO ati-drivers || exit
DISTDIR=/dev/shm/distfiles/ emerge -FO nvidia-drivers || exit
mkdir -p /dev/shm/distfiles/tmp
cp /dev/shm/distfiles/{*[Ll]inux*,xvba*} /dev/shm/distfiles/tmp
chown portage.portage -R /dev/shm/distfiles/tmp/
rsync -aEXu --delete /dev/shm/distfiles/tmp/  /dev/shm/distfiles/rootfs/usr/portage/distfiles/ || exit
mksquashfs /dev/shm/distfiles/rootfs/ /usr/src/pentoo/livecd/trunk/isoroot/modules/zdistfiles-`date "+%Y%m%d"`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || exit
