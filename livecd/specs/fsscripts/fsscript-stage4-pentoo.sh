#!/bin/sh
set -x
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

PYTHON3=$(emerge --info | grep -oE '^PYTHON_SINGLE_TARGET\=".*(python3_[0-9]+\s*)+"' | grep -oE 'python3_[0-9]+' | cut -d\" -f2 | sed 's#_#.#')
${PYTHON3} -c "from _multiprocessing import SemLock" || emerge -1 --buildpkg=y python:${PYTHON3#python}

portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || error_handler
fi

if portageq has_version / dev-lang/ruby:3.0; then
  eselect ruby set ruby30
fi
if portageq has_version / dev-lang/ruby:3.1; then
  eselect ruby set ruby31
fi

revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler

"$(portageq get_repo_path / pentoo)/scripts/bug-461824.sh"

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler

#I guess this was removed from base-system?
mkdir -p '/etc/modprobe.d'

true
