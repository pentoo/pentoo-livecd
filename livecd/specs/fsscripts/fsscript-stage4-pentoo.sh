#!/bin/sh -x
source /tmp/envscript

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#fix interpreted stuff
perl-cleaner --modules -- --buildpkg=y || /bin/bash

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON3=$(emerge --info | grep -oE '^PYTHON_SINGLE_TARGET\="(python3*_[0-9]\s*)+"' | cut -d\" -f2 | sed 's#_#.#')
eselect python set --python3 ${PYTHON3} || /bin/bash
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}
#python 3 by default now
eselect python set "${PYTHON3}"
if [ -x /usr/sbin/python-updater ]; then
	python-updater -- --buildpkg=y || /bin/bash
fi

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

eselect ruby set ruby25 || /bin/bash

#short term insanity, rebuild everything which was built with debug turned on to shrink file sizes
#emerge --usepkg=n --buildpkg=y --oneshot $(grep -ir ggdb /var/db/pkg/*/*/CFLAGS | sed -e 's#/var/db/pkg/#=#' -e 's#/CFLAGS.*##')

revdep-rebuild -i -- --usepkg=n --buildpkg=y || /bin/bash

[ -x /var/db/repos/local/scripts/bug-461824.sh ] && /var/db/repos/local/scripts/bug-461824.sh
[ -x /var/db/repos/pentoo/scripts/bug-461824.sh ] && /var/db/repos/pentoo/scripts/bug-461824.sh

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

fixpackages
eclean-pkg -t 3m
