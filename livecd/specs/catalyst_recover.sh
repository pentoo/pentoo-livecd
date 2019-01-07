#!/bin/sh

stagepath=/catalyst/tmp/$(grep "rel_type:" "${1}" | awk '{print $2}')/$(grep "target:" "${1}" | awk '{print $2}')-$(grep "subarch:" "${1}" | awk '{print $2}')-$(grep "version_stamp:" "${1}" | awk '{print $2}')
pkgcache_path=$(grep "pkgcache_path:" "${1}" | awk '{print $2}')

mount --bind /proc "${stagepath}"/proc
mount --bind /dev "${stagepath}"/dev
mount --bind /dev/pts "${stagepath}"/dev/pts
mount --bind /usr/portage "${stagepath}"/usr/portage
mount --bind "${pkgcache_path}" "${stagepath}"/usr/portage/packages
PS1="chroot ${PS1}" linux32 chroot "${stagepath}" /bin/bash
umount "${stagepath}"/proc
umount -l "${stagepath}"/dev/pts
umount -l "${stagepath}"/dev
umount "${stagepath}"/usr/portage/packages
umount "${stagepath}"/usr/portage

