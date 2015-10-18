#!/bin/sh

set -e

ARCH="$1"
PROFILE="$2"

if [ -z ${1} ] || [ -z ${2} ] ; then
	echo "need two params"
	exit
fi

if [ "${1}" = "x86" ]; then
        subarch="pentium-m"
elif [ "${1}" = "amd64" ]; then
        subarch="${1}"
else
	echo "Subarch must be x86 or amd64"
	exit 1
fi

#last generate the sig and torrent
RC="$(grep ^RC= build_spec.sh |cut -d'=' -f2)"
#RC="${RC:0:7}$(date "+%Y%m%d")"
for arch in ${ARCH}
do
	if [ -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}.iso.DIGESTS ]
	then
		GPG_TTY=$(tty) gpg --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
		/catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}.iso.DIGESTS

		volid="Pentoo_Linux_${arch}_${PROFILE}_$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}"
		mktorrent -a http://tracker.cryptohaze.com/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
		mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
	fi
done
