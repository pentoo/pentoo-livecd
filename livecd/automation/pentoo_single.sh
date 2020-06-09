#!/bin/sh -x
if [ -z "$1" ]; then
  printf "Arch required\n"
  exit 1
fi

/usr/src/pentoo/pentoo-livecd/livecd/specs/snap.sh

arch="${1}"
stage="${2}"

. /usr/src/pentoo/pentoo-livecd/automation/pentoo_functions.sh

catalyst_clean pre
FAILED=0
chmod 755 /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh
/usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh "${arch}" "hardened" "${stage}" > "/tmp/${arch}-hardened-${stage}.spec"
pkgcache_path="$(grep pkgcache_path /tmp/amd64-hardened-stage1.spec | awk -F' ' '{print $2}')"
PKGDIR="${pkgcache_path}" eclean-pkg --changed-deps || PKGDIR="${pkgcache_path}" eclean-pkg
wait_for_it eatmydata catalyst -f "/tmp/${arch}-hardened-${stage}.spec" || FAILED=1
PKGDIR="${pkgcache_path}" eclean-pkg --changed-deps || PKGDIR="${pkgcache_path}" eclean-pkg
catalyst_clean post
mirror_sync
