#!/bin/sh

/usr/src/pentoo/pentoo-livecd/livecd/specs/snap.sh

ARCH="x86 amd64"
PROFILE="hardened"
stage="binpkg-update"
SIGN_FAILED=0

for arch in ${ARCH}
do
  #sets subarch and profile_arch from ${arch}, so it has to be sourced in the loop
  . /usr/src/pentoo/pentoo-livecd/livecd/automation/pentoo_functions.sh
  echo "${PROFILE} ${arch} build started..." 1>&2
  FAILED=0
  chmod 755 /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh
  /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh "${arch}" "${PROFILE}" "${stage}" > "/tmp/${arch}-${PROFILE}-${stage}.spec"
  wait_for_it eatmydata catalyst -f "/tmp/${arch}-${PROFILE}-${stage}.spec" || FAILED=1
  catalyst_clean
  if [ "${FAILED}" = "0" ]; then
    echo "${PROFILE} ${arch} build successful" 1>&2
    wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/packages/${profile_arch}-${PROFILE}" /mnt/mirror/local_mirror/Packages/
    if ! sign_binpkgs "/mnt/mirror/local_mirror/Packages/${profile_arch}-${PROFILE}"; then
      echo "${PROFILE} ${arch} binpkg signing FAILED" 1>&2
      SIGN_FAILED=1
    fi
  elif [ "${FAILED}" = 1 ]; then
    echo "${PROFILE} ${arch} build FAILED" 1>&2
  fi
  echo "------------------------------------------------------------------" 1>&2
done
#a failed signing run can leave unsigned or stale-index packages in local_mirror
if [ "${SIGN_FAILED}" = 0 ]; then
  /mnt/mirror/mirror.sh && echo "mirror successful" 1>&2
else
  echo "not mirroring, binpkg signing failed" 1>&2
fi
