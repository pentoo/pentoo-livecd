#!/bin/bash
# Wipe the OpenPGP application of one YubiKey and generate the binhost's
# binpkg signing key on it: NIST P-384 made on the card, sign and certify only,
# expiring in 900 days (the GLEP 63 limit), KDF on, touch off and the
# signature PIN asked once per session, so the build box can sign unattended.
# Everything runs in a throwaway GnuPG home; ~/.gnupg is never used.  Writes
# the public key, the revocation certificate and the fingerprint to OUTDIR.
# Interactive: it asks for confirmation, the user ID and the PINs.
#
# usage: binpkg-key-yubikey.sh SERIAL OUTDIR
set -euo pipefail

die() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
	exit 1
}

[ "$#" = 2 ] || die "usage: ${0##*/} SERIAL OUTDIR"
serial=$1
outdir=$2
[ ! -e "${outdir}/fingerprint" ] || die "${outdir} already holds a key"

# gpg picks the card by reader, not by serial, so only this YubiKey may be plugged in
[ "$(ykman list --serials)" = "${serial}" ] || die "plug in only the YubiKey with serial ${serial}"
yk() {
	ykman --device "${serial}" "$@"
}

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'gpgconf --kill all; rm -rf "${GNUPGHOME}"' EXIT
printf 'disable-ccid\npcsc-shared\nreader-port Yubico YubiKey\n' > "${GNUPGHOME}/scdaemon.conf"
GPG_TTY=$(tty)
export GPG_TTY

# ykman and scdaemon share the card, so scdaemon forgets what it read after each ykman step
card() {
	gpgconf --kill scdaemon
	gpg-card "$@"
}

yk openpgp info
echo
read -r -p "This deletes every OpenPGP key on YubiKey ${serial}. Type the serial to go on: " answer
[ "${answer}" = "${serial}" ] || die "not confirmed"
read -r -p "User ID for the key, e.g. 'Pentoo binpkg signing key <binhost@example.org>': " uid
[ -n "${uid}" ] || die "no user ID"

yk openpgp reset --force
echo "KDF setup: enter the default Admin PIN 12345678"
card kdf-setup
echo "Set the PINs.  The defaults are 123456 and 12345678.  The build box keeps the"
echo "user PIN in a file, so make it long and random (up to 127 characters)."
yk openpgp access change-pin
yk openpgp access change-admin-pin

echo "Generating NIST P-384 on the card"
card generate --algo=nistp384 OPENPGP.1
gpgconf --kill scdaemon
gpg --quick-gen-key "${uid}" card sign 900d

for slot in sig dec aut; do
	yk openpgp keys set-touch --force "${slot}" off
done
yk openpgp access set-signature-policy once

keys=$(gpg --batch --with-colons --list-keys 2> /dev/null)
fpr=$(awk -F: '$1 == "fpr" {print $10; exit}' <<< "${keys}")
rev=${GNUPGHOME}/openpgp-revocs.d/${fpr}.rev
info=$(yk openpgp info)
sig=$(yk openpgp keys info sig)
card_fpr=$(awk '/^Signature key/ {s = 1} s && /Fingerprint:/ {sub(/.*Fingerprint: */, ""); gsub(/ /, ""); print; exit}' <<< "${info}")
problems=()
[ "$(grep -c '^pub:' <<< "${keys}")" = 1 ] || problems+=("not exactly one key")
! grep -q '^sub:' <<< "${keys}" || problems+=("the key has subkeys")
[ "${#fpr}" = 40 ] && gpg --batch --export "${fpr}" | gpg --batch --list-packets | grep -q 'version 4, algo 19,' ||
	problems+=("not a v4 ECDSA key")
awk -F: -v now="$(date +%s)" '$1 == "pub" && $4 == 19 && $17 == "nistp384" && $7 > now + 899 * 86400 && $7 <= now + 900 * 86400 {ok = 1}
	END {exit !ok}' <<< "${keys}" || problems+=("not NIST P-384 expiring in 900 days")
[ "${card_fpr}" = "${fpr}" ] || problems+=("the card's signature key is ${card_fpr}, not ${fpr}")
grep -q 'Algorithm: *SECP384R1' <<< "${sig}" || problems+=("the card key isn't NIST P-384")
grep -q 'Origin: *GENERATED' <<< "${sig}" || problems+=("the card key wasn't generated on the card")
grep -q 'Touch policy: *Off' <<< "${sig}" || problems+=("touch is still on")
grep -q 'KDF enabled: *True' <<< "${info}" || problems+=("KDF is off")
grep -q 'Require PIN for signature: *Once' <<< "${info}" || problems+=("the signature PIN is asked every time")
[ -f "${rev}" ] || problems+=("no revocation certificate")

install -d -m 0700 "${outdir}"
gpg --batch --armor --export "${fpr}" > "${outdir}/${fpr}.asc"
[ ! -f "${rev}" ] || cp "${rev}" "${outdir}/"
echo "${fpr}" > "${outdir}/fingerprint"

echo
yk openpgp info
echo
gpg --batch --list-keys "${fpr}"
if [ "${#problems[@]}" -gt 0 ]; then
	printf 'PROBLEM: %s\n' "${problems[@]}" >&2
	exit 1
fi
echo "Key ${fpr} written to ${outdir}.  Keep ${fpr}.rev offline; the secret key exists only on the card."
