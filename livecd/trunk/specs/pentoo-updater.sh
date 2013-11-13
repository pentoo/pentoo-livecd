#!/bin/sh -x

emerge --deep --update --newuse -kb @world || /bin/bash
etc-update --automode -5 || /bin/bash
emerge --depclean || /bin/bash
emerge @preserved-rebuild --buildpkg=y || /bin/bash
smart-live-rebuild || /bin/bash
revdep-rebuild || /bin/bash
etc-update --automode -5 || /bin/bash
eclean-dist -d || /bin/bash
eclean-pkg -d || /bin/bash
python-updater -- --buildpkg=y|| /bin/bash
perl-cleaner --modules -- --buildpkg=y || /bin/bash
