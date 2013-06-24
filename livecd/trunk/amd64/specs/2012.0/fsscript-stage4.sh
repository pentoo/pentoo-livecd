#!/bin/sh
source /tmp/envscript
USE="-directfb" emerge -1 -kb libsdl DirectFB || /bin/bash
emerge --deep --update --newuse -kb @world || /bin/bash
perl-cleaner --modules -- --buildpkg=y || /bin/bash
python-updater -- --buildpkg=y || /bin/bash
