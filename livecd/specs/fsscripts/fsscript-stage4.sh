#!/bin/sh
set -x
source /tmp/envscript

EC() { echo -e '\e[1;33m'code $?'\e[m\n'; }
trap EC ERR

fix_locale() {
  for i in /etc/locale.nopurge /etc/locale.gen; do
    echo C.UTF-8 UTF-8 > "${i}"
    echo en_US ISO-8859-1 >> "${i}"
    echo en_US.UTF-8 UTF-8 >> "${i}"
  done
  eselect locale set C.utf8 || error_handler
  env-update
  . /etc/profile
  locale-gen || error_handler
}

error_handler() {
  if [ -n "${PS1}" ]; then
    #this is an interactive shell, so ask the user for help
    /bin/bash
  else
    #not interactive, fail hard
    exit 1
  fi
}

fix_locale

#revdep-rebuild --library 'libstdc++.so.6' -- --buildpkg=y --usepkg=n --exclude gcc

emerge -1kbq --newuse --update sys-apps/portage || error_handler

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler

# cmake dep loop unless lz4 exists first
USE=-lz4 emerge -1kbq app-arch/libarchive || error_handler
emerge -1kbq app-arch/lz4 || error_handler
#ease transition to the new use flags
USE="-qt5" emerge -1kbq cmake || error_handler
if portageq list_preserved_libs /; then
  #we do this twice for a reason, let this one fail sometimes
  emerge --buildpkg=y @preserved-rebuild -q || true
fi

emerge --newuse -1kbq --rebuild-if-new-rev sys-libs/glibc
#perl update sucks
emerge --update -1kbq perl --nodeps
emerge -1kbq app-portage/gentoolkit
emerge --update --changed-deps -1kbq $(equery d '<dev-lang/perl-5.40' | awk '/^\w/ {print "="$1}')
removebigint=$(portageq match / '<perl-core/Math-BigInt-2.3.2')
if [ -n "${removebigint:-}" ]; then
  emerge -C '<perl-core/Math-BigInt-2.3.2'
fi
perl-cleaner --modules -- --buildpkg=y
emerge -1kbq --newuse --update --changed-deps --onlydeps --onlydeps-with-rdeps media-gfx/graphite2
emerge -1kbq --newuse --update --changed-deps media-gfx/graphite2
#bust some circular deps
USE="-harfbuzz" emerge -1kbq --newuse --update --changed-deps media-libs/freetype
USE="-icu" emerge -1kbq --newuse --update --changed-deps dev-db/sqlite
USE="-tk" emerge -1kbq --newuse --update --changed-deps dev-lang/python
USE="-opengl -cups -X" emerge -1kbq --newuse --update --changed-deps media-libs/libva
USE="-cups -lm-sensors -bluetooth -vaapi" emerge -1kbq --newuse --update --changed-deps x11-libs/gtk+
USE="-cups" emerge -1kbq --newuse --update --changed-deps net-fs/samba
USE="-zeroconf" emerge -1kbq --update --changed-deps net-print/cups || error_handler
emerge -1kbq --newuse --update --changed-deps sys-apps/util-linux
emerge -1kbq --newuse --update --changed-deps dev-libs/glib
emerge -1kbq --newuse --update --changed-deps net-print/cups
emerge -1kbq --newuse --update --changed-deps dev-lang/python
#revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler
#emerge -1kbq --newuse --update --changed-deps x11-libs/gtk+
USE="minimal" emerge -1kbq --newuse --update --changed-deps media-libs/libsndfile
USE="-verify-sig" emerge -1kbq --newuse --update --changed-deps dev-libs/libsodium
emerge -1kbq --newuse --update --with-bdeps=y --changed-deps @system || true
emerge -1kbq --newuse --update --with-bdeps=y --changed-deps @profile || true
#finish transition to the new use flags
emerge --deep --update --newuse -kb --with-bdeps=y --changed-deps @world || error_handler
old_gcc="$(portageq match / '<sys-devel/gcc-12.3')"
if [ -n "${old_gcc}" ]; then
  emerge -C "<sys-devel/gcc-12.3"
fi
gcc-config latest
. /etc/profile
#this has to be done early or x86 fails on the stage1 update seed
if [ "${clst_subarch}" = "pentium-m" ]; then
	emerge --update --oneshot -kb dev-lang/rust-bin || error_handler
fi

#do what stage1 update seed is going to do
emerge --verbose --update --newuse --changed-deps --with-bdeps=y --oneshot --deep --changed-use --rebuild-if-new-rev sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2 dev-build/libtool dev-lang/perl net-misc/openssh dev-libs/openssl sys-libs/readline sys-libs/ncurses || error_handler
if portageq list_preserved_libs /; then
  if ! emerge --buildpkg=y @preserved-rebuild -q ; then
    emerge -C @preserved-rebuild || error handler
    emerge --deep --update --newuse -kb --changed-deps --with-bdeps=y @world || error_handler
  fi
fi

#fix interpreted stuff
perl-cleaner --all -- --buildpkg=y || error_handler
if portageq list_preserved_libs /; then
  emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON3=$(portageq envvar PYTHON_SINGLE_TARGET | sed 's#_#.#')
#eselect python set --python3 ${PYTHON3} || error_handler
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1q --buildpkg=y python:${PYTHON3#python}
#python 3 by default now
#eselect python set "${PYTHON3}"
if [ -x /usr/sbin/python-updater ];then
	python-updater -- --buildpkg=y || error_handler
fi

if portageq list_preserved_libs /; then
  emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

emerge -1kbq app-portage/gentoolkit || error_handler
#things are broken, I have no clue why or how, but this is the earliest point to fix it
broken_packages=$(qfile -q $(equery -C -N check -o '*' 2>&1 | grep --color=never 'does not exist' | awk '{print $2}' | grep -Ev '\.cache') 2>&1 | grep -v 'qfile' | awk -F: '{print $1}' | sort -u | tr '\n' ' ')
if [ -n "${broken_packages}" ]; then
  emerge -1q --buildpkg=y --usepkg=n ${broken_packages} || error_handler
fi

if portageq list_preserved_libs /; then
  emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler

for i in /var/gentoo/repos/local /var/db/repos/local /var/db/repos/pentoo; do
  [ -x ${i}/scripts/bug-461824.sh ] && ${i}/scripts/bug-461824.sh
done

#remove all pentoo-sources then add just the newest
kernelsources=$(portageq match / 'sys-kernel/pentoo-sources')
if [ -n "${kernelsources:-}" ]; then
  emerge -C 'sys-kernel/pentoo-sources'
fi
#some things fail in livecd-stage1 but work here, nfc why
emerge -1kbq sys-kernel/pentoo-sources || error_handler
#emerge -1kbq app-crypt/johntheripper || error_handler

if [ "${clst_subarch}" != "pentium-m" ]; then
  #fix java circular deps in next stage
  emerge --update --oneshot -kb openjdk-bin:11 || error_handler
  eselect java-vm set system openjdk-bin-11 || error_handler
  emerge --update --oneshot -kb openjdk:11 || error_handler
  eselect java-vm set system openjdk-11 || error_handler
  emerge -C openjdk-bin:11 || error_handler
fi

#fix PyQt5->qtmultimedia->pulseaudio->PyQt5 circular deps in the next stage
USE="-pulseaudio" emerge -1kbq dev-qt/qtmultimedia

if portageq list_preserved_libs /; then
  emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

#short term insanity, rebuild everything which was built with debug turned on to shrink file sizes
#emerge --oneshot -q --usepkg=n --buildpkg=y $(grep -ir ggdb /var/db/pkg/*/*/CFLAGS | sed -e 's#/var/db/pkg/#=#' -e 's#/CFLAGS.*##')

#add 64 bit toolchain to 32 bit iso to build dual kernel iso someday
#[ "${clst_subarch}" = "pentium-m" ] && crossdev -s1 -t x86_64

#emerge --depclean \
#  --exclude app-portage/gentoolkit \
#  --exclude dev-db/sqlite \
#  --exclude dev-java/openjdk \
#	--exclude dev-lang/rust-bin \
#  --exclude dev-libs/libsodium \
#  --exclude dev-qt/qtmultimedia \
#  --exclude media-libs/freetype \
#  --exclude media-libs/harfbuzz \
#  --exclude media-libs/libsndfile \
#  --exclude media-libs/libva \
#  --exclude media-video/ffmpeg \
#  --exclude net-fs/samba \
#  --exclude net-print/cups \
#  --exclude llvm-core/clang \
#  --exclude llvm-core/llvm \
#  --exclude sys-kernel/pentoo-sources \
#  --exclude x11-libs/gtk+ \
#  || error_handler

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler
rm -rf /tmp/*
true
