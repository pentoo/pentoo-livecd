#!/bin/bash
# Pretend-resolve the stage1 seed update or the stage3 @system build the way
# catalyst runs them, without root and without catalyst.  emerge runs in a
# private user and mount namespace whose /etc/portage holds the bootstrap
# profile and livecd/portage, whose /var/db/pkg is the seed's vdb (empty
# unless -v is given) and whose binpkgs are the given pkgcache, both mounted
# read-only.
#
# usage: bootstrap-resolve.sh [-o overlay] [-g gentoo] [-p pkgdir] [-v vdb] [-a arch] stage1|stage3
#   -o  pentoo overlay checkout (default: the installed pentoo repo)
#   -g  gentoo repo (default: the installed gentoo repo)
#   -p  binpkgs to offer, e.g. /catalyst/packages/amd64_23.0s-hardened-bootstrap
#   -v  the seed's var/db/pkg, unpacked from the stage4 (stage1) or stage2 (stage3) tarball
#   -a  amd64 (default) or x86
#
# Exits with emerge's status.
set -euo pipefail

usage() {
	sed -n '/^# usage:/,/^#$/s/^# //p' "$0" >&2
	exit 2
}

livecd=$(cd "$(dirname "$0")/.." && pwd)
overlay=
gentoo=
pkgdir=
vdb=
arch=amd64
while getopts o:g:p:v:a:h opt; do
	case ${opt} in
		o) overlay=$(realpath "${OPTARG}") ;;
		g) gentoo=$(realpath "${OPTARG}") ;;
		p) pkgdir=$(realpath "${OPTARG}") ;;
		v) vdb=$(realpath "${OPTARG}") ;;
		a) arch=${OPTARG} ;;
		*) usage ;;
	esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || usage
: "${overlay:=$(portageq get_repo_path / pentoo)}"
: "${gentoo:=$(portageq get_repo_path / gentoo)}"

case $1 in
	stage1)
		read -r -a seed < <(sed -n 's/^update_seed_command:"\(.*\)"$/\1/p' "${livecd}/specs/stage1-common.spec")
		args=(--buildpkg=n)
		for a in "${seed[@]}"; do
			[ "${a}" = --quiet ] || args+=("${a}")
		done
		;;
	stage3)
		args=(--usepkg --buildpkg --binpkg-respect-use=y --newuse -e --update --deep --with-bdeps=y @system)
		;;
	*) usage ;;
esac

profile=${overlay}/profiles/pentoo/hardened/linux/${arch}/23.0/split-usr/bootstrap
[ -d "${profile}" ] || { echo "no such profile: ${profile}" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-resolve.XXXXXX")
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}"/{portage/repos.conf,vdb,pkgs,edb,lib}
cp -r "${livecd}/portage/profile" "${work}/portage/profile"
ln -s "${profile}" "${work}/portage/make.profile"
cat > "${work}/portage/repos.conf/repos.conf" <<EOF
[DEFAULT]
main-repo = gentoo
[gentoo]
location = ${gentoo}
[pentoo]
location = ${overlay}
EOF
cat > "${work}/portage/make.conf" <<EOF
ACCEPT_LICENSE="Intel-SDP NVIDIA-CUDA"
FEATURES="-news -getbinpkg"
PORTAGE_BINHOST=""
PORTAGE_NICENESS=""
PKGDIR="${work}/pkgs"
EOF

# shellcheck disable=SC2016
unshare --map-root-user --mount bash -euc '
	work=$1 vdb=$2 pkgdir=$3
	shift 3
	ro_bind() {
		mount --bind "$1" "$2"
		mount -o remount,bind,ro "$2"
	}
	mount --bind "${work}/portage" /etc/portage
	mount --bind "${work}/edb" /var/cache/edb
	mount --bind "${work}/lib" /var/lib/portage
	ro_bind "${vdb:-${work}/vdb}" /var/db/pkg
	ro_bind "${pkgdir:-${work}/pkgs}" "${work}/pkgs"
	# only root is mapped in the namespace, so portage cannot chown to its own user
	PORTAGE_USERNAME=root PORTAGE_GRPNAME=root \
		exec nice emerge --pretend --backtrack=99 --verbose-conflicts "$@"
' bootstrap-resolve "${work}" "${vdb}" "${pkgdir}" "${args[@]}"
