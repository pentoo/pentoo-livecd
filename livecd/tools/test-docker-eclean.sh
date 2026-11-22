#!/bin/bash
# Run the eclean-pkg line the Dockerfiles use to empty the binpkg locations,
# in the pentoo-core image they build on: it has to delete every binpkg in
# PKGDIR and in a binrepos.conf location, even ones of installed packages,
# and leave the installed packages and /var/empty alone.  Needs docker, no
# privileges.
#
# usage: test-docker-eclean.sh [image]

# shellcheck disable=SC2329 # functions called through check
set -euo pipefail

livecd=$(cd "$(dirname "$0")/.." && pwd)
image=${1:-pentoolinux/pentoo-core:latest}
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

mapfile -t lines < <(grep -h 'eclean-pkg' "${livecd}"/automation/docker/*/Dockerfile |
	grep -v '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/ && \\$//' | sort -u)
check "every Dockerfile uses the same eclean-pkg line" test "${#lines[@]}" = 1
line=${lines[0]}

# shellcheck disable=SC2016 # expanded in the container
script='
set -u
pkgdir=$(portageq pkgdir 2> /dev/null)
mkdir -p /etc/portage/binrepos.conf /var/cache/binhost/pentoo-binhost-1
printf "[test]\nsync-uri = http://127.0.0.1:1/\nlocation = /var/cache/binhost/pentoo-binhost-1\n" > /etc/portage/binrepos.conf/test.conf
quickpkg --include-config=y app-arch/gzip sys-apps/which > /dev/null 2>&1
cp -a "${pkgdir}"/. /var/cache/binhost/pentoo-binhost-1/
count() { find "${pkgdir}" /var/cache/binhost -type f \( -name "*.gpkg.tar" -o -name "*.tbz2" -o -name "*.xpak" \) | wc -l; }
installed=$(qlist -I | wc -l)
empty_before=$(find /var/empty -printf "%p %m %u %s\n" | sort)
echo "binpkgs before: $(count)"
eclean-pkg --deep > /dev/null 2>&1
echo "binpkgs after plain eclean-pkg --deep: $(count)"
bash -c "$1" > /dev/null 2>&1
echo "rc: $?"
echo "binpkgs after: $(count)"
echo "/var/empty changed: $([ "$(find /var/empty -printf "%p %m %u %s\n" | sort)" = "${empty_before}" ] && echo no || echo yes)"
echo "installed changed: $([ "$(qlist -I | wc -l)" = "${installed}" ] && echo no || echo yes)"
'
out=$(docker run --rm --entrypoint /bin/bash "${image}" -c "${script}" sh "${line}" 2>&1)
printf '%s\n' "${out}" | sed 's/^/     /'
says() {
	printf '%s\n' "${out}" | grep -qxF -- "$1"
}
check "the test puts 4 binpkgs in PKGDIR and a binrepos.conf location" says "binpkgs before: 4"
check "plain eclean-pkg --deep keeps them, since they're installed" says "binpkgs after plain eclean-pkg --deep: 4"
check "the Dockerfile line succeeds" says "rc: 0"
check "and deletes every binpkg in both locations" says "binpkgs after: 0"
check "and leaves the installed packages alone" says "installed changed: no"
check "and leaves /var/empty as it was" says "/var/empty changed: no"

exit "${failed}"
