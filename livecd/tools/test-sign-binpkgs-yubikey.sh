#!/bin/bash
# Hardware test for the binpkg signing key: sign and verify a few quickpkg
# gpkgs with the key on the YubiKey, running automation/pentoo_sign_binpkgs.sh
# as the build host does but with temp GnuPG homes, so neither ~/.gnupg nor
# /root is used.  Asks for the user PIN and reports the time per signature.
#
# With --wrong-pin it also checks that a wrong PIN file costs exactly one PIN
# try and that the next run refuses to use it, then resets the counter with
# the right PIN.  If a wrong PIN ever costs more than one try, unblock the PIN
# with: ykman --device SERIAL openpgp access unblock-pin
#
# usage: test-sign-binpkgs-yubikey.sh [--wrong-pin] SERIAL PUBKEY.asc

# shellcheck disable=SC2329 # functions called through check and trap
set -euo pipefail

wrong_pin=
if [ "${1:-}" = --wrong-pin ]; then
	wrong_pin=1
	shift
fi
[ "$#" = 2 ] || { echo "usage: ${0##*/} [--wrong-pin] SERIAL PUBKEY.asc" >&2; exit 1; }
serial=$1
pubkey=$(realpath "$2")
# the signing home's scdaemon takes the first YubiKey reader it finds
[ "$(ykman list --serials)" = "${serial}" ] || { echo "plug in only the YubiKey with serial ${serial}" >&2; exit 1; }

sign=$(cd "$(dirname "$0")/../automation" && pwd)/pentoo_sign_binpkgs.sh
root=$(mktemp -d)
# portage verifies as nobody when run as root
chmod 755 "${root}"
export BINPKG_SIGN_HOME=${root}/sign BINPKG_VERIFY_HOME=${root}/verify
pkgdir=${root}/packages
log=${root}/log
failed=0
cleanup() {
	local home
	for home in "${BINPKG_SIGN_HOME}" "${BINPKG_VERIFY_HOME}"; do
		[ ! -d "${home}" ] || gpgconf --homedir "${home}" --kill all
	done
	rm -rf "${root}"
}
trap cleanup EXIT

check() {
	local name=$1
	shift
	printf '...  %s' "${name}"
	if "$@" > "${log}" 2>&1; then
		printf '\rok   %s\n' "${name}"
	else
		printf '\rFAIL %s\n' "${name}"
		sed 's/^/     /' "${log}"
		failed=1
	fi
}

fails() {
	! "$@"
}

pin_tries() {
	ykman --device "${serial}" openpgp info | awk '/^PIN tries remaining/ {print $NF}'
}

lock_card() {
	gpgconf --homedir "${BINPKG_SIGN_HOME}" --kill all
}

echo "building test packages"
for atom in sys-apps/sed sys-apps/grep app-arch/gzip; do
	PKGDIR=${pkgdir} BINPKG_FORMAT=gpkg FEATURES="-binpkg-signing binpkg-multi-instance compress-index" \
		quickpkg --include-config=y "${atom}" > /dev/null
done

check "--init finds the key on the card" "${sign}" --init "${pubkey}"
read -r -s -p "User PIN of YubiKey ${serial} (not shown as you type, end with Enter): " pin
echo
(umask 077; printf '%s\n' "${pin}" > "${BINPKG_SIGN_HOME}/pin")
unset pin
check "--test-pin signs with the card" "${sign}" --test-pin

start=$(date +%s.%N)
check "signing the packages succeeds" "${sign}" "${pkgdir}"
end=$(date +%s.%N)
# each gpkg gets a signature for its metadata, its image and its Manifest
awk -v s="${start}" -v e="${end}" 'BEGIN {printf "     %.2f s for 3 packages, at most %.2f s per signature\n", e - s, (e - s) / 9}'
check "--verify passes" "${sign}" --verify "${pkgdir}"

if [ -n "${wrong_pin}" ]; then
	cp "${BINPKG_SIGN_HOME}/pin" "${root}/right-pin"
	lock_card
	check "the card starts with 3 PIN tries" test "$(pin_tries)" = 3
	echo wrong-pin > "${BINPKG_SIGN_HOME}/pin"
	check "--test-pin rejects a wrong PIN file" fails "${sign}" --test-pin
	check "a wrong PIN costs exactly one try" test "$(pin_tries)" = 2
	lock_card
	check "a run refuses a PIN file once a try is gone" fails "${sign}" "${pkgdir}"
	check "the refused run costs no try" test "$(pin_tries)" = 2
	cp "${root}/right-pin" "${BINPKG_SIGN_HOME}/pin"
	lock_card
	check "--test-pin with the right PIN succeeds" "${sign}" --test-pin
	check "the right PIN resets the tries to 3" test "$(pin_tries)" = 3
	echo "     PIN tries left: $(pin_tries)"
fi

exit "${failed}"
