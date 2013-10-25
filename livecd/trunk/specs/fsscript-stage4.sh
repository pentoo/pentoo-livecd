#!/bin/sh -x
source /tmp/envscript

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
perl-cleaner --modules -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi
python-updater -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi
eselect ruby set ruby19 || /bin/bash

#rebuild everything to ensure packages exist for everything.
emerge -e -kb @world || /bin/bash
emerge -1 -kb app-portage/gentoolkit || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -- --buildpkg=y || /bin/bash

#some things fail in livecd-stage1 but work here, nfc why
USE=aufs emerge -1 -kb sys-kernel/pentoo-sources || /bin/bash
#emerge -1 -kb app-crypt/johntheripper || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

eclean-pkg
