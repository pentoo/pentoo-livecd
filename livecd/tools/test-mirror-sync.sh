#!/bin/bash
# Check what the automation publishes to the mirror: each iso with its own
# tools list (never a failed build's), and the binpkg dir pentoo_binpkgs.sh
# syncs.  Runs copies of the scripts with
# /catalyst, /mnt/mirror and /usr/src/pentoo/pentoo-livecd moved into a temp
# dir and catalyst stubbed out, so it needs no root and touches nothing else.
#
# usage: test-mirror-sync.sh
set -euo pipefail

automation=$(cd "$(dirname "$0")/../automation" && pwd)
root=$(mktemp -d)
trap 'rm -rf "${root}"' EXIT

# only paths that start a word move; /tmp goes first, as ${root} is under it
relocate() {
	sed -E -e "s#(^|[\" ])/tmp/#\1${root}/tmp/#g" \
		-e "s#(^|[\" ])/var/tmp/#\1${root}/var/tmp/#g" \
		-e "s#(^|[\" ])/catalyst/#\1${root}/catalyst/#g" \
		-e "s#(^|[\" ])/mnt/mirror/#\1${root}/mnt/mirror/#g" \
		-e "s#(^|[\" ])/usr/src/pentoo/pentoo-livecd/livecd/automation/#\1${root}/#g" \
		-e "s#(^|[\" ])/usr/src/pentoo/pentoo-livecd/livecd/specs/#\1${root}/specs/#g" \
		"$1" > "$2"
}
relocate "${automation}/pentoo_functions.sh" "${root}/pentoo_functions.sh"
relocate "${automation}/pentoo_binpkgs.sh" "${root}/pentoo_binpkgs.sh"
mkdir -p "${root}/bin" "${root}/specs" "${root}/tmp" "${root}/mnt/mirror/local_mirror"
printf '#!/bin/sh\nexit 0\n' > "${root}/specs/snap.sh"
printf '#!/bin/sh\nexit 0\n' > "${root}/specs/build_spec.sh"
printf '#!/bin/sh\nexit 0\n' > "${root}/mnt/mirror/mirror.sh"
printf '#!/bin/sh\nexit 0\n' > "${root}/bin/catalyst"
printf '#!/bin/sh\nexec "$@"\n' > "${root}/bin/eatmydata"
chmod 755 "${root}"/specs/*.sh "${root}/mnt/mirror/mirror.sh" "${root}"/bin/*

list="${root}/catalyst/log/tool-list/tools_list_amd64-hardened.json"
autobuilds="${root}/mnt/mirror/local_mirror/daily-autobuilds"
packages="${root}/mnt/mirror/local_mirror/Packages"
failed=0

# description, then a command that succeeds when the check passes
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

# each build an hour after the last, as rsync skips files with the same size
# and mtime
stamp=$(date +%s)

# build stage, FAILED, iso file the build leaves in its release dir ("" for
# none), tools list it writes ("" for none)
build() {
	stamp=$((stamp + 3600))
	release=${root}/catalyst/release/Pentoo_amd64_hardened
	[ "$1" = livecd-stage2-full ] && release=${root}/catalyst/release/Pentoo_Full_amd64_hardened
	[ "$1" = livecd-stage2-core ] && release=${root}/catalyst/release/Pentoo_Core_amd64_hardened
	rm -rf "${release}"
	mkdir -p "${release}" "${root}/catalyst/packages/amd64_23.0s-hardened" "$(dirname "${list}")"
	[ -z "$3" ] || touch -d "@${stamp}" "${release}/$3"
	[ -z "$4" ] || { echo "$4" > "${list}" && touch -d "@${stamp}" "${list}"; }
	# like the automation scripts, without set -e
	# shellcheck disable=SC2034 # read by mirror_sync
	(set +e; arch=amd64 stage=$1 FAILED=$2
	# shellcheck source=/dev/null
	. "${root}/pentoo_functions.sh"
	mirror_sync) > /dev/null 2>&1
}

build livecd-stage2 0 pentoo-1.iso "normal 1"
check "normal iso published" test -f "${autobuilds}/Pentoo_amd64_hardened/pentoo-1.iso"
check "normal list published with the normal iso" test "$(cat "${autobuilds}/Pentoo_amd64_hardened/tools_list_amd64-hardened.json" 2> /dev/null)" = "normal 1"
check "list moved out of the catalyst log" test ! -e "${list}"
check "binpkgs synced" test -d "${packages}/amd64_23.0s-hardened"

build livecd-stage2-full 0 pentoo-full-1.iso "full 1"
check "full list published with the full iso" test "$(cat "${autobuilds}/Pentoo_Full_amd64_hardened/tools_list_amd64-hardened.json" 2> /dev/null)" = "full 1"
check "normal list kept" test "$(cat "${autobuilds}/Pentoo_amd64_hardened/tools_list_amd64-hardened.json" 2> /dev/null)" = "normal 1"

build livecd-stage2 0 pentoo-2.iso "normal 2"
check "old normal iso deleted" test ! -e "${autobuilds}/Pentoo_amd64_hardened/pentoo-1.iso"
check "new normal iso published" test -f "${autobuilds}/Pentoo_amd64_hardened/pentoo-2.iso"
check "normal list replaced" test "$(cat "${autobuilds}/Pentoo_amd64_hardened/tools_list_amd64-hardened.json" 2> /dev/null)" = "normal 2"

build livecd-stage2-full 1 "" "broken full"
check "failed build's list removed" test ! -e "${list}"
check "failed build's list not published" test "$(cat "${autobuilds}/Pentoo_Full_amd64_hardened/tools_list_amd64-hardened.json" 2> /dev/null)" = "full 1"

build livecd-stage2-core 0 pentoo-core-1.iso ""
check "build without a list publishes none" test ! -e "${autobuilds}/Pentoo_Core_amd64_hardened/tools_list_amd64-hardened.json"

for profile_arch in amd64_23.0s x86_23.0s; do
	mkdir -p "${root}/catalyst/packages/${profile_arch}-hardened"
	touch "${root}/catalyst/packages/${profile_arch}-hardened/Packages"
done
rm -rf "${packages}"
PATH="${root}/bin:${PATH}" sh "${root}/pentoo_binpkgs.sh" > /dev/null 2>&1 || true
check "pentoo_binpkgs.sh syncs amd64_23.0s-hardened" test -f "${packages}/amd64_23.0s-hardened/Packages"
check "pentoo_binpkgs.sh syncs x86_23.0s-hardened" test -f "${packages}/x86_23.0s-hardened/Packages"

exit "${failed}"
