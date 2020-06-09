#!/bin/sh

/usr/src/pentoo/pentoo-livecd/livecd/specs/snap.sh

ARCH="x86 amd64"
PROFILE="hardened"
stage="binpkg-update"

. pentoo_functions.sh

for arch in ${ARCH}
do
  echo "${PROFILE} ${arch} build started..." 1>&2
  FAILED=0
  chmod 755 /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh
  /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh "${arch}" "${PROFILE}" "${stage}" > "/tmp/${arch}-${PROFILE}-${stage}.spec"
  wait_for_it eatmydata catalyst -f "/tmp/${arch}-${PROFILE}-${stage}.spec" || FAILED=1
  catalyst_clean
  if [ "${FAILED}" = "0" ]; then
    echo "${PROFILE} ${arch} build successful" 1>&2
    wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/packages/${arch}-${PROFILE}" /mnt/mirror/local_mirror/Packages/
  elif [ "${FAILED}" = 1 ]; then
    echo "${PROFILE} ${arch} build FAILED" 1>&2
  fi
  echo "------------------------------------------------------------------" 1>&2
done
/mnt/mirror/mirror.sh && echo "mirror successful" 1>&2
