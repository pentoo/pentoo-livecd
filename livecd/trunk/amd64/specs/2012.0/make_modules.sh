#!/bin/sh

rm -rf /usr/src/pentoo/livecd/trunk/isoroot/modules/*

##make the gentoo portage module
mkdir -p /dev/shm/portage/rootfs/usr/ || exit
rsync -aEXu /var/tmp/portage/snapshot_cache/`awk '/snapshot:/ {print $2}' livecd-stage1_template.spec`/portage /dev/shm/portage/rootfs/usr/ || exit
mksquashfs /dev/shm/portage/rootfs/ /usr/src/pentoo/livecd/trunk/isoroot/modules/portage-`awk '/snapshot:/ {print $2}' livecd-stage1_template.spec`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || exit

##make the pentoo portage module
mkdir -p /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/ || exit
rsync -aEXu /usr/src/pentoo/portage/trunk/ /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/ || exit
mksquashfs /dev/shm/pentoo_portage/rootfs/ /usr/src/pentoo/livecd/trunk/isoroot/modules/pentoo_overlay-`date "+%Y%m%d"`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || exit
