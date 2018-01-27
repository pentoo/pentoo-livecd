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

#first we prep directories and build all the spec files
for arch in ${ARCH}
do
	rm -rf /catalyst/release/Pentoo_${arch}_${PROFILE} /catalyst/release/Pentoo_Linux_${arch}_${PROFILE}*.torrent
	mkdir -p /catalyst/release/Pentoo_${arch}_${PROFILE}
	chmod 777 /catalyst/release/Pentoo_${arch}_${PROFILE}

	for stage in stage1 stage2 stage3 stage4 stage4-pentoo binpkg-update-seed binpkg-update livecd-stage2
	do
		#I have nfc why it's loosing exec all of a sudden but I can compensate
		chmod +x build_spec.sh
		./build_spec.sh ${arch} ${PROFILE} ${stage} > /tmp/${arch}-${PROFILE}-${stage}.spec
	done
done

#then the actual builds
for arch in ${ARCH}
do
	#for stage in stage4-pentoo binpkg-update-seed livecd-stage2
	#for stage in binpkg-update-seed livecd-stage2
	#for stage in livecd-stage2
	#for stage in stage1 stage2 stage3 stage4 stage4-pentoo binpkg-update-seed livecd-stage2
	for stage in stage4-pentoo binpkg-update-seed livecd-stage2
	do
		#building in tmpfs isn't exactly friendly on my ram usage, so let's limit to one catalyst at a time
		#while ps aux | grep "[c]atalyst -f"
		#do
		#	echo "Catalyst already running, sleeping 2m"
		#	sleep 2m
		#done
		#IO load is CRUSHING my build system, so if a heavy IO operation is running, hold off on starting the next one
		#rsync is used to copy from livecd-stage1 to livecd-stage2
		while ps aux | grep "[r]sync -a --delete /catalyst/"
		do
			echo "IO at max, sleeping 2m"
			sleep 2m
		done
		#this is unpacking a stage
		while ps aux | grep "[x]pf /catalyst/"
		do
			echo "IO at max, sleeping 2m"
			sleep 2m
		done
		#this is packing a stage
		while ps aux | grep "[c]pf /catalyst/"
		do
			echo "IO at max, sleeping 2m"
			sleep 2m
		done
		#removing tempfiles when complete
		while ps aux | grep "[r]m -rf /catalyst/tmp/"
		do
			echo "IO at max, sleeping 2m"
			sleep 2m
		done
		#end excessive IO handling

		catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
		if [ "${stage}" != "livecd-stage1" -a "${stage}" != "livecd-stage2"  -a "${stage}" != "stage4-pentoo" -a "${stage}" != "binpkg-update-seed" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/${stage}-${subarch}-2015.0
		fi
		if [ "${stage}" = "stage4-pentoo" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/stage4-${subarch}-pentoo-2015.0
		fi
		if [ "${stage}" = "binpkg-update-seed" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/stage4-${subarch}-binpkg-update-2015.0
		fi
		if [ "${stage}" = "livecd-stage2" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage1-${subarch}-2015.0
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage2-${subarch}-2015.0
		fi
	#	if [ $? -ne 0 ]; then
	#		catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
	#		if [ $? -ne 0 ]; then
	#			catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
	#			if [ $? -ne 0 ]; then
	#				catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec
	#			fi
	#				if [ $? -ne 0 ]; then
	#					break
	#				fi
	#		fi
	#	fi
	done
done

#until catalyst -f /tmp/x86-hardened-livecd-stage2.spec; do echo failed; sleep 30; done

#sync packages
rsync -aEXuh --progress --delete --omit-dir-times /catalyst/packages/${ARCH}-${PROFILE} /mnt/mirror/local_mirror/Packages/

/mnt/mirror/mirror.sh

#last generate the sig and torrent
#RC="$(grep ^RC= build_spec.sh |cut -d'=' -f2)"
#RC="${RC:0:7}$(date "+%Y%m%d")"
#for arch in ${ARCH}
#do
#	if [ -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}.iso.DIGESTS ]
#	then
#		GPG_TTY=$(tty) gpg --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
#		/catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}.iso.DIGESTS
#
#		volid="Pentoo_Linux_${arch}_${PROFILE}_$(grep VERSION_STAMP= build_spec.sh | cut -d'=' -f2)_${RC}"
#		mktorrent -a http://tracker.cryptohaze.com/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
#		mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
#	fi
#done
