#!/bin/sh
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
eselect python set --python2 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 1 |sed 's#_#.#') || /bin/bash
eselect python set --python3 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#') || /bin/bash
python-updater -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

eselect ruby set ruby20 || /bin/bash

revdep-rebuild.py -i --no-pretend -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || /bin/bash

/usr/local/portage/scripts/bug-461824.sh

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

eclean-pkg
