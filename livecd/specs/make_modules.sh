#!/bin/sh

set -e

#IO load is CRUSHING my build system, so if a heavy IO operation is running, hold off on starting the next one
#rsync is used to copy from livecd-stage1 to livecd-stage2
while ps aux | grep "[r]sync -a --delete /catalyst/"
do
	echo IO at max, sleeping 2m
	sleep 2m
done
#this is unpacking a stage
while ps aux | grep "[t]ar -I pixz -xpf /catalyst/"
do
	echo IO at max, sleeping 2m
	sleep 2m
done
#this is packing a stage
while ps aux | grep "[t]ar -I pixz -cpf /catalyst/"
do
	echo IO at max, sleeping 2m
	sleep 2m
done
#removing tempfiles when complete
while ps aux | grep "[r]m -rf /catalyst/tmp/"
do
	echo IO at max, sleeping 2m
	sleep 2m
done
#bug 461824 script (grep of majority of stage)
while ps aux | grep "[g]rep -r _portage_reinstall_"
do
	echo IO at max, sleeping 2m
	sleep 2m
done
#end excessive IO handling

rm -rf /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/*

##make the gentoo portage module
rm -rf /dev/shm/portage/rootfs/var/db/repos/gentoo
mkdir -p /dev/shm/portage/rootfs/var/db/repos/gentoo
rsync -aEXu --delete /catalyst/tmp/repos/portage/* /dev/shm/portage/rootfs/var/db/repos/gentoo
##add the distfiles we want
mkdir -p /dev/shm/distfiles/rootfs/var/cache/distfiles/
#make sure it's all in the local store too
ACCEPT_LICENSE="Broadcom" emerge -FO b43-firmware b43legacy-firmware
ACCEPT_KEYWORDS="-* amd64" emerge -fO nvidia-drivers
#ACCEPT_KEYWORDS="-* x86" linux32 emerge -FO nvidia-drivers

##if we don't clean this out it gets big.  this box doesn't reboot much
rm -rf /dev/shm/distfiles/*
ACCEPT_LICENSE="Broadcom" DISTDIR="/dev/shm/distfiles/" emerge -FO b43-firmware b43legacy-firmware
DISTDIR="/dev/shm/distfiles/" ACCEPT_KEYWORDS="-* amd64" emerge -fO nvidia-drivers
#DISTDIR="/dev/shm/distfiles/" ACCEPT_KEYWORDS="-* x86" linux32 emerge -FO nvidia-drivers
#remove the older version of 64 bit driver
rm -f /dev/shm/distfiles/NVIDIA-Linux-x86_64-390.??.run
rm -rf /dev/shm/distfiles/tmp
mkdir -p /dev/shm/distfiles/tmp
#cp /dev/shm/distfiles/{*[Ll]inux*,xvba*} /dev/shm/distfiles/tmp/
cp /dev/shm/distfiles/*[Ll]inux-x86* /dev/shm/distfiles/tmp/
cp /dev/shm/distfiles/nvidia-settings-*.tar.bz2 /dev/shm/distfiles/tmp/
cp /dev/shm/distfiles/broadcom-wl* /dev/shm/distfiles/tmp/
cp /dev/shm/distfiles/wl_apsta-3.130.20.0.o /dev/shm/distfiles/tmp
mkdir -p /dev/shm/portage/rootfs/var/cache/distfiles
rsync -aEXu --progress --delete /dev/shm/distfiles/tmp/  /dev/shm/portage/rootfs/var/cache/distfiles/
#double check that we have what we expect in here so I don't mess up again
DISTDIR=/dev/shm/portage/rootfs/var/cache/distfiles/ emerge -fO nvidia-drivers
chown root.root /dev/shm/portage/rootfs/var/cache
chown root.root /dev/shm/portage/rootfs/var
chown root.root /dev/shm/portage/rootfs
chown root.root /dev/shm/portage
chown portage.portage -R /dev/shm/portage/rootfs/var/cache/distfiles
## add the pentoo overlay
mkdir -p /dev/shm/portage/rootfs/var/db/repos/pentoo/
rsync -aEXu --progress --delete /var/db/repos/pentoo/ /dev/shm/portage/rootfs/var/db/repos/pentoo/
chown root.root /dev/shm/portage/rootfs/var/db/repos
chown root.root /dev/shm/portage/rootfs/var/db
chown root.root /dev/shm/portage/rootfs/var
chown portage.portage -R /dev/shm/portage/rootfs/var/db/repos/pentoo
# make the unified squashfs module
mksquashfs /dev/shm/portage/rootfs/ /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/portage_and_overlay-$(date "+%Y%m%d").lzm -comp xz -Xbcj x86 -b 1048576 -no-recovery -noappend -Xdict-size 1048576

#drop the files into the mirror for the next sync
rsync -aEuh --progress --delete --omit-dir-times /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/ /mnt/mirror/local_mirror/modules/
