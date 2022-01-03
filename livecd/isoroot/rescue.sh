#!/bin/sh
set -eux 
#shellcheck disable=SC3040
set -o pipefail || true

if [ -z "${1-}" ]; then
  printf "Please provide the grub.cfg file from your /boot drive as param 1\n"
  exit 1
fi

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
  if [ ! -e "${DESTDIR}/run" ]; then
    mkdir "${DESTDIR}/run" || return $?
  fi
  mount -t tmpfs none "${DESTDIR}/run" || return $?
  return 0
}

live_umount() {
  sleep 1
  if mount | grep -q "${DESTDIR}/proc "; then
    umount -R "${DESTDIR}/proc" || return $?
  fi
  if mount | grep -q "${DESTDIR}/sys "; then
    umount -R "${DESTDIR}/sys" || return $?
  fi
  if mount | grep -q "${DESTDIR}/dev "; then
    umount -R "${DESTDIR}/dev" || return $?
  fi
  if mount | grep -q "${DESTDIR}/run "; then
    umount -R "${DESTDIR}/run" || return $?
  fi
  return 0
}

DESTDIR="/mnt/gentoo"

#extract what we need from grub.cfg
root_key="$(for i in $(grep 'linux\W/' -- "${1}" | head -n1); do printf "%s" "${i}" | awk -F'=' '/root_key=/ {print $2}'; done)"
root_keydev="/dev/disk/by-uuid/$(for uuid in $(grep 'linux\W/' -- "${1}" | head -n1); do printf "%s" "${uuid}" | awk -F'=' '/root_keydev/ {print $3}'; done)"
if [ "${root_keydev}" = '/dev/disk/by-uuid/' ]; then
  root_keydev="$(for uuid in $(grep 'linux\W/' -- "${1}" | head -n1); do printf "%s" "${uuid}" | awk -F'=' '/root_keydev/ {print $2}'; done)"
fi
crypt_root="/dev/disk/by-uuid$(for uuid in $(grep 'linux\W/' -- "${1}" | head -n1); do printf "%s" "${uuid}" | awk -F'=' '/crypt_root/ {print $3}'; done)"
if [ "${crypt_root}" = '/dev/disk/by-uuid/' ]; then
  crypt_root="$(for uuid in $(grep 'linux\W/' -- "${1}" | head -n1); do printf "%s" "${uuid}" | awk -F'=' '/crypt_root/ {print $2}'; done)"
fi

#mount the keydev temporarily
mkdir -p /mnt/key
mount "${root_keydev}" /mnt/key

gpg --pinentry-mode=loopback --logger-file /dev/null --quiet --decrypt "/mnt/key${root_key}" | sudo cryptsetup -d - luksOpen "${crypt_root}" root

#unmount the key as we are done with it
umount /mnt/key

mkdir -p "${DESTDIR}"
mount /dev/mapper/root "${DESTDIR}"

live_mount
chroot "${DESTDIR}" /bin/bash || true
live_umount
