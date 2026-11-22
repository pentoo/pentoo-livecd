#!/bin/bash
# Run the lines the Dockerfiles use to trust the binhost keys before they
# emerge, in the pentoo-core image they build on, with the portage tree and a
# pentoo-overlay checkout mounted at /var/db/repos as the builds mount them.
# With an overlay that has pentoo-trust-helper they have to leave the Pentoo
# binhost key fully trusted in /etc/portage/gnupg; with one that doesn't they
# have to do nothing and succeed.  Needs docker, no privileges.
#
#   docker create --name portage gentoo/portage
#   test-docker-trust.sh OVERLAY [image]

# shellcheck disable=SC2329 # functions called through check and trap
set -euo pipefail

livecd=$(cd "$(dirname "$0")/.." && pwd)
overlay=$(realpath "${1:?usage: $0 OVERLAY [image]}")
image=${2:-pentoolinux/pentoo-core:latest}
fpr=FFB957A9397712C1EC079E30BE0908FC837B76F4
root=$(mktemp -d)
trap 'rm -rf "${root}"' EXIT
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

mapfile -t blocks < <(for dockerfile in "${livecd}"/automation/docker/*/Dockerfile; do
	grep -A1 '^  helper=.*pentoo-trust-helper' "${dockerfile}" | sed -e 's/^[[:space:]]*//' -e 's/ && \\$//' | paste -sd ';'
done | grep . | sort -u)
check "every Dockerfile uses the same trust lines" test "${#blocks[@]}" = 1
lines=${blocks[0]}

# shellcheck disable=SC2016 # expanded in the container
script='
bash -c "$1" > /tmp/trust.log 2>&1
echo "rc: $?"
validity=$(gpg --homedir /etc/portage/gnupg --with-colons --list-keys "$2" 2> /dev/null | awk -F: "\$1 == \"pub\" {print \$2; exit}")
echo "validity: ${validity:-none}"
'
run() {
	docker run --rm --volumes-from portage -v "$1":/var/db/repos/pentoo:ro \
		--entrypoint /bin/bash "${image}" -c "${script}" sh "${lines}" "${fpr}" 2>&1
}
says() {
	printf '%s\n' "$1" | grep -qxF -- "$2"
}

if [ -f "${overlay}/pentoo/pentoo-core/files/pentoo-trust-helper" ]; then
	out=$(run "${overlay}")
	printf '%s\n' "${out}" | sed 's/^/     /'
	check "with the helper in the overlay the lines succeed" says "${out}" "rc: 0"
	check "and the Pentoo binhost key is fully trusted" says "${out}" "validity: f"
else
	echo "info ${overlay} has no pentoo-trust-helper yet, only the case without it runs"
fi
mkdir -p "${root}/overlay/profiles"
echo pentoo > "${root}/overlay/profiles/repo_name"
out=$(run "${root}/overlay")
printf '%s\n' "${out}" | sed 's/^/     /'
check "without the helper the lines succeed" says "${out}" "rc: 0"
check "and trust nothing" says "${out}" "validity: none"

exit "${failed}"
