#!/bin/sh
set -x
if [ -z "$1" ]; then
  printf "Arch required\n"
  exit 1
fi
if [ -z "$2" ]; then
  printf "Stage required\n"
  exit 1
fi

arch="${1}"
stage="${2}"

. /usr/src/pentoo/pentoo-livecd/livecd/automation/pentoo_functions.sh

catalyst_clean pre
FAILED=0
chmod 755 /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh
/usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh "${arch}" "hardened" "${stage}" > "/tmp/${arch}-hardened-${stage}.spec"
sleep 1
sync
sleep 1
pkgcache_path="$(grep pkgcache_path "/tmp/${arch}-hardened-${stage}.spec" | awk -F' ' '{print $2}')"
PKGDIR="${pkgcache_path}" eclean-pkg --unique-use --changed-deps || PKGDIR="${pkgcache_path}" eclean-pkg
if ! wait_for_it eatmydata catalyst -f "/tmp/${arch}-hardened-${stage}.spec"; then
  printf "wait_for_it eatmydata catalyst failed\n"
  FAILED=1
fi
PKGDIR="${pkgcache_path}" eclean-pkg --unique-use --changed-deps || PKGDIR="${pkgcache_path}" eclean-pkg
catalyst_clean post
mirror_sync
exit ${FAILED}
