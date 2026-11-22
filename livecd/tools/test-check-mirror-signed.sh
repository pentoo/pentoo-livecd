#!/bin/bash
# Test check-mirror-signed.sh against hand-written Packages indexes served
# from 127.0.0.1 by python's http.server.  Needs no root and no network.
#
# usage: test-check-mirror-signed.sh
# shellcheck disable=SC2329 # the functions run through check and trap
set -euo pipefail

tool=$(cd "$(dirname "$0")" && pwd)/check-mirror-signed.sh
root=$(mktemp -d)
server=
cleanup() {
	[ -z "${server}" ] || kill "${server}" 2>/dev/null || true
	rm -rf "${root}"
}
trap cleanup EXIT

fail=0
check() {
	local name=$1
	shift
	if "$@"; then
		echo "ok   ${name}"
	else
		echo "FAIL ${name}"
		fail=1
	fi
}

header() {
	printf 'ARCH: amd64\nPACKAGES: 3\nTIMESTAMP: 1795298411\nVERSION: 0\n\n'
}
stanza() {
	printf 'BUILD_ID: 1\nCPV: %s\nMTIME: %s\nPATH: %s\nSIZE: %s\n\n' "$1" "$3" "$2" "$4"
}

local_root="${root}/local"
mkdir -p "${local_root}/dir_a" "${local_root}/dir_b"
{
	header
	stanza sys-apps/sed-4.10-r1 sys-apps/sed/sed-4.10-r1-1.gpkg.tar 1795298411 40960
	stanza sys-apps/which-2.23 sys-apps/which/which-2.23-1.gpkg.tar 1795298412 20480
	stanza app-misc/foo-1 app-misc/foo/foo-1-1.gpkg.tar 1795298413 10240
} > "${local_root}/dir_a/Packages"
{
	header
	stanza sys-apps/grep-3.11 sys-apps/grep/grep-3.11-1.gpkg.tar 1795298414 30720
	stanza sys-apps/gawk-5.3 sys-apps/gawk/gawk-5.3-1.gpkg.tar 1795298415 51200
} > "${local_root}/dir_b/Packages"
gzip -k "${local_root}/dir_a/Packages"

good="${root}/good"
bad="${root}/bad"
cp -r "${local_root}" "${good}"
cp -r "${local_root}" "${bad}"
{
	header
	stanza sys-apps/sed-4.10-r1 sys-apps/sed/sed-4.10-r1-1.gpkg.tar 1795298411 99999
	stanza sys-apps/which-2.23 sys-apps/which/which-2.23-1.gpkg.tar 1795298412 20480
	stanza app-misc/bar-2 app-misc/bar/bar-2-1.gpkg.tar 1795298416 5120
} > "${bad}/dir_a/Packages"
rm -r "${bad}/dir_b"
gzstale="${root}/gzstale"
cp -r "${local_root}" "${gzstale}"
gzip -c "${bad}/dir_a/Packages" > "${gzstale}/dir_a/Packages.gz"

# python picks the port and prints it once it is listening
serve() {
	local dir=$1 out=$2
	python3 -I -c '
import functools, http.server, sys
h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
print(s.server_address[1], flush=True)
s.serve_forever()
' "${dir}" > "${out}" 2>/dev/null &
	server=$!
	for _ in $(seq 100); do
		[ -s "${out}" ] && return 0
		sleep 0.1
	done
	echo "server did not start" >&2
	return 1
}

serve "${root}" "${root}/port"
port=$(head -n1 "${root}/port")
good_url="http://127.0.0.1:${port}/good"
bad_url="http://127.0.0.1:${port}/bad"
gzstale_url="http://127.0.0.1:${port}/gzstale"

run() {
	"${tool}" -l "${local_root}" "$@" > "${root}/out" 2>&1
}
run_fails() {
	! run "$@"
}
lacks() {
	! grep -qF -- "$1" "${root}/out"
}
has() {
	grep -qF -- "$1" "${root}/out"
}

check "identical mirror passes" run -m "${good_url}"
check "identical mirror reports packages" has "ok   ${good_url}/dir_a: 3 packages match"
check "identical mirror reports Packages.gz" has "ok   ${good_url}/dir_a/Packages.gz: 3 packages match"

check "stale Packages.gz fails" run_fails -m "${gzstale_url}" dir_a
check "stale Packages.gz reported" has "FAIL ${gzstale_url}/dir_a/Packages.gz: 1 stale, 1 missing, 1 extra"
check "fresh Packages next to stale Packages.gz passes" has "ok   ${gzstale_url}/dir_a: 3 packages match"

check "bad mirror fails" run_fails -m "${bad_url}"
check "stale size reported" has "stale: sys-apps/sed/sed-4.10-r1-1.gpkg.tar"
check "missing entry reported" has "missing: app-misc/foo/foo-1-1.gpkg.tar"
check "extra entry reported" has "extra: app-misc/bar/bar-2-1.gpkg.tar"
check "summary counts" has "FAIL ${bad_url}/dir_a: 1 stale, 1 missing, 1 extra"
check "missing dir (404) reported" has "FAIL ${bad_url}/dir_b: cannot fetch"

check "missing dir alone fails" run_fails -m "${bad_url}" dir_b
check "explicit good dir ignores bad dir" run -m "${good_url}" dir_a
check "explicit dir is the only one checked" lacks "dir_b"
check "bad dir alone fails" run_fails -m "${bad_url}" dir_a

check "repeated -m passes when all good" run -m "${good_url}" -m "${good_url}/"
check "repeated -m fails when one is bad" run_fails -m "${good_url}" -m "${bad_url}"
check "repeated -m reports the good one" has "ok   ${good_url}/dir_b: 2 packages match"

check "unreachable mirror fails" run_fails -m "http://127.0.0.1:1/x"
check "nonexistent local root fails" run_fails -l "${root}/nonexistent" -m "${good_url}"

exit "${fail}"
