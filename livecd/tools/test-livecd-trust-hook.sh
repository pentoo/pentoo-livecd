#!/bin/bash
# Check root_overlay's local.d script that gives a booted iso its own
# /etc/portage/gnupg: it runs pentoo-trust-helper, never fails the boot, and
# removes itself only once the helper worked.  Runs a copy of the script for
# each case, with a stub helper on a PATH that holds nothing else, so the
# real helper never runs.  Needs no root.
#
# usage: test-livecd-trust-hook.sh

# shellcheck disable=SC2329 # functions called through check and trap
set -euo pipefail

livecd=$(cd "$(dirname "$0")/.." && pwd)
hook=${livecd}/root_overlay/etc/local.d/50-pentoo-trust-helper.start
root=$(mktemp -d)
trap 'rm -rf "${root}"' EXIT
tools=${root}/tools
stub=${root}/stub
mkdir -p "${tools}" "${stub}" "${root}/local.d"
for tool in sh rm; do
	ln -s "$(command -v "${tool}")" "${tools}/${tool}"
done
cat > "${stub}/pentoo-trust-helper" <<STUB
#!/bin/sh
echo called >> "${root}/calls"
echo "helper output"
[ ! -e "${root}/helper-fails" ]
STUB
chmod 755 "${stub}/pentoo-trust-helper"
copy=${root}/local.d/50-pentoo-trust-helper.start
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

# $1 PATH; runs a fresh copy of the hook, output in ${root}/out
run() {
	local rc=0
	rm -f "${root}/calls"
	cp "${hook}" "${copy}"
	PATH=$1 "${copy}" > "${root}/out" 2>&1 || rc=$?
	echo "${rc}" > "${root}/rc"
}
rc_is() {
	[ "$(cat "${root}/rc")" = "$1" ]
}
helper_ran() {
	[ "$(cat "${root}/calls" 2> /dev/null)" = called ]
}
says() {
	grep -qF -- "$1" "${root}/out"
}
quiet() {
	[ ! -s "${root}/out" ]
}
keeps_local_d() {
	! grep "^livecd/rm:" "$1" | grep -qE "(^| )/etc(/local\.d)?/?( |$)"
}

rm -f "${root}/helper-fails"
run "${stub}:${tools}"
check "runs the helper" helper_ran
check "exits 0 when the helper works" rc_is 0
check "is quiet when the helper works" quiet
check "removes itself when the helper works" test ! -e "${copy}"

touch "${root}/helper-fails"
run "${stub}:${tools}"
check "runs the helper again after a failed boot" helper_ran
check "exits 0 when the helper fails" rc_is 0
check "shows the failing helper's output" says "helper output"
check "warns when the helper fails" says "pentoo-trust-helper failed"
check "stays for the next boot when the helper fails" test -e "${copy}"

run "${tools}"
check "exits 0 without a helper installed" rc_is 0
check "is quiet without a helper installed" quiet
check "stays for a later pentoo-core without a helper installed" test -e "${copy}"

check "is executable" test -x "${hook}"
spec=${livecd}/specs/livecd-stage2-common.spec
check "livecd/rm keeps /etc/local.d" keeps_local_d "${spec}"
check "livecd/root_overlay is the overlay holding the hook" \
	grep -q "^livecd/root_overlay: /usr/src/pentoo/pentoo-livecd/livecd/root_overlay$" "${spec}"

exit "${failed}"
