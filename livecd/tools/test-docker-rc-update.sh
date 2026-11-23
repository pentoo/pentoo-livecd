#!/bin/bash
# Run the Dockerfiles' rc-update lines in gentoo/stage3, which the stage4-docker
# tarball is built from. A docker build has no softlevel, and since openrc 0.64
# rc-update then works on the default runlevel instead of sysinit, so each line
# has to name its runlevel. Needs docker, no privileges.
#
# usage: test-docker-rc-update.sh [image]

# shellcheck disable=SC2329 # functions called through check
set -euo pipefail

livecd=$(cd "$(dirname "$0")/.." && pwd)
image=${1:-gentoo/stage3}
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

mapfile -t lines < <(grep -h 'rc-update' "${livecd}"/automation/docker/*/Dockerfile |
	grep -v '^[[:space:]]*#' | sed -e 's/^[[:space:]]*//' -e 's/ && \\$//')
check "the Dockerfiles have rc-update lines" test "${#lines[@]}" -gt 0
names_runlevel() {
	local line
	for line in "${lines[@]}"; do
		[[ ${line} =~ ^rc-update\ (del|delete|add)\ [^\ ]+\ [^\ ]+$ ]] || return 1
	done
}
check "every rc-update line names its runlevel" names_runlevel

services=$(printf '%s\n' "${lines[@]}" | awk '$2 ~ /^del/ { print $3 }' | sort -u | tr '\n' ' ')
# shellcheck disable=SC2016 # expanded in the container
script='
set -u
echo "openrc: $(cd /var/db/pkg/sys-apps && echo openrc-*)"
echo "softlevel: $([ -e /run/openrc/softlevel ] && echo yes || echo no)"
bash -c "$1"
echo "rc: $?"
for s in $2; do
	ls /etc/runlevels/*/"${s}" 2> /dev/null | sed "s/^/still in: /"
done
'
out=$(docker run --rm --entrypoint /bin/bash "${image}" -c "${script}" sh \
	"$(printf '%s && ' "${lines[@]}")true" "${services}" 2>&1) || true
printf '%s\n' "${out}" | sed 's/^/     /'
says() {
	printf '%s\n' "${out}" | grep -qxF -- "$1"
}
check "the image has no softlevel, like a docker build" says "softlevel: no"
check "the Dockerfile lines succeed" says "rc: 0"
none_left() {
	! printf '%s\n' "${out}" | grep -q '^still in: '
}
check "and leave ${services}in no runlevel" none_left

exit "${failed}"
