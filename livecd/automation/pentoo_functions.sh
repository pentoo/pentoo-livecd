if [ "${arch}" = "amd64" ]; then
  subarch="amd64"
  profile_arch="amd64_23.0s"
elif [ "${arch}" = "x86" ]; then
  subarch="pentium-m"
  profile_arch="x86_23.0s"
else
  printf "Unknown arch\n"
  exit 1
fi

wait_for_it() {
  while pgrep -f "$*"
  do
    echo already running, sleeping 1m
    sleep 1m
  done
  "$@"
}

#stages building at the same time share tmp dir prefixes, so each glob has to
#stop at the version stamp; livecd/tools/test-catalyst-clean.sh checks this
catalyst_clean() {
  if [ "${stage}" = "stage4-pentoo" ] || [ "${stage}" = "stage4-pentoo-full" ] || [ "${stage}" = "stage4-pentoo-core" ] || [ "${stage}" = "stage4-docker" ]; then
    rm -rf /var/tmp/catalyst/tmp/hardened/stage4-"${subarch}-${stage#stage4-}"-20*
  elif [ "${stage}" = "binpkg-update-seed" ] || [ "${stage}" = "binpkg-update" ] ; then
    rm -rf /var/tmp/catalyst/tmp/hardened/stage4-"${subarch}"-binpkg-update-20*
  elif [ "${stage}" = "livecd-stage2" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_${arch}_hardened"
    fi
    rm -rf /var/tmp/catalyst/tmp/hardened/livecd-stage2-"${subarch}"-20*.*
    rm -rf /catalyst/builds/hardened/livecd-stage2-"${subarch}"-20??.?/*
  elif [ "${stage}" = "livecd-stage2-core" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_Core_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_Core_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_Core_${arch}_hardened"
    fi
    rm -rf /var/tmp/catalyst/tmp/hardened/livecd-stage2-"${subarch}"-core-20*.*
    rm -rf /catalyst/builds/hardened/livecd-stage2-"${subarch}"-core-20??.?/*
  elif [ "${stage}" = "livecd-stage2-full" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_Full_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_Full_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_Full_${arch}_hardened"
    fi
    rm -rf /var/tmp/catalyst/tmp/hardened/livecd-stage2-${subarch}-full-20*.*
    rm -rf /catalyst/builds/hardened/livecd-stage2-${subarch}-full-20??.?/*
  else
    rm -rf /var/tmp/catalyst/tmp/hardened/"${stage}-${subarch}-20"*
  fi
}

mirror_sync() {
  if [ "${FAILED}" = "0" ]; then
    echo "hardened ${arch} build successful" 1>&2
    if [ "${stage}" != "${stage/livecd/}" ]; then
      #the tools list has to be in the release dir before the rsync publishes it
      if [ "${stage}" != "${stage/full/}" ]; then
        #full iso
        mv "/catalyst/log/tool-list/tools_list_${arch}-hardened.json" /catalyst/release/Pentoo_Full_${arch}_hardened/
        wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/release/Pentoo_Full_${arch}_hardened" /mnt/mirror/local_mirror/daily-autobuilds/
      elif [ "${stage}" != "${stage/core/}" ]; then
        #core iso
        mv "/catalyst/log/tool-list/tools_list_${arch}-hardened.json" /catalyst/release/Pentoo_Core_${arch}_hardened/
        wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/release/Pentoo_Core_${arch}_hardened" /mnt/mirror/local_mirror/daily-autobuilds/
      else
        #normal iso
        mv "/catalyst/log/tool-list/tools_list_${arch}-hardened.json" /catalyst/release/Pentoo_${arch}_hardened/
        wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/release/Pentoo_${arch}_hardened" /mnt/mirror/local_mirror/daily-autobuilds/
      fi
    fi
    if [ "${stage}" != "${stage/livecd/}" ] || [ "${stage}" != "${stage/full/}" ]; then
      #sync packages for anything called livecd or full.  These are the stages which run eclean-pkg and fixpackages
      wait_for_it rsync -aEXuh --progress --delete --omit-dir-times "/catalyst/packages/${profile_arch}-hardened" /mnt/mirror/local_mirror/Packages/
      #/mnt/mirror/mirror.sh &
    fi
  else
    echo "hardened ${arch} ${stage} build FAILED" 1>&2
    #or the next livecd build to succeed would publish this list as its own
    rm -f "/catalyst/log/tool-list/tools_list_${arch}-hardened.json"
    #exit 1
  fi
}
