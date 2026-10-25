#!/bin/bash
# Check that catalyst_clean from automation/pentoo_functions.sh removes the
# catalyst tmp dir of the stage it is run for and nothing else, since several
# stages can build at the same time.  Runs in a private user and mount
# namespace with tmpfs over /var/tmp and /catalyst, so it is safe to run on
# the build host.
#
# usage: test-catalyst-clean.sh
set -euo pipefail

functions=$(cd "$(dirname "$0")/../automation" && pwd)/pentoo_functions.sh

# shellcheck disable=SC2016
exec unshare --map-root-user --mount bash -euc '
	functions=$1
	mount -t tmpfs none /var/tmp
	[ ! -d /catalyst ] || mount -t tmpfs none /catalyst
	tmp=/var/tmp/catalyst/tmp/hardened

	# stage as passed to pentoo_single.sh, then the tmp dir catalyst uses for it
	stages="
		stage1 stage1-amd64-2026.0
		stage2 stage2-amd64-2026.0
		stage3 stage3-amd64-2026.0
		stage4 stage4-amd64-2026.0
		stage4-pentoo stage4-amd64-pentoo-2026.0
		stage4-pentoo-core stage4-amd64-pentoo-core-2026.0
		stage4-pentoo-full stage4-amd64-pentoo-full-2026.0
		stage4-docker stage4-amd64-docker-2026.0
		binpkg-update stage4-amd64-binpkg-update-2026.0
		binpkg-update-seed stage4-amd64-binpkg-update-2026.0
		livecd-stage2 livecd-stage2-amd64-2026.0
		livecd-stage2-core livecd-stage2-amd64-core-2026.0
		livecd-stage2-full livecd-stage2-amd64-full-2026.0
	"
	dirs=$(echo "${stages}" | awk "NF {print \$2}" | sort -u)

	failed=0
	while read -r stage dir; do
		[ -n "${stage}" ] || continue
		rm -rf "${tmp}"
		mkdir -p "${tmp}"
		for d in ${dirs}; do
			mkdir "${tmp}/${d}"
			touch "${tmp}/${d}.lock"
		done
		(arch=amd64; . "${functions}"; catalyst_clean post)
		problems=
		for d in ${dirs}; do
			if [ "${d}" = "${dir}" ]; then
				[ ! -e "${tmp}/${d}" ] && [ ! -e "${tmp}/${d}.lock" ] || problems+=" kept ${d}"
			else
				[ -d "${tmp}/${d}" ] && [ -e "${tmp}/${d}.lock" ] || problems+=" removed ${d}"
			fi
		done
		if [ -n "${problems}" ]; then
			echo "FAIL ${stage}:${problems}"
			failed=1
		else
			echo "ok   ${stage}"
		fi
	done <<< "${stages}"
	exit "${failed}"
' test-catalyst-clean "${functions}"
