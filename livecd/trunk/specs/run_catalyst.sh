#!/bin/sh

#set -e

ARCH="$1"
PROFILE="$2"

#first we prep directories and build all the spec files
for arch in ${ARCH}
do
	rm -rf /catalyst/release/Pentoo_${arch}_${PROFILE} /catalyst/release/Pentoo*${arch}*.torrent
	mkdir -p /catalyst/release/Pentoo_${arch}_${PROFILE}
	chmod 777 /catalyst/release/Pentoo_${arch}_${PROFILE}

	for stage in stage1 stage2 stage3 stage4 livecd-stage1 livecd-stage2
	do
		#I have nfc why it's loosing exec all of a sudden but I can compensate
		chmod +x build_spec.sh
		./build_spec.sh ${arch} ${PROFILE} ${stage} > /tmp/${arch}-${PROFILE}-${stage}.spec
	done
done

#then the actual builds
for arch in ${ARCH}
do
	for stage in stage1 stage2 stage3 stage4 livecd-stage1 livecd-stage2
	do
		catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
		if [ $? -ne 0 ]; then
			catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
			if [ $? -ne 0 ]; then
				catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
				if [ $? -ne 0 ]; then
					catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
				fi
			fi
		fi
	done
done

#sync packages
if [ ${ARCH} = amd64 ]; then
	rsync -aEXuh --progress --delete --omit-dir-times /catalyst/tmp/packages/${ARCH}-${PROFILE} /mnt/mirror/local_mirror/Packages/
elif [ ${ARCH} = i686 ]; then
	rsync -aEXuh --progress --delete --omit-dir-times /catalyst/tmp/packages/x86-${PROFILE} /mnt/mirror/local_mirror/Packages/
fi
/mnt/mirror/mirror.sh

#last generate the sig and torrent
for arch in ${ARCH}
do
	gpg --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
	/catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_$(grep RC= build_spec.sh | cut -d'=' -f2).iso.DIGESTS
	volid="Pentoo Linux_${arch}_${PROFILE}_$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_$(grep RC= build_spec.sh | cut -d'=' -f2)"
	mktorrent -a http://tracker.cryptohaze.com/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
done
