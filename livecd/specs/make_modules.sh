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
mkdir -p /dev/shm/portage/rootfs/usr/
rsync -aEXu --delete /catalyst/tmp/portage/portage /dev/shm/portage/rootfs/usr/
mkdir -p /catalyst/tmp/portage/portage/distfiles
mkdir -p /catalyst/tmp/portage/portage/packages
##add the distfiles we want
mkdir -p /dev/shm/distfiles/rootfs/usr/portage/distfiles/
#DISTDIR=/dev/shm/distfiles/ emerge -FO ati-drivers
DISTDIR=/dev/shm/distfiles/ emerge -FO nvidia-drivers
mkdir -p /dev/shm/distfiles/tmp
#cp /dev/shm/distfiles/{*[Ll]inux*,xvba*} /dev/shm/distfiles/tmp/
cp /dev/shm/distfiles/*[Ll]inux* /dev/shm/distfiles/tmp/
rsync -aEXu --progress --delete /dev/shm/distfiles/tmp/  /dev/shm/portage/rootfs/usr/portage/distfiles/
chown root.root /dev/shm/portage/rootfs/usr
chown root.root /dev/shm/portage/rootfs
chown root.root /dev/shm/portage
chown portage.portage -R /dev/shm/portage/rootfs/usr/portage

# make the squashfs module
filename=$(awk '/snapshot:/ {print $3}' /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh)
version="${filename%.*}"
mksquashfs /dev/shm/portage/rootfs/ /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/portage-${version%.*}.lzm -comp xz -Xbcj x86 -b 1048576 -no-recovery -noappend -Xdict-size 1048576
rm -rf /catalyst/tmp/portage/portage/distfiles
rm -rf /catalyst/tmp/portage/portage/packages

##make the pentoo overlay module
layman -s pentoo
mkdir -p /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/
rsync -aEXu --progress --delete /var/lib/layman/pentoo/ /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo/
chown root.root /dev/shm/pentoo_portage/rootfs/var/lib/layman
chown root.root /dev/shm/pentoo_portage/rootfs/var/lib
chown root.root /dev/shm/pentoo_portage/rootfs/var
chown portage.portage -R /dev/shm/pentoo_portage/rootfs/var/lib/layman/pentoo
mksquashfs /dev/shm/pentoo_portage/rootfs/ /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/pentoo_overlay-$(date "+%Y%m%d").lzm -comp xz -Xbcj x86 -b 1048576 -no-recovery -noappend -Xdict-size 1048576

#drop the files into the mirror for the next sync
rsync -aEuh --progress --delete --omit-dir-times /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/ /mnt/mirror/local_mirror/modules/

#make the user mode hack module after the sync, user's don't need to download this separately
#mkdir -p /dev/shm/pentoouser/rootfs/etc/init.d/
#wget https://gitweb.gentoo.org/proj/livecd-tools.git/plain/init.d/fixinittab -O /dev/shm/pentoouser/rootfs/etc/init.d/fixinittab
#sed -i -e '/--autologin/s/root/`id -nu 1000 2>/dev/null || echo root`/' /dev/shm/pentoouser/rootfs/etc/init.d/fixinittab
#if we are going to force the user to set a password, we shouldn't autologin so many terminals
#sed -i 's/2 3 4 5 6//' /dev/shm/pentoouser/rootfs/etc/init.d/fixinittab
#chmod 755 /dev/shm/pentoouser/rootfs/etc/init.d/fixinittab
#chown -R root.root /dev/shm/pentoouser/rootfs/
#mksquashfs /dev/shm/pentoouser/rootfs/ /usr/src/pentoo/pentoo-livecd/livecd/isoroot/modules/pentoouser.lzm -comp xz -Xbcj x86 -b 1048576 -no-recovery -noappend -Xdict-size 1048576
