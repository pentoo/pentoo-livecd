#!/bin/sh
#input arch ($1) and stage ($2), output working spec

set -e

VERSION_STAMP=2013.0
echo "version_stamp: ${VERSION_STAMP}"
RC=RC1.7
case ${2} in
	stage1)
		if [ ${1} = amd64 ]
		then
			echo source_subpath: hardened/stage3-amd64-hardened-20130523
		elif [ ${1} = i686 ]
		then
			echo source_subpath: hardened/stage3-i686-hardened-20130423
		fi
		;;
	stage2)
		echo "source_subpath: hardened/stage1-${1}-${VERSION_STAMP}"
		;;
	stage3)
		echo "source_subpath: hardened/stage2-${1}-${VERSION_STAMP}"
		;;
	stage4)
		echo "source_subpath: hardened/stage3-${1}-${VERSION_STAMP}"
		;;
	livecd-stage1)
		echo "source_subpath: hardened/stage4-${1}-${VERSION_STAMP}"
		;;
	livecd-stage2)
		echo "source_subpath: hardened/livecd-stage1-${1}-${VERSION_STAMP}"
		echo "livecd/iso: /catalyst/release/Pentoo_${1}/pentoo-${1}-${VERSION_STAMP}_${RC}.iso"
		echo "livecd/volid: Pentoo Linux ${1} ${VERSION_STAMP} ${RC}"
		;;
esac

#grab common things
cat ${1}-common.spec full-common.spec
echo "target: ${2}"

#fix profiles
case ${2} in
	stage1|stage2|stage3)
		if [ ${1} = amd64 ]
		then
			echo "profile: --force pentoo:pentoo/hardened/linux/${1}/bootstrap"
		elif [ ${1} = i686 ]
		then
			echo "profile: --force pentoo:pentoo/hardened/linux/x86/bootstrap"
		fi
		;;
	stage4|livecd-stage1|livecd-stage2)
		if [ ${1} = amd64 ]
		then
			echo "profile: pentoo:pentoo/hardened/linux/${1}"
		elif [ ${1} = i686 ]
		then
			echo "profile: pentoo:pentoo/hardened/linux/x86"
		fi
		;;
esac

[ -f ${2}-common.spec ] && cat ${2}-common.spec

case ${2} in
	stage1)
		if [ ${1} = amd64 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/${1}-hardened-bootstrap/${2}"
		elif [ ${1} = i686 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/x86-hardened-bootstrap/${2}"
		fi
		;;
	stage2|stage3)
		if [ ${1} = amd64 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/${1}-hardened-bootstrap"
		elif [ ${1} = i686 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/x86-hardened-bootstrap"
		fi
		;;
	stage4|livecd-stage1|livecd-stage2)
		if [ ${1} = amd64 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/${1}-hardened"
		elif [ ${1} = i686 ]
		then
			echo "pkgcache_path: /catalyst/tmp/packages/x86-hardened"
		fi
		;;
esac
