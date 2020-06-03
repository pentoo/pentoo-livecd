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
elif [[ ${3} = binpkg-update* ]]
then
	echo "version_stamp: binpkg-update-${VERSION_STAMP}"
elif [ "${3}" = "livecd-stage2-full" ]
then
	echo "version_stamp: full-${VERSION_STAMP}"
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
	stage4|stage4-pentoo|stage4-pentoo-full|binpkg-update-seed|binpkg-update|livecd-stage1|livecd-stage2|livecd-stage2-full)
		echo "pkgcache_path: /catalyst/packages/${1}-${2}"
		;;
esac

case ${3} in
	stage1)
    ## this is how we use gentoo's stages, but 17.1 broke us
		#if [ ${1} = amd64 ]
		#then
		#	if [ ${2} = hardened ]
		#	then
		#		echo "source_subpath: ${2}/seeds/stage3-amd64-${2}-20190929T214502Z.tar.xz"
		#	elif [ ${2} = default ]
		#	then
		#		echo "source_subpath: ${2}/seeds/stage3-amd64-20181218T214503Z.tar.xz"
		#	fi
		#elif [ ${1} = x86 ]
		#then
		#	if [ ${2} = hardened ]
		#	then
		#		echo "source_subpath: ${2}/seeds/stage3-i686-${2}-20190927T214501Z.tar.xz"
		#	elif [ ${2} = default ]
		#	then
		#		echo "source_subpath: ${2}/seeds/stage3-i686-20190103T151155Z.tar.xz"
		#	fi
		#fi
    ## so let's run in circles
    echo "source_subpath: ${2}/stage4-${subarch}-${VERSION_STAMP}.tar.xz"
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
	binpkg-update-seed)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-full-${VERSION_STAMP}.tar.xz"
		;;
	binpkg-update)
		#this might be really dangerous but to avoid remaking the same fixes over and over
		#I'm going to seed binpkg-update with binpkg-update :-)
		echo "source_subpath: ${2}/stage4-${subarch}-binpkg-update-${VERSION_STAMP}.tar.xz"
		;;
	livecd-stage1)
		echo "source_subpath: ${2}/stage4-${subarch}-pentoo-${VERSION_STAMP}.tar.xz"
		#echo "source_subpath: ${2}/stage4-${subarch}-binpkg-update-${VERSION_STAMP}.tar.xz"
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

if [ "${3}" = "livecd-stage2" ] || [ "${3}" = "livecd-stage2-full" ]
then
  echo -e "\n# This option is the full path and filename to a kernel .config file that is"
  echo "# used by genkernel to compile the kernel this label applies to."
  if [ ${1} = amd64 ] && [ ${2} = hardened ]
  then
    echo "boot/kernel/pentoo/config: /usr/src/pentoo/pentoo-livecd/livecd/${1}/kernel/config-latest"
  elif [ ${1} = amd64 ] && [ ${2} = default ]
  then
    echo "boot/kernel/pentoo/config: /usr/src/pentoo/pentoo-livecd/livecd/${1}/kernel/config-latest"
  elif [ ${1} = x86 ] && [ ${2} = hardened ]
  then
    echo "boot/kernel/pentoo/config: /usr/src/pentoo/pentoo-livecd/livecd/${1}/kernel/config-latest"
  elif [ ${1} = x86 ] && [ ${2} = default ]
  then
    echo "boot/kernel/pentoo/config: /usr/src/pentoo/pentoo-livecd/livecd/${1}/kernel/config-latest"
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
  echo livecd/gk_mainargs: --disklabel --no-dmraid --gpg --luks --lvm --mdadm --btrfs --microcode --microcode-initramfs --no-module-rebuild --kernel-localversion=UNSET --compress-initramfs-type=xz
  #if [ ${1} = amd64 ]
  #then
  #this adds zfs to just the non-hardened 64 bit kernel
  #	echo -e "\n# This option sets genkernel parameters on a per-kernel basis and applies only"
  #	echo "# to this kernel label.  This can be used for building options into only a"
  #	echo "# single kernel, where compatibility may be an issue.  Since we do not use this"
  #	echo "# on the official release media, it is left blank, but it follows the same"
  #	echo "# syntax as livecd/gk_mainargs."
  #	echo "boot/kernel/pentoo/gk_kernargs: --zfs"
  #else
  echo -e "\n#This ensures zfs is turned off and not autodetected to be in use"
  echo "boot/kernel/pentoo/gk_kernargs: --no-zfs --b2sums"
  #fi

  echo "# This option is for merging kernel-dependent packages and external modules that"
  echo "# are configured against this kernel label."
  echo "boot/kernel/pentoo/packages: pentoo/pentoo"
fi

echo "subarch: ${subarch}"

if [ ${1} = amd64 ]
then
	echo "cflags: -Os -mtune=core2 -pipe -ggdb -frecord-gcc-switches"
	echo "cxxflags: -Os -mtune=core2 -pipe -ggdb -frecord-gcc-switches"
	echo "fflags: -Os -mtune=core2 -pipe -ggdb -frecord-gcc-switches"
	echo "fcflags: -Os -mtune=core2 -pipe -ggdb -frecord-gcc-switches"
	echo "common_flags: -Os -mtune=core2 -pipe -ggdb -frecord-gcc-switches"
elif [ ${1} = x86 ]
then
	echo "cflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -ggdb -frecord-gcc-switches"
	echo "cxxflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -ggdb -frecord-gcc-switches"
	echo "fflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -ggdb -frecord-gcc-switches"
	echo "fcflags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -ggdb -frecord-gcc-switches"
	echo "common_flags: -Os -mtune=pentium-m -pipe -fomit-frame-pointer -ggdb -frecord-gcc-switches"
fi

if [ "${3}" = stage4-pentoo ] || [ "${3}" = "stage4-pentoo-full" ]
then
	echo "target: stage4"
elif [[ ${3} = binpkg-update* ]]
then
	echo "target: stage4"
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
	stage4|stage4-pentoo|stage4-pentoo-full|binpkg-update-seed|binpkg-update|livecd-stage1)
		echo "profile: pentoo:pentoo/${2}/linux/${1}"
		;;
	livecd-stage2|livecd-stage2-full)
		echo "profile: pentoo:pentoo/${2}/linux/${1}/binary"
		;;
esac

[ "${3}" = "stage1" ] && cat /usr/src/pentoo/pentoo-livecd/livecd/specs/stage1-common.spec

if [ "${3}" = "livecd-stage2" ] || [ "${3}" = "livecd-stage2-full" ]
then
  cat /usr/src/pentoo/pentoo-livecd/livecd/specs/livecd-stage2-common.spec
fi

#kitchen sink
case ${3} in
	stage4)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4.sh"
		echo "stage4/packages: --update @system"
		;;
	stage4-pentoo)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4-pentoo.sh"
		echo "stage4/use: livecd livecd-stage1 -office -pentoo-full -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
		;;
	stage4-pentoo-full)
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/fsscript-stage4-pentoo.sh"
		echo "stage4/use: livecd livecd-stage1 -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
		;;
	binpkg-update*)
		echo "stage4/use: livecd livecd-stage1 pentoo-full -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "stage4/packages: --update pentoo/pentoo"
		echo "stage4/fsscript: /usr/src/pentoo/pentoo-livecd/livecd/specs/fsscripts/call-pentoo-updater.sh"
		;;
	livecd-stage1)
		echo "livecd/use: livecd livecd-stage1 -libzfs -video_cards_fglrx -video_cards_nvidia -video_cards_virtualbox"
		echo "livecd/packages: --update pentoo/pentoo"
		;;
esac
