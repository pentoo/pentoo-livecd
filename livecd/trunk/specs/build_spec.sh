#!/bin/sh
#input arch ($1) and stage ($2), output working spec

VERSION_STAMP=2013.0
echo "version_stamp: ${VERSION_STAMP}"
RC=RC1.7
case ${2} in
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
		echo "profile: --force pentoo:pentoo/hardened/linux/${1}/bootstrap"
		;;
	stage4|livecd-stage1|livecd-stage2)
		echo "profile: pentoo:pentoo/hardened/linux/${1}"
		;;
esac

[ -f ${2}-common.spec ] && cat ${2}-common.spec

case ${2} in
	stage1)
		echo "pkgcache_path: /catalyst/tmp/packages/${2}-hardened-bootstrap/stage1"
		;;
	stage2|stage3)
		echo "pkgcache_path: /catalyst/tmp/packages/${2}-hardened-bootstrap"
		;;
	stage4|livecd-stage1|livecd-stage2)
		echo "pkgcache_path: /catalyst/tmp/packages/${2}-hardened"
		;;
esac

