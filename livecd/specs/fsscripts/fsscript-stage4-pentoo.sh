#!/bin/sh -x
source /tmp/envscript

error_handler() {
  if [ -n "${PS1}" ]; then
    #this is an interactive shell, so ask the user for help
    /bin/bash
  else
    #not interactive, fail hard
    exit 1
  fi
}

emerge -1kb --newuse --update sys-apps/portage || error_handler

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || error_handler
fi

#fix interpreted stuff
perl-cleaner --modules -- --buildpkg=y || error_handler

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || error_handler
fi

#first we set the python interpreters to match PYTHON_TARGETS
PYTHON3=$(emerge --info | grep -oE '^PYTHON_SINGLE_TARGET\=".*(python3_[0-9]+\s*)+"' | grep -oE 'python3_[0-9]+' | cut -d\" -f2 | sed 's#_#.#')
#eselect python set --python3 ${PYTHON3} || error_handler
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}
#python 3 by default now
#eselect python set "${PYTHON3}"
if [ -x /usr/sbin/python-updater ]; then
	python-updater -- --buildpkg=y || error_handler
fi

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || error_handler
fi

eselect ruby set ruby27 || error_handler

#short term insanity, rebuild everything which was built with debug turned on to shrink file sizes
#emerge --usepkg=n --buildpkg=y --oneshot $(grep -ir ggdb /var/db/pkg/*/*/CFLAGS | sed -e 's#/var/db/pkg/#=#' -e 's#/CFLAGS.*##')

revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler

[ -x /var/db/repos/local/scripts/bug-461824.sh ] && /var/db/repos/local/scripts/bug-461824.sh
[ -x /var/db/repos/pentoo/scripts/bug-461824.sh ] && /var/db/repos/pentoo/scripts/bug-461824.sh

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler

fixpackages
eclean-pkg -t 3m
true
