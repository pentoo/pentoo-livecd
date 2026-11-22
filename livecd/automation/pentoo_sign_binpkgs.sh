#!/bin/bash
# Sign the unsigned gpkg binpkgs in each PKGDIR with the binhost key on the
# YubiKey, refresh the PKGDIR's index and verify every package in it.  The
# card's user PIN file is the switch: without it this only says signing is
# off and exits 0.  See "Signing binpkgs" in README.md.
#
# usage: pentoo_sign_binpkgs.sh PKGDIR...
#        pentoo_sign_binpkgs.sh --verify PKGDIR...
#        pentoo_sign_binpkgs.sh --init PUBKEY.asc
#        pentoo_sign_binpkgs.sh --test-pin
set -euo pipefail

sign_home=${BINPKG_SIGN_HOME:-/root/.gnupg-binpkg-signing}
verify_home=${BINPKG_VERIFY_HOME:-/etc/portage/gnupg-binpkg-verify}
pin=${sign_home}/pin
lock=${sign_home}/sign.lock
pinentry="--pinentry-mode loopback --passphrase-file ${pin}"
here=$(cd "$(dirname "$0")" && pwd)

die() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
	exit 1
}

verify() {
	[ -d "${verify_home}" ] || die "no ${verify_home}, run --init first"
	BINPKG_GPG_VERIFY_GPG_HOME=${verify_home} python3 "${here}/pentoo_verify_binpkgs.py" "$@"
}

init() {
	local pubkey=$1 fpr
	[ -f "${pubkey}" ] || die "no ${pubkey}"
	[ ! -e "${verify_home}" ] || die "${verify_home} already exists"
	if [ ! -d "${sign_home}" ]; then
		install -d -m 0700 "${sign_home}"
		printf 'disable-ccid\npcsc-shared\nreader-port Yubico YubiKey\n' > "${sign_home}/scdaemon.conf"
	fi
	fpr=$(gpg --homedir "${sign_home}" --batch --with-colons --show-keys "${pubkey}" |
		awk -F: '$1 == "pub" {p = 1; next} p && $1 == "fpr" {print $10; p = 0}')
	[ "$(wc -w <<< "${fpr}")" = 1 ] || die "${pubkey} must hold exactly one key"
	gpg --homedir "${sign_home}" --batch --quiet --import "${pubkey}"
	# the card status creates the stubs that point gpg at the key on the card
	gpg --homedir "${sign_home}" --batch --list-secret-keys "${fpr}" > /dev/null 2>&1 ||
		gpg --homedir "${sign_home}" --batch --card-status > /dev/null ||
		die "can't read the YubiKey, is it plugged in and pcscd running?"
	gpg --homedir "${sign_home}" --batch --list-secret-keys "${fpr}" > /dev/null 2>&1 ||
		die "the YubiKey doesn't hold the secret key of ${fpr}"

	install -d -m 0755 "${verify_home}"
	echo disable-scdaemon > "${verify_home}/gpg-agent.conf"
	gpg --homedir "${verify_home}" --batch --quiet --import "${pubkey}"
	echo "${fpr}:6:" | gpg --homedir "${verify_home}" --batch --quiet --import-ownertrust
	gpg --homedir "${verify_home}" --batch --quiet --check-trustdb
	gpgconf --homedir "${verify_home}" --kill all
	# portage verifies as nobody:nogroup when run as root
	chmod -R go+rX "${verify_home}"

	echo "${fpr}" > "${sign_home}/signing-key"
	echo "set up ${fpr}; signing turns on once the user PIN is in ${pin} (mode 0600)"
}

load_key() {
	[ -f "${sign_home}/signing-key" ] || die "no ${sign_home}/signing-key, run --init first"
	[ -d "${verify_home}" ] || die "no ${verify_home}, run --init first"
	key=$(< "${sign_home}/signing-key")
}

test_signature() {
	# shellcheck disable=SC2086 # pinentry is a list of options
	flock "${lock}" gpg --homedir "${sign_home}" --batch --no-tty ${pinentry} \
		--local-user "${key}" --digest-algo SHA512 --armor --detach-sign < /dev/null > /dev/null
}

# a wrong PIN file costs one try per run, so three runs would block the PIN
check_pin_retries() {
	local retries
	retries=$(gpg --homedir "${sign_home}" --batch --with-colons --card-status 2> /dev/null |
		awk -F: '$1 == "pinretry" {print $2}') || true
	[ -z "${retries}" ] || [ "${retries}" -ge 3 ] ||
		die "the YubiKey has ${retries} PIN tries left, not using ${pin}; fix it, then run --test-pin to reset the counter"
}

sign() {
	local pkgdir status=0 features f
	local -a unsigned
	if [ ! -f "${pin}" ]; then
		echo "binpkg signing is off (no ${pin}), leaving $* unsigned" >&2
		return 0
	fi
	load_key
	exec 9> "${sign_home}/run.lock"
	flock 9
	check_pin_retries
	test_signature || die "test signature with ${key} failed: is the YubiKey plugged in and ${pin} right?"

	export BINPKG_GPG_SIGNING_GPG_HOME=${sign_home}
	export BINPKG_GPG_SIGNING_KEY=${key}
	export BINPKG_GPG_VERIFY_GPG_HOME=${verify_home}
	export BINPKG_GPG_SIGNING_BASE_COMMAND="/usr/bin/flock ${lock} /usr/bin/gpg --sign --armor ${pinentry} [PORTAGE_CONFIG]"
	for pkgdir in "$@"; do
		[ -d "${pkgdir}" ] || { echo "no ${pkgdir}" >&2; status=1; continue; }
		unsigned=()
		while IFS= read -r -d '' f; do
			tar -tf "${f}" 2> /dev/null | grep '\.sig$' > /dev/null || unsigned+=("${f}")
		done < <(find "${pkgdir}" -name '*.gpkg.tar' -type f -print0)
		echo "signing ${#unsigned[@]} binpkgs in ${pkgdir}"
		if [ "${#unsigned[@]}" -gt 0 ]; then
			printf '%s\0' "${unsigned[@]}" | xargs -0 -n1 -P4 gpkg-sign --allow-unsigned || status=1
		fi
		features="${FEATURES:-}"
		[ ! -f "${pkgdir}/Packages.gz" ] || features+=" compress-index"
		PKGDIR=${pkgdir} FEATURES=${features} emaint binhost --fix || status=1
		verify "${pkgdir}" || status=1
	done
	return "${status}"
}

case "${1:-}" in
	"")
		die "usage: ${0##*/} PKGDIR... | --verify PKGDIR... | --init PUBKEY.asc | --test-pin"
		;;
	--verify)
		shift
		[ "$#" -gt 0 ] || die "--verify needs a PKGDIR"
		verify "$@"
		;;
	--init)
		[ "$#" = 2 ] || die "--init needs the public key file"
		init "$2"
		;;
	--test-pin)
		[ -f "${pin}" ] || die "no ${pin}"
		load_key
		test_signature || die "test signature with ${key} failed: is the YubiKey plugged in and ${pin} right?"
		echo "${pin} works for ${key}"
		;;
	*)
		sign "$@"
		;;
esac
