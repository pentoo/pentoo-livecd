#!/bin/sh

set -e

sleepy() {
  printf "IO at max, sleeping...\n"
  sleep 15
}

check_io() {
  #IO load is CRUSHING my build system, so if a heavy IO operation is running, hold off on starting the next one
  #rsync is used to copy from livecd-stage1 to livecd-stage2
  while pgrep  -f "[r]sync .* /catalyst/"
  do
    sleepy
  done
  #this is unpacking a stage
  while pgrep -f "[x]pf /catalyst/"
  do
    sleepy
  done
  #this is packing a stage
  while pgrep -f "[c]pf /catalyst/"
  do
    sleepy
  done
  #removing tempfiles when complete
  while pgrep -f "[r]m -rf /catalyst/tmp/"
  do
    sleepy
  done
  #end excessive IO handling
}

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

if [ "$PROFILE" = "default" ] && [ "$ARCH" = "amd64" ]; then
  printf "You promised to to stop doing this.\n"
  exit 1
fi

#first we prep directories and build all the spec files
for arch in ${ARCH}
do
	for stage in stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo binpkg-update-seed binpkg-update livecd-stage2-full livecd-stage2
	do
		#I have nfc why it's loosing exec all of a sudden but I can compensate
		chmod +x build_spec.sh
		./build_spec.sh ${arch} ${PROFILE} ${stage} > /tmp/${arch}-${PROFILE}-${stage}.spec
	done
done

#then the actual builds
for arch in ${ARCH}
do
	#This is a "full" livecd run
	#for stage in stage1 stage2 stage3 stage4 stage4-pentoo livecd-stage2

	#for stage in stage4-pentoo binpkg-update-seed livecd-stage2
	#for stage in binpkg-update-seed livecd-stage2
	case ${3:-missing} in
	  all)                targets="stage4 stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo binpkg-update-seed livecd-stage2-full livecd-stage2" ;;
	  livecd-all)         targets="stage4 stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo binpkg-update-seed livecd-stage2-full livecd-stage2" ;;
	  livecd-full)        targets="stage4 stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo binpkg-update-seed livecd-stage2-full livecd-stage2" ;;
	  livecd)             targets="stage4 stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  stage1)             targets="stage1 stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  stage2)             targets="stage2 stage3 stage4 stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  stage3)             targets="stage3 stage4 stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  stage4)             targets="stage4 stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  stage4-pentoo)      targets="stage4-pentoo-full stage4-pentoo livecd-stage2-full livecd-stage2" ;;
	  livecd-stage2)      targets="livecd-stage2-full livecd-stage2" ;;
	  livecd-stage2-mini) targets="livecd-stage2" ;;
	  binpkg-update-seed) targets="binpkg-update-seed" ;;
	  none)               targets="" ;;
	  release)            targets="" ;;
	  *) printf "Requested build invalid\n"; exit 1 ;;
	esac
	for stage in ${targets}
	do
    FAILURE="0"
		check_io

		if [ "${stage}" = "livecd-stage2" ]
		then
			rm -rf /catalyst/release/Pentoo_${arch}_${PROFILE}
			mkdir -p /catalyst/release/Pentoo_${arch}_${PROFILE}
			chmod 777 /catalyst/release/Pentoo_${arch}_${PROFILE}
      rm -rf /catalyst/builds/${PROFILE}/livecd-stage2-${subarch}-2019.0/*
    elif [ "${stage}" = "livecd-stage2-full" ]; then
			rm -rf /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
			mkdir -p /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
			chmod 777 /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
      rm -rf /catalyst/builds/${PROFILE}/livecd-stage2-${subarch}-full-2019.0/*
		fi

		check_io

		#catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec --log-level debug || FAILURE="1"
		eatmydata catalyst -f /tmp/${arch}-${PROFILE}-${stage}.spec || FAILURE="1"

    #if [ "${FAILURE}" = "1" ]; then
    #  printf "FUCK: we failed on /tmp/${arch}-${PROFILE}-${stage}.spec\n"
    #  ./catalyst_recover.sh /tmp/${arch}-${PROFILE}-${stage}.spec
    #fi
		check_io

		if [ "${stage}" != "livecd-stage1" -a "${stage}" != "livecd-stage2"  -a "${stage}" != "stage4-pentoo" -a "${stage}" != "binpkg-update-seed" ]
		then
			#rm -rf /catalyst/tmp/${PROFILE}/${stage}-${subarch}-*
      true
		fi
		if [ "${stage}" = "stage4-pentoo" ] || [ "${stage}" = "stage4-pentoo-full" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/stage4-${subarch}-pentoo-*
		fi
		if [ "${stage}" = "binpkg-update-seed" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/stage4-${subarch}-binpkg-update-*
		fi
		if [ "${stage}" = "livecd-stage2" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage1-${subarch}-2*
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage2-${subarch}-2*/*
		fi
		if [ "${stage}" = "livecd-stage4-pentoo-full" ]
		then
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage1-${subarch}-full-2*
			rm -rf /catalyst/tmp/${PROFILE}/livecd-stage2-${subarch}-full-2*/*
		fi

    if [ "${FAILURE}" = "1" ]; then
      printf "FUCK: we failed on /tmp/${arch}-${PROFILE}-${stage}.spec\n"
      exit 1
    fi
    if [ -f "/catalyst/log/tool-list/tools_list_${arch}-${PROFILE}.json" ]; then
      mv "/catalyst/log/tool-list/tools_list_${arch}-${PROFILE}.json" /catalyst/release/Pentoo_${arch}_${PROFILE}/
    elif [ -f "/catalyst/log/tool-list/tools_list_full_${arch}-${PROFILE}.json" ]; then
      mv "/catalyst/log/tool-list/tools_list_full_${arch}-${PROFILE}.json" /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/
    fi

	done
done

#until catalyst -f /tmp/x86-hardened-livecd-stage2.spec; do echo failed; sleep 30; done

#if [ -n "${targets}" ]; then
  #sync packages
  check_io
  rsync -aEXuh --progress --delete --omit-dir-times /catalyst/packages/${ARCH}-${PROFILE} /mnt/mirror/local_mirror/Packages/
  check_io
  /mnt/mirror/mirror.sh
#fi

#last generate the sig and torrent
source ./build_spec.sh > /dev/null
#RC="$(grep ^RC= build_spec.sh |cut -d'=' -f2)"
#RC="${RC:0:7}$(date "+%Y%m%d")"
for arch in ${ARCH}
do
  if [ -n "${RC}" ]; then
    if [ -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS ]; then
      if [ ! -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS.asc ]; then
        su zero -c "GPG_TTY=$(tty) gpg --verbose --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
          /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS"
      fi

      volid="Pentoo_Linux_${arch}_${PROFILE}_${VERSION_STAMP}_${RC}"
      if [ ! -f "/catalyst/release/Pentoo_${arch}_${PROFILE}/${volid}.torrent" ]; then
        mktorrent -a udp://tracker.coppersurfer.tk:6969/announce,udp://tracker.open-internet.nl:6969/announce,udp://tracker.skyts.net:6969/announce,udp://tracker.opentrackr.org:1337/announce,udp://inferno.demonoid.pw:3418/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
        mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
      fi
    fi

    if [ -f /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS ]; then
      if [ ! -f /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS.asc ]; then
        su zero -c "GPG_TTY=$(tty) gpg --verbose --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
          /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}_${RC}.iso.DIGESTS"
      fi

      volid="Pentoo_Linux_Full_${arch}_${PROFILE}_${VERSION_STAMP}_${RC}"
      if [ ! -f "/catalyst/release/Pentoo_Full_${arch}_${PROFILE}/${volid}.torrent" ]; then
        mktorrent -a udp://tracker.coppersurfer.tk:6969/announce,udp://tracker.open-internet.nl:6969/announce,udp://tracker.skyts.net:6969/announce,udp://tracker.opentrackr.org:1337/announce,udp://inferno.demonoid.pw:3418/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
        mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
      fi
    fi
  else
    if [ -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS ]; then
      if [ ! -f /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS.asc ]; then
        su zero -c "GPG_TTY=$(tty) gpg --verbose --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
          /catalyst/release/Pentoo_${arch}_${PROFILE}/pentoo-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS"
      fi

      volid="Pentoo_Linux_${arch}_${PROFILE}_${VERSION_STAMP}"
      if [ ! -f "/catalyst/release/Pentoo_${arch}_${PROFILE}/${volid}.torrent" ]; then
        mktorrent -a udp://tracker.coppersurfer.tk:6969/announce,udp://tracker.open-internet.nl:6969/announce,udp://tracker.skyts.net:6969/announce,udp://tracker.opentrackr.org:1337/announce,udp://inferno.demonoid.pw:3418/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
        mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_${arch}_${PROFILE}
      fi
    fi

    if [ -f /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS ]; then
      if [ ! -f /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS.asc ]; then
        su zero -c "GPG_TTY=$(tty) gpg --verbose --sign --clearsign --yes --digest-algo SHA512 --default-key DD11F94A --homedir /home/zero/.gnupg \
          /catalyst/release/Pentoo_Full_${arch}_${PROFILE}/pentoo-full-${arch}-${PROFILE}-${VERSION_STAMP}.iso.DIGESTS"
      fi

      volid="Pentoo_Linux_Full_${arch}_${PROFILE}_${VERSION_STAMP}"
      if [ ! -f "/catalyst/release/Pentoo_Full_${arch}_${PROFILE}/${volid}.torrent" ]; then
        mktorrent -a udp://tracker.coppersurfer.tk:6969/announce,udp://tracker.open-internet.nl:6969/announce,udp://tracker.skyts.net:6969/announce,udp://tracker.opentrackr.org:1337/announce,udp://inferno.demonoid.pw:3418/announce -n "${volid}" -o /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
        mv /catalyst/release/"${volid}".torrent /catalyst/release/Pentoo_Full_${arch}_${PROFILE}
      fi
    fi
  fi
done
