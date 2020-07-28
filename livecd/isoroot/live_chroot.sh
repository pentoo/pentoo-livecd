#!/bin/sh -x

#sanity/usage checks
if [ ! -r "${1}" ]; then
  printf "Unable to read ${1}, please pass the pentoo iso in as arg 1\n"
  exit 1
fi
if [ "$(file -ib ${1})" != "application/x-iso9660-image; charset=binary" ]; then
  printf "This doesn't appear to be an iso file, cowardly quitting\n"
  exit 1
fi

#final functional location
DESTDIR="/mnt/pentoo_live"

#some functions we need
live_mount() {
  if [ ! -e "${DESTDIR}/sys" ]; then
    mkdir "${DESTDIR}/sys" || return $?
  fi
  if [ ! -e "${DESTDIR}/proc" ]; then
    mkdir "${DESTDIR}/proc" || return $?
  fi
  if [ ! -e "${DESTDIR}/dev" ]; then
    mkdir "${DESTDIR}/dev" || return $?
  fi
  for i in dev proc sys; do
    mount --make-shared /${i} || return $?
    mount --rbind --make-rslave /${i} "${DESTDIR}/${i}" || return $?
  done
  return 0
}
live_umount() {
  sleep 1
  if mount | grep -q "${DESTDIR}/proc "; then
    umount -R ${DESTDIR}/proc || return $?
  fi
  if mount | grep -q "${DESTDIR}/sys "; then
    umount -R ${DESTDIR}/sys || return $?
  fi
  if mount | grep -q "${DESTDIR}/dev "; then
    umount -R ${DESTDIR}/dev || return $?
  fi
  if mount | grep -q "${DESTDIR}/mnt/cdrom"; then
    umount -R ${DESTDIR}/mnt/cdrom || return $?
  fi
  if mount | grep -q '/mnt/pentoo_live'; then
    umount -R /mnt/pentoo_live || return $?
  fi
  if mount | grep -q '/mnt/pentoo_squash'; then
    umount -R /mnt/pentoo_squash || return $?
  fi
  for i in $(mount | grep ' /mnt/overlay/.' | awk '{print $3}'); do
    umount "${i}"
  done
  if mount | grep -q '/mnt/pentoo_iso'; then
    umount -R /mnt/pentoo_iso || return $?
  fi
  return 0
}

#start with unmount
live_umount

#mount the iso itself
mkdir /mnt/pentoo_iso
mount "${1}" /mnt/pentoo_iso

overlay=/mnt/overlay
upperdir="${overlay}/.upper"
workdir="${overlay}/.work"

mkdir -p /mnt/overlay /mnt/pentoo_squash "${DESTDIR}"
mount -t squashfs -o loop,ro /mnt/pentoo_iso/image.squashfs /mnt/pentoo_squash
mkdir -p "${overlay}"
mount -t tmpfs none "${overlay}"
mkdir -p "${upperdir}" "${workdir}"
modprobe overlay

for module in "/mnt/pentoo_iso/modules/"*.lzm; do
  mod=$(basename "${module}")
  mkdir -p "/mnt/overlay/.${mod}"
  mount -o loop,ro "${module}" "/mnt/overlay/.${mod}"
  mod_path="${mod_path}:/mnt/overlay/.${mod}"
  #mods="${mods} /mnt/overlay/.${mod}"
done

mount -t overlay overlay -o lowerdir=/mnt/pentoo_squash${mod_path},upperdir="${upperdir}",workdir="${workdir}" "${DESTDIR}"
mkdir -p /mnt/pentoo_live/mnt/cdrom
mount --bind /mnt/pentoo_iso "${DESTDIR}/mnt/cdrom"
live_mount
chroot "${DESTDIR}" /bin/bash
live_umount
