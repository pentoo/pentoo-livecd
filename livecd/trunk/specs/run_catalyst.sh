#!/bin/sh

set -e

ARCH="$1"

#first we prep directories and build all the spec files
for arch in ${ARCH}
do
	mkdir -p /catalyst/release/Pentoo_${arch}
	chmod 777 /catalyst/release/Pentoo_${arch}

	for stage in stage1 stage2 stage3 stage4 livecd-stage1 livecd-stage2
	do
		./build_spec.sh ${arch} ${stage} > /tmp/${arch}-${stage}.spec
	done
done

#then the actual builds
for arch in ${ARCH}
do
	for stage in stage1 stage2 stage3 stage4 livecd-stage1 livecd-stage2
	do
		catalyst -f /tmp/${arch}-${stage}.spec
		if [ $? -ne 0 ]; then
			catalyst -f /tmp/${arch}-${stage}.spec
			if [ $? -ne 0 ]; then
				catalyst -f /tmp/${arch}-${stage}.spec
				if [ $? -ne 0 ]; then
					catalyst -f /tmp/${arch}-${stage}.spec
				fi
			fi
		fi
	done
done

#last generate the sig and torrent
for arch in ${ARCH}
do
	gpg --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
	/catalyst/release/Pentoo_${arch}/pentoo-${arch}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_$(grep RC= build_spec.sh | cut -d'=' -f2).iso.DIGESTS
	volid="Pentoo Linux_${arch}_$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_$(grep RC= build_spec.sh | cut -d'=' -f2)"
	mktorrent -a http://tracker.cryptohaze.com/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}
done
