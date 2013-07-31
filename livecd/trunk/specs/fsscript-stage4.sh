#!/bin/sh -x
source /tmp/envscript
#ease transition to the new use flags
USE="-directfb" emerge -1 -kb libsdl DirectFB || /bin/bash
#finish transition to the new use flags
emerge --deep --update --newuse -kb @world || /bin/bash
#fix interpreted stuff
perl-cleaner --modules -- --buildpkg=y || /bin/bash
python-updater -- --buildpkg=y || /bin/bash
#rebuild everything to ensure packages exist for everything.
emerge -e -kb @world || /bin/bash
emerge -1 --buildpkg=y app-portage/gentoolkit || /bin/bash
revdep-rebuild -- --buildpkg=y || /bin/bash
