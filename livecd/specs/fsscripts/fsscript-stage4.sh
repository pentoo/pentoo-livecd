#!/bin/sh -x
source /tmp/envscript

fix_locale() {
  for i in /etc/locale.nopurge /etc/locale.gen; do
  	echo C.UTF-8 UTF-8 > "${i}"
  	echo en_US ISO-8859-1 >> "${i}"
  	echo en_US.UTF-8 UTF-8 >> "${i}"
  done
	eselect locale set C.utf8 || /bin/bash
  env-update
  . /etc/profile
	locale-gen || /bin/bash
}

fix_locale

#revdep-rebuild --library 'libstdc++.so.6' -- --buildpkg=y --usepkg=n --exclude gcc

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

#ease transition to the new use flags
USE="-qt5" emerge -1 -kb cmake || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#merge in the profile set since we have no @system set
emerge -1kb --newuse --update @profile || /bin/bash
#finish transition to the new use flags
emerge --deep --update --newuse -kb @world || /bin/bash
#do what stage1 update seed is going to do
emerge --quiet --update --newuse --changed-deps --oneshot --deep --changed-use --rebuild-if-new-rev sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2 sys-devel/libtool dev-lang/perl net-misc/openssh dev-libs/openssl sys-libs/readline sys-libs/ncurses || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#fix interpreted stuff
perl-cleaner --all -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON3=$(emerge --info | grep -oE '^PYTHON_SINGLE_TARGET\="(python3*_[0-9]\s*)+"' | cut -d\" -f2 | sed 's#_#.#')
eselect python set --python3 ${PYTHON3} || /bin/bash
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}
#python 3 by default now
eselect python set "${PYTHON3}"
if [ -x /usr/sbin/python-updater ];then
	python-updater -- --buildpkg=y || /bin/bash
fi

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

emerge -1 -kb app-portage/gentoolkit || /bin/bash
#things are broken, I have no clue why or how, but this is the earliest point to fix it
broken_packages=$(qfile -q $(equery -C -N check -o '*' 2>&1 | grep --color=never 'does not exist' | awk '{print $2}' | grep -Ev '\.cache') 2>&1 | grep -v 'qfile' | awk -F: '{print $1}' | sort -u | tr '\n' ' ')
if [ -n "${broken_packages}" ]; then
  emerge -1 --buildpkg=y --usepkg=n ${broken_packages} || /bin/bash
fi

portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -i -- --usepkg=n --buildpkg=y || /bin/bash

for i in /var/gentoo/repos/local /var/db/repos/local /var/db/repos/pentoo; do
  [ -x ${i}/scripts/bug-461824.sh ] && ${i}/scripts/bug-461824.sh
done

#some things fail in livecd-stage1 but work here, nfc why
emerge -1 -kb sys-kernel/pentoo-sources || /bin/bash
#emerge -1 -kb app-crypt/johntheripper || /bin/bash

#fix java circular deps in next stage
emerge --update --oneshot -kb openjdk-bin:11 || /bin/bash
eselect java-vm set system openjdk-bin-11 || /bin/bash
emerge --update --oneshot -kb openjdk:11 || /bin/bash
eselect java-vm set system openjdk-11 || /bin/bash
emerge -C openjdk-bin:11 || /bin/bash

#fix PyQt5->qtmultimedia->pulseaudio->PyQt5 circular deps in the next stage
USE="-pulseaudio" emerge -1kb dev-qt/qtmultimedia

#fix cups/avahi circular deps in next stage
USE=-zeroconf emerge --update --oneshot -kb net-print/cups || /bin/bash

if [ "${clst_subarch}" = "pentium-m" ]; then
	emerge --update --oneshot -kb dev-lang/rust-bin || /bin/bash
fi
portageq list_preserved_libs /
if [ $? = 0 ]; then
  emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#short term insanity, rebuild everything which was built with debug turned on to shrink file sizes
#emerge --oneshot --usepkg=n --buildpkg=y $(grep -ir ggdb /var/db/pkg/*/*/CFLAGS | sed -e 's#/var/db/pkg/#=#' -e 's#/CFLAGS.*##')

#add 64 bit toolchain to 32 bit iso to build dual kernel iso someday
#[ "${clst_subarch}" = "pentium-m" ] && crossdev -s1 -t x86_64

fixpackages
eclean-pkg -t 3m
emerge --depclean --exclude dev-java/openjdk  --exclude sys-kernel/pentoo-sources \
	--exclude dev-lang/rust-bin --exclude app-portage/gentoolkit --exclude net-print/cups  --exclude dev-qt/qtmultimedia || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash
