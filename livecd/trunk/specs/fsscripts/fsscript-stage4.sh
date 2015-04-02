#!/bin/sh
source /tmp/envscript

fix_locale() {
	grep -q "en_US ISO-8859-1" /etc/locale.nopurge || echo en_US ISO-8859-1 >> /etc/locale.nopurge
	grep -q "en_US.UTF-8 UTF-8" /etc/locale.nopurge || echo en_US.UTF-8 UTF-8 >> /etc/locale.nopurge
	sed -i -e '/en_US ISO-8859-1/s/^# *//' -e '/en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen || /bin/bash
	locale-gen || /bin/bash
}

fix_locale

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

emerge -1 -kb wgetpaste || /bin/bash

#ease transition to the new use flags
USE="-directfb" emerge -1 -kb libsdl DirectFB || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#finish transition to the new use flags
emerge --deep --update --newuse -kb @world || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#fix interpreted stuff
perl-cleaner --all -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#first we set the python interpreters to match PYTHON_TARGETS
eselect python set --python2 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 1 |sed 's#_#.#') || /bin/bash
eselect python set --python3 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#') || /bin/bash
python2.7 -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:2.7
python3.3 -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:3.3
python-updater -- --buildpkg=y || /bin/bash

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#there doesn't actually appear to be a ruby installed at this point except long dead 1.8
#eselect ruby set ruby20 || /bin/bash

emerge --depclean || /bin/bash

emerge -1 -kb app-portage/gentoolkit || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild.py -i --no-pretend -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || /bin/bash

/usr/local/portage/scripts/bug-461824.sh

#some things fail in livecd-stage1 but work here, nfc why
USE="aufs symlink" emerge -1 -kb sys-kernel/pentoo-sources || /bin/bash
#emerge -1 -kb app-crypt/johntheripper || /bin/bash

#fix java circular deps in next stage
emerge --update --oneshot -kb icedtea-bin:7 || /bin/bash
eselect java-vm set system icedtea-bin-7 || /bin/bash
#emerge --update --oneshot -kb icedtea:7 || /bin/bash
#emerge -C icedtea-bin:7 || /bin/bash
#eselect java-vm set system icedtea-7 || /bin/bash

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

eclean-pkg
