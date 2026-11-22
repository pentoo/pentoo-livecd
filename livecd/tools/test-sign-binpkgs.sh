#!/bin/bash
# Check automation/pentoo_sign_binpkgs.sh and pentoo_verify_binpkgs.py on real
# gpkgs made with quickpkg.  A passphrase-protected NIST P-384 key in a temp
# GnuPG home stands in for the YubiKey, its passphrase for the PIN.  Needs
# portage and gnupg but no root and no card: run it on a Gentoo host, or the
# way CI does:
#
#   docker create --name portage gentoo/portage
#   docker run --rm --volumes-from portage -v "$PWD":/src -w /src gentoo/stage3 livecd/tools/test-sign-binpkgs.sh
#
# usage: [TEST_VERBOSE=1] test-sign-binpkgs.sh

# shellcheck disable=SC2329 # functions called through check and trap
set -euo pipefail

sign=$(cd "$(dirname "$0")/../automation" && pwd)/pentoo_sign_binpkgs.sh
root=$(mktemp -d)
# portage verifies as nobody when run as root
chmod 755 "${root}"
cleanup() {
	local home
	for home in "${root}"/gnupg-*; do
		[ ! -d "${home}" ] || gpgconf --homedir "${home}" --kill all
	done
	rm -rf "${root}"
}
trap cleanup EXIT

sign_home=${root}/gnupg-sign
verify_home=${root}/gnupg-verify
rogue_home=${root}/gnupg-rogue
empty_home=${root}/gnupg-empty
pkgdir=${root}/packages
log=${root}/log
failed=0

for home in "${sign_home}" "${rogue_home}" "${empty_home}"; do
	install -d -m 0700 "${home}"
	echo disable-scdaemon > "${home}/gpg-agent.conf"
done

# description, then a command that succeeds when the check passes
check() {
	local name=$1
	shift
	if "$@" > "${log}" 2>&1; then
		echo "ok   ${name}"
		[ -z "${TEST_VERBOSE:-}" ] || sed 's/^/     /' "${log}"
	else
		echo "FAIL ${name}"
		sed 's/^/     /' "${log}"
		failed=1
	fi
}

fails() {
	! "$@"
}

run() {
	BINPKG_SIGN_HOME=${BINPKG_SIGN_HOME:-${sign_home}} BINPKG_VERIFY_HOME=${BINPKG_VERIFY_HOME:-${verify_home}} "${sign}" "$@"
}

lock_card() {
	gpgconf --homedir "${sign_home}" --kill gpg-agent
}

quickpkg_into() {
	PKGDIR=$1 BINPKG_FORMAT=gpkg FEATURES="-binpkg-signing binpkg-multi-instance compress-index" \
		quickpkg --include-config=y "$2" > /dev/null
}

snapshot() {
	find "${pkgdir}" -type f -printf '%P %s %T@\n' | sort
}

all_signed() {
	local f
	while IFS= read -r -d '' f; do
		tar -tf "${f}" | grep '\.sig$' > /dev/null || { echo "unsigned: ${f}"; return 1; }
	done < <(find "${pkgdir}" -name '*.gpkg.tar' -print0)
}

unchanged() {
	diff "$1" <(snapshot)
}

gpg --homedir "${sign_home}" --batch --quiet --pinentry-mode loopback --passphrase test-pin \
	--quick-gen-key 'Pentoo binpkg signing test <test@example.invalid>' nistp384 sign 900d 2> /dev/null
gpg --homedir "${rogue_home}" --batch --quiet --pinentry-mode loopback --passphrase '' \
	--quick-gen-key 'Rogue <rogue@example.invalid>' nistp384 sign 900d 2> /dev/null
fpr=$(gpg --homedir "${sign_home}" --batch --with-colons --list-keys 2> /dev/null | awk -F: '$1 == "fpr" {print $10; exit}')
rogue_fpr=$(gpg --homedir "${rogue_home}" --batch --with-colons --list-keys 2> /dev/null | awk -F: '$1 == "fpr" {print $10; exit}')
gpg --homedir "${sign_home}" --batch --armor --export "${fpr}" > "${root}/key.asc"
lock_card

for atom in sys-apps/sed sys-apps/grep app-arch/gzip; do
	quickpkg_into "${pkgdir}" "${atom}"
done
cp -a "${pkgdir}" "${root}/unsigned"
before=${root}/before
snapshot > "${before}"

check "--init sets up the verify home" run --init "${root}/key.asc"
check "--init records the signing key" test "$(cat "${sign_home}/signing-key" 2> /dev/null)" = "${fpr}"
check "--init refuses to redo the verify home" fails run --init "${root}/key.asc"

check "signing is off without the PIN file" run "${pkgdir}"
check "signing off leaves the packages alone" unchanged "${before}"

echo wrong-pin > "${sign_home}/pin"
check "--test-pin rejects a wrong PIN file" fails run --test-pin
check "a wrong PIN file fails the run" fails run "${pkgdir}"
check "a wrong PIN file leaves the packages alone" unchanged "${before}"
lock_card

echo test-pin > "${sign_home}/pin"
chmod 600 "${sign_home}/pin"
check "--test-pin accepts the right PIN file" run --test-pin
lock_card
check "signing with the PIN file succeeds" run "${pkgdir}"
check "every package is signed" all_signed
check "--verify passes" run --verify "${pkgdir}"

signed=${root}/signed
snapshot > "${signed}"
check "a second run succeeds" run "${pkgdir}"
check "a second run changes nothing" unchanged "${signed}"

quickpkg_into "${pkgdir}" app-arch/bzip2
check "a run with a new package succeeds" run "${pkgdir}"
check "the new package is signed" all_signed
check "the old packages are left alone" diff <(grep '\.gpkg\.tar ' "${signed}") <(snapshot | grep '\.gpkg\.tar ' | grep -v '^app-arch/bzip2/')

victim=$(cd "${pkgdir}" && find . -path './sys-apps/sed/*.gpkg.tar' -printf '%P\n')
cp -a "${pkgdir}/${victim}" "${root}/victim"

cp -a "${root}/unsigned/${victim}" "${pkgdir}/${victim}"
BINPKG_GPG_SIGNING_GPG_HOME=${rogue_home} BINPKG_GPG_SIGNING_KEY=${rogue_fpr} \
	BINPKG_GPG_SIGNING_BASE_COMMAND="/usr/bin/gpg --sign --armor [PORTAGE_CONFIG]" \
	gpkg-sign --allow-unsigned "${pkgdir}/${victim}" > /dev/null 2>&1
touch -r "${root}/victim" "${pkgdir}/${victim}"
check "--verify rejects a package signed by another key" fails run --verify "${pkgdir}"
check "a run rejects a package signed by another key" fails run "${pkgdir}"
cp -a "${root}/victim" "${pkgdir}/${victim}"
check "a run succeeds once the package is replaced" run "${pkgdir}"

# inside the image member, as tar padding isn't covered by any digest
offset=$(python3 -I -c '
import sys, tarfile
image = [m for m in tarfile.open(sys.argv[1]) if m.name.endswith("/image.tar.zst")][0]
print(image.offset_data + image.size // 2)' "${pkgdir}/${victim}")
printf '\377' | dd of="${pkgdir}/${victim}" bs=1 seek="${offset}" conv=notrunc status=none
touch -r "${root}/victim" "${pkgdir}/${victim}"
check "--verify rejects a tampered package" fails run --verify "${pkgdir}"
cp -a "${root}/victim" "${pkgdir}/${victim}"

touch "${pkgdir}/${victim}"
check "--verify rejects a stale index" fails run --verify "${pkgdir}"
check "a run refreshes a stale index" run "${pkgdir}"

check "a keyring without the key rejects the packages" fails env BINPKG_VERIFY_HOME="${empty_home}" "${sign}" --verify "${pkgdir}"

exit "${failed}"
