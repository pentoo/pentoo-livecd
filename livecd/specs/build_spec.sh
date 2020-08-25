#!/bin/bash
#input arch (x86 or amd64)($1), profile ($2) and stage ($3), output working spec

set -e

VERSION_STAMP=$(date +%Y.0)
#could change .0 to %q
if [ "${3}" = stage4-pentoo ]
then
	echo "version_stamp: pentoo-${VERSION_STAMP}"
elif [ "${3}" = stage4-pentoo-full ]
then
	echo "version_stamp: pentoo-full-${VERSION_STAMP}"
elif [ "${3}" = stage4-pentoo-core ]
then
	echo "version_stamp: pentoo-core-${VERSION_STAMP}"
elif [ "${3}" = stage4-wctf-client ]
then
	echo "version_stamp: wctf-client-${VERSION_STAMP}"
elif [[ ${3} = binpkg-update* ]]
then
	echo "version_stamp: binpkg-update-${VERSION_STAMP}"
elif [ "${3}" = "livecd-stage2-full" ]
then
	echo "version_stamp: full-${VERSION_STAMP}"
elif [ "${3}" = "livecd-stage2-core" ]
then
	echo "version_stamp: core-${VERSION_STAMP}"
else
	echo "version_stamp: ${VERSION_STAMP}"
fi

RC=p$(date "+%Y%m%d")
#RC="r1"

if [ "${1}" = "x86" ]; then
	arch="x86"
	subarch="pentium-m"
elif [ "${1}" = "amd64" ]; then
	arch="x86_64"
	subarch="${1}"
fi

echo "rel_type: ${2}"
echo "snapshot: latest.tar.xz "
echo "portage_overlay: /var/db/repos/pentoo"
echo "portage_confdir: /usr/src/pentoo/pentoo-livecd/livecd/portage"
echo "compression_mode: pixz"

#pkgcache_path
case ${3} in
	stage1)
		echo "pkgcache_path: /catalyst/packages/${1}-${2}-bootstrap/${3}"
		;;
	stage2|stage3)
		echo "pkgcache_path: /catalyst/packages/${1}-${2}-bootstrap"
		;;
	stage4|stage4-pentoo|stage4-pentoo-core|stage4-pentoo-full|stage4-wctf-client|binpkg-update-seed|binpkg-update|livecd-stage2-core|livecd-stage2|livecd-stage2-full)
		echo "pkgcache_path: /catalyst/packages/${1}-${2}"
		;;
esac

case ${3} in
	stage1)
    ## let's run in circles
    echo "source_subpath: ${2}/stage4-${subarch}-${VERSION_STAMP}.tar.xz"
    #migrate to new version stamp by using a static version stamp
    #echo "source_subpath: ${2}/stage4-${subarch}-2019.3.tar.xz"
		;;
	stage2)
		echo "source_subpath: ${2}/stage1-${subarch}-${VERSION_STAMP}.tar.xz"
		;;
	stage3)
		echo "source_subpath: ${2}/stage2-${subarch}-${VERSION_STAMP}.tar.xz"
		;;
	stage4)
		echo "source_subpath: ${2}/stage3-${subarch}-${VERSION_STAMP}.tar.xz"
		;;
	stage4-pentoo*)
		echo "source_subpath: ${2}/stage4-${subarch}-${VERSION_STAMP}.tar.xz"
		;;
	stage4-wctf-client)
		echo "source_subpath: ${2}/stage4-${subarch}-${VERSION_STAMP}.tar.xz"
		;;
	binpkg-update-seed)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-full-${VERSION_STAMP}.tar.xz"
		;;
	binpkg-update)
		#this might be really dangerous but to avoid remaking the same fixes over and over
		#I'm going to seed binpkg-update with binpkg-update :-)
		echo "source_subpath: ${2}/stage4-${subarch}-binpkg-update-${VERSION_STAMP}.tar.xz"
		;;
	livecd-stage2-core)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-core-${VERSION_STAMP}.tar.xz"
		if [ -n "${RC}" ]; then
			echo "livecd/iso: /catalyst/release/Pentoo_Core_${1}_${2}/pentoo-core-${1}-${2}-${VERSION_STAMP}_${RC}.iso"
			echo "livecd/volid: Pentoo Linux Core ${arch} ${VERSION_STAMP} ${RC:0:5}"
		else
			echo "livecd/iso: /catalyst/release/Pentoo_Core_${1}_${2}/pentoo-core-${1}-${2}-${VERSION_STAMP}.iso"
			echo "livecd/volid: Pentoo Linux Core ${arch} ${VERSION_STAMP}"
		fi
		echo "livecd/depclean: no"
		;;
	livecd-stage2)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-${VERSION_STAMP}.tar.xz"
		if [ -n "${RC}" ]; then
      echo "livecd/iso: /catalyst/release/Pentoo_${1}_${2}/pentoo-${1}-${2}-${VERSION_STAMP}_${RC}.iso"
			echo "livecd/volid: Pentoo Linux ${arch} ${VERSION_STAMP} ${RC:0:5}"
		else
      echo "livecd/iso: /catalyst/release/Pentoo_${1}_${2}/pentoo-${1}-${2}-${VERSION_STAMP}.iso"
			echo "livecd/volid: Pentoo Linux ${arch} ${VERSION_STAMP}"
		fi
		;;
	livecd-stage2-full)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-full-${VERSION_STAMP}.tar.xz"
		if [ -n "${RC}" ]; then
			echo "livecd/iso: /catalyst/release/Pentoo_Full_${1}_${2}/pentoo-full-${1}-${2}-${VERSION_STAMP}_${RC}.iso"
			echo "livecd/volid: Pentoo Linux Full ${arch} ${VERSION_STAMP} ${RC:0:5}"
		else
			echo "livecd/iso: /catalyst/release/Pentoo_Full_${1}_${2}/pentoo-full-${1}-${2}-${VERSION_STAMP}.iso"
			echo "livecd/volid: Pentoo Linux Full ${arch} ${VERSION_STAMP}"
		fi
		echo "livecd/depclean: no"
		;;
esac

if [ "${3}" = "livecd-stage2" ] || [ "${3}" = "livecd-stage2-full" ] || [ "${3}" = "livecd-stage2-core" ]
then
  echo -e "\n# This option is the full path and filename to a kernel .config file that is"
  echo "# used by genkernel to compile the kernel this label applies to."
  if [ ${1} = amd64 ] && [ ${2} = hardened ]
  then
    echo "boot/kernel/pentoo/config: /var/db/repos/pentoo/sys-kernel/pentoo-sources/files/config-${1}-latest"
  elif [ ${1} = amd64 ] && [ ${2} = default ]
  then
    echo "boot/kernel/pentoo/config: /var/db/repos/pentoo/sys-kernel/pentoo-sources/files/config-${1}-latest"
  elif [ ${1} = x86 ] && [ ${2} = hardened ]
  then
    echo "boot/kernel/pentoo/config: /var/db/repos/pentoo/sys-kernel/pentoo-sources/files/config-${1}-latest"
  elif [ ${1} = x86 ] && [ ${2} = default ]
  then
    echo "boot/kernel/pentoo/config: /var/db/repos/pentoo/sys-kernel/pentoo-sources/files/config-${1}latest"
  fi

  echo -e "\n# This allows the optional directory containing the output packages for kernel"
  echo "# builds.  Mainly used as a way for different spec files to access the same"
  echo "# cache directory.  Default behavior is for this location to be autogenerated"
  echo "# by catalyst based on the spec file."
  echo "kerncache_path: /catalyst/kerncache/${1}-${2}"

  echo "livecd/fsops: -comp xz -Xbcj x86 -b 1048576 -no-recovery -noappend -Xdict-size 1048576"

  echo -e "\n# This is a set of arguments that will be passed to genkernel for all kernels"
  echo "# defined in this target.  It is useful for passing arguments to genkernel that"
  echo "# are not otherwise available via the livecd-stage2 spec file."
  echo livecd/gk_mainargs: --disklabel --no-dmraid --gpg --luks --lvm --mdadm --btrfs --no-module-rebuild --kernel-localversion=UNSET --compress-initramfs-type=xz --no-microcode-initramfs --b2sum --no-zfs
fi

if [ "${3}" = "livecd-stage2" ] || [ "${3}" = "livecd-stage2-full" ];
then
  echo "# This option is for merging kernel-dependent packages and external modules that"
  echo "# are configured against this kernel label."
  echo "boot/kernel/pentoo/packages: pentoo/pentoo"
elif [ "${3}" = "livecd-stage2-core" ]; then
  echo "# This option is for merging kernel-dependent packages and external modules that"
  echo "# are configured against this kernel label."
  echo "boot/kernel/pentoo/packages: pentoo/pentoo-core"
fi

echo "subarch: ${subarch}"

if [ ${1} = amd64 ]
then
	echo "cflags: -Os -mtune=core2 -pipe -frecord-gcc-switches"
	echo "cxxflags: -Os -mtune=core2 -pipe -frecord-gcc-switches"
	echo "fflags: -Os -mtune=core2 -pipe -frecord-gcc-switches"
	echo "fcflags: -Os -mtune=core2 -pipe -frecord-gcc-switches"
	echo "common_flags: -Os -mtune=core2 -pipe -frecord-gcc-switches"
elif [ ${1} = x86 ]
then
	echo "cflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -frecord-gcc-switches"
	echo "cxxflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -frecord-gcc-switches"
	echo "fflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -frecord-gcc-switches"
	echo "fcflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -frecord-gcc-switches"
	echo "common_flags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -frecord-gcc-switches"
fi

if [ "${3}" = stage4-pentoo ] || [ "${3}" = "stage4-pentoo-core" ] || [ "${3}" = "stage4-pentoo-full" ] || [ "${3}" = "stage4-pentoo-full" ] || [ "${3}" = "stage4-wctf-client" ]
then
	echo "target: stage4"
elif [[ ${3} = binpkg-update* ]]
then
	echo "target: stage4"
elif [ "${3}" = "livecd-stage2-core" ]
then
  echo "target: livecd-stage2"
elif [ "${3}" = "livecd-stage2-full" ]
then
  echo "target: livecd-stage2"
else
	echo "target: ${3}"
fi

#fix profiles
case ${3} in
	stage1|stage2|stage3)
		echo "profile: --force pentoo:pentoo/${2}/linux/${1}/bootstrap"
		;;
	stage4|stage4-pentoo|stage4-pentoo-full|stage4-pentoo-core|stage4-wctf-client|binpkg-update-seed|binpkg-update)
		echo "profile: pentoo:pentoo/${2}/linux/${1}"
		;;
	livecd-stage2-core|livecd-stage2|livecd-stage2-full)
		echo "profile: pentoo:pentoo/${2}/linux/${1}/binary"
		;;
esac

[ "${3}" = "stage1" ] && cat /usr/src/pentoo/pentoo-livecd/livecd/specs/stage1-common.spec

if [ "${3}" = "livecd-stage2" ] || [ "${3}" = "livecd-stage2-full" ] || [ "${3}" = "livecd-stage2-core" ]
then
  cat /usr/src/pentoo/pentoo-livecd/livecd/specs/livecd-stage2-common.spec
fi

#kitchen sink
case ${3} in
	stage4)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4.sh"
		echo "stage4/packages: --update @system"
    echo "stage4/rm: /usr/lib/debug /catalyst"
		;;
	stage4-pentoo)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4-pentoo.sh"
		echo "stage4/use: livecd livecd-stage1 -office -pentoo-full -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
    echo "stage4/rm: /usr/lib/debug /catalyst"
		;;
	stage4-pentoo-full)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4-pentoo.sh"
		echo "stage4/use: livecd livecd-stage1 -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
    echo "stage4/rm: /usr/lib/debug /catalyst"
		;;
	stage4-pentoo-core)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4-pentoo.sh"
		echo "stage4/use: livecd livecd-stage1 -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo-core"
    echo "stage4/rm: /usr/lib/debug /catalyst"
		;;
	stage4-wctf-client)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/depclean-hard.sh"
		echo "stage4/use: -livecd pentoo-minimal pentoo-in-a-container wctf-wifi wctf-minimal"
		echo "stage4/packages: --update --deep --verbose --tree pentoo/wctf-client"
    echo "stage4/unmerge: sys-devel/llvm sys-devel/llvm-common"
    echo "stage4/rm: /usr/lib/debug /catalyst /usr/share/doc /usr/share/man"
		;;
	binpkg-update*)
		echo "stage4/use: livecd livecd-stage1 pentoo-full -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/call-pentoo-updater.sh"
    echo "stage4/rm: /usr/lib/debug /catalyst"
		;;
esac
