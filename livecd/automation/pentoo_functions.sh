if [ "${arch}" = "amd64" ]; then
  subarch="amd64"
  profile_arch="amd64_r1"
elif [ "${arch}" = "x86" ]; then
  subarch="pentium-m"
  profile_arch="x86"
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

catalyst_clean() {
  if [ "${stage}" = "stage4-pentoo" ] || [ "${stage}" = "stage4-pentoo-full" ]; then
    rm -rf /catalyst/tmp/hardened/stage4-"${subarch}"-pentoo-*
  elif [ "${stage}" = "binpkg-update-seed" ] || [ "${stage}" = "binpkg-update" ] ; then
    rm -rf /catalyst/tmp/hardened/stage4-"${subarch}"-binpkg-update-*
  elif [ "${stage}" = "livecd-stage2" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_${arch}_hardened"
    fi
    rm -rf "/catalyst/tmp/hardened/livecd-stage2-${subarch}-2021.0"
    rm -rf /catalyst/builds/hardened/livecd-stage2-"${subarch}"-2021.0/*
  elif [ "${stage}" = "livecd-stage2-core" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_Core_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_Core_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_Core_${arch}_hardened"
    fi
    rm -rf "/catalyst/tmp/hardened/livecd-stage2-${subarch}-core-2021.0"
    rm -rf /catalyst/builds/hardened/livecd-stage2-"${subarch}"-core-2021.0/*
  elif [ "${stage}" = "livecd-stage2-full" ]; then
    if [ "${1}" = "pre" ]; then
      rm -rf "/catalyst/release/Pentoo_Full_${arch}_hardened"
      mkdir -p "/catalyst/release/Pentoo_Full_${arch}_hardened"
      chmod 777 "/catalyst/release/Pentoo_Full_${arch}_hardened"
    fi
    rm -rf /catalyst/tmp/hardened/livecd-stage2-${subarch}-full-2021.0
    rm -rf /catalyst/builds/hardened/livecd-stage2-${subarch}-full-2021.0/*
  else
    rm -rf /catalyst/tmp/hardened/"${stage}-${subarch}-"*
  fi
}

mirror_sync() {
  if [ "${FAILED}" = "0" ]; then
    echo "hardened ${arch} build successful" 1>&2
    if [ "${stage}" != "${stage/livecd/}" ]; then
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
    #exit 1
  fi
}
