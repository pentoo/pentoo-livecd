#!/bin/bash
# Check that no image we publish keeps /etc/portage/gnupg.  getuto puts a
# private local trust key and its passphrase there, which has to be made on
# each install, not shipped in a stage, an iso or a docker image.  Generates
# the spec for every target with specs/build_spec.sh and checks that its
# stage4/rm or livecd/rm list removes the keyring, and that every Dockerfile
# that runs commands removes it too.  Needs no root.
#
# usage: test-image-cleanup.sh

# shellcheck disable=SC2329 # functions called through check and trap
set -euo pipefail

livecd=$(cd "$(dirname "$0")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf "${root}"' EXIT
sed -e "s#/usr/src/pentoo/pentoo-livecd/livecd/specs/#${livecd}/specs/#g" \
	-e "s#/catalyst/builds/#${root}/catalyst/builds/#g" \
	"${livecd}/specs/build_spec.sh" > "${root}/build_spec.sh"
# the stage4 target looks for its stage3 seed
mkdir -p "${root}/catalyst/builds/hardened"
touch "${root}/catalyst/builds/hardened/stage3-amd64-$(date +%Y).0.tar.zstd"
failed=0

check() {
	local name=$1
	shift
	if "$@"; then
		echo "ok   ${name}"
	else
		echo "FAIL ${name}"
		failed=1
	fi
}

# $1 spec file, $2 the option holding the list of paths catalyst removes
removes_keyring() {
	grep "^$2: " "$1" | tr ' ' '\n' | grep -qx /etc/portage/gnupg
}

for target in stage4 stage4-pentoo stage4-pentoo-full stage4-pentoo-core stage4-docker \
	binpkg-update-seed binpkg-update livecd-stage2 livecd-stage2-full livecd-stage2-core; do
	bash "${root}/build_spec.sh" amd64 hardened "${target}" > "${root}/${target}.spec" 2> /dev/null
	case ${target} in
		livecd-*) option=livecd/rm ;;
		*) option=stage4/rm ;;
	esac
	check "${target}: ${option} removes /etc/portage/gnupg" removes_keyring "${root}/${target}.spec" "${option}"
done

for dockerfile in "${livecd}"/automation/docker/*/Dockerfile; do
	image=${dockerfile%/Dockerfile}
	grep -q '^RUN ' "${dockerfile}" || continue
	check "docker ${image##*/}: removes /etc/portage/gnupg" grep -q 'rm -rf .*/etc/portage/gnupg' "${dockerfile}"
done

exit "${failed}"
