#!/bin/bash
# Check that public mirrors serve the signed binpkgs.  Signing a gpkg changes
# its SIZE and MTIME, so each mirror's Packages index is compared, entry by
# entry, with the local index that pentoo_sign_binpkgs.sh already verified.
# Reports entries missing on the mirror, extra on the mirror and entries
# whose SIZE or MTIME differ.  Exits 0 only if every mirror and dir matches.
#
# usage: check-mirror-signed.sh [-l LOCAL_ROOT] [-m MIRROR_BASE]... [DIR...]
set -euo pipefail

local_root=/mnt/mirror/local_mirror/Packages
mirrors=()

usage() {
	echo "usage: ${0##*/} [-l LOCAL_ROOT] [-m MIRROR_BASE]... [DIR...]" >&2
	exit 2
}

while getopts l:m:h opt; do
	case "${opt}" in
		l) local_root=${OPTARG} ;;
		m) mirrors+=("${OPTARG}") ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))

if [ "${#mirrors[@]}" -eq 0 ]; then
	mirrors=(
		https://pentoo.glpgs.io/Packages/
		https://ftp.acc.umu.se/mirror/pentoo.ch/Packages/
		https://pentoo.osuosl.org/Packages/
		https://www.pentoo.ch/isos/Packages/
	)
fi

if [ ! -d "${local_root}" ]; then
	echo "${0##*/}: local root ${local_root} is not a directory" >&2
	exit 2
fi

dirs=("$@")
if [ "${#dirs[@]}" -eq 0 ]; then
	for p in "${local_root}"/*/Packages; do
		[ -f "${p}" ] || continue
		p=${p%/Packages}
		dirs+=("${p##*/}")
	done
fi
if [ "${#dirs[@]}" -eq 0 ]; then
	echo "${0##*/}: no dirs with a Packages file in ${local_root}" >&2
	exit 2
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

# entries are keyed by PATH, or CPV and BUILD_ID without it
compare() {
	python3 -I -c '
import sys

def load(name):
	with open(name, encoding="utf-8", errors="replace") as f:
		stanzas = f.read().split("\n\n")
	out = {}
	for s in stanzas[1:]:
		d = {}
		for line in s.splitlines():
			k, sep, v = line.partition(": ")
			if sep:
				d[k] = v
		if "CPV" not in d and "PATH" not in d:
			continue
		key = d.get("PATH") or d["CPV"] + "-" + d.get("BUILD_ID", "")
		out[key] = (d.get("SIZE"), d.get("MTIME"))
	return out

loc, mir = load(sys.argv[1]), load(sys.argv[2])
stale = sorted(k for k in loc if k in mir and loc[k] != mir[k])
missing = sorted(k for k in loc if k not in mir)
extra = sorted(k for k in mir if k not in loc)
label = sys.argv[3]
if not (stale or missing or extra):
	print("ok   %s: %d packages match" % (label, len(loc)))
	sys.exit(0)
print("FAIL %s: %d stale, %d missing, %d extra" % (label, len(stale), len(missing), len(extra)))
for what, keys in (("stale", stale), ("missing", missing), ("extra", extra)):
	for k in keys[:10]:
		detail = ""
		if what == "stale":
			detail = " (local %s/%s, mirror %s/%s)" % (loc[k] + mir[k])
		print("       %s: %s%s" % (what, k, detail))
	if len(keys) > 10:
		print("       %s: ... and %d more" % (what, len(keys) - 10))
sys.exit(1)
' "$@"
}

problems=0
for base in "${mirrors[@]}"; do
	base=${base%/}
	for d in "${dirs[@]}"; do
		label="${base}/${d}"
		if [ ! -f "${local_root}/${d}/Packages" ]; then
			echo "FAIL ${label}: no local ${local_root}/${d}/Packages"
			problems=$((problems + 1))
			continue
		fi
		if ! curl -fsSL --max-time 300 -o "${tmp}/Packages" "${label}/Packages" 2> "${tmp}/err"; then
			echo "FAIL ${label}: cannot fetch ${label}/Packages: $(tr '\n' ' ' < "${tmp}/err")"
			problems=$((problems + 1))
			continue
		fi
		compare "${local_root}/${d}/Packages" "${tmp}/Packages" "${label}" || problems=$((problems + 1))
		# clients fetch Packages.gz first, so a stale one hides a fresh Packages
		[ -f "${local_root}/${d}/Packages.gz" ] || continue
		if ! curl -fsSL --max-time 300 -o "${tmp}/Packages.gz" "${label}/Packages.gz" 2> "${tmp}/err" ||
			! gzip -dc "${tmp}/Packages.gz" > "${tmp}/Packages" 2>> "${tmp}/err"; then
			echo "FAIL ${label}: cannot fetch ${label}/Packages.gz: $(tr '\n' ' ' < "${tmp}/err")"
			problems=$((problems + 1))
			continue
		fi
		compare "${local_root}/${d}/Packages" "${tmp}/Packages" "${label}/Packages.gz" || problems=$((problems + 1))
	done
done

if [ "${problems}" -ne 0 ]; then
	echo "${problems} mirror/dir combination(s) do not match" >&2
	exit 1
fi
