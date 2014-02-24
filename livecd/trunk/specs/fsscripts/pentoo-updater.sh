#!/bin/sh
source /etc/profile
env-update
source /tmp/envscript

emerge --update --newuse --oneshot portage || /bin/bash

#first we set the python interpreters to match PYTHON_TARGETS
eselect python set --python2 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 1 |sed 's#_#.#') || /bin/bash
eselect python set --python3 $(emerge --info | grep ^PYTHON_TARGETS | cut -d\" -f2 | cut -d" " -f 2 |sed 's#_#.#') || /bin/bash
python2.7 -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:2.7
python3.3 -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:3.3
python-updater -- --buildpkg=y --rebuild-exclude sys-devel/gdb --exclude sys-devel/gdb || /bin/bash

perl-cleaner --ph-clean --modules -- --buildpkg=y || /bin/bash

#emerge -C efreet ethumb edje eeze eet eina emotion eio ecore evas embryo
emerge --deep --update --newuse -kb @world || /bin/bash

#add gnome/kde use flags
echo "pentoo/pentoo gnome kde" >> /etc/portage/package.use
emerge --onlydeps --oneshot --deep --update --newuse pentoo/pentoo || /bin/bash
etc-update --automode -5 || /bin/bash
#emerge --depclean || /bin/bash
emerge @preserved-rebuild --buildpkg=y || /bin/bash
smart-live-rebuild 2>&1 || /bin/bash
revdep-rebuild.py -i -- --buildpkg=y || /bin/bash
emerge --deep --update --newuse -kb @world || /bin/bash
etc-update --automode -5 || /bin/bash
#remove gnome/kde use flags
rm /etc/portage/package.use

/usr/local/portage/scripts/bug-461824.sh

eclean-pkg || /bin/bash
emaint binhost || /bin/bash

emerge --info > /var/log/portage/emerge-info-$(date "+%Y%m%d").txt
