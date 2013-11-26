#!/bin/sh -x
source /tmp/envscript

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

python-updater -- --buildpkg=y || /bin/bash
portageq list_preserved_libs /
if [ $? -ne 0 ]; then
        emerge @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -- --buildpkg=y || /bin/bash

#work around for detecting and fixing bug #461824
grep -r _portage_reinstall_ /etc {/usr,}/{*bin,lib*} | grep -v doebuild > /tmp/urfuct.txt
if [ -n "$(cat /tmp/urfuct.txt)" ]; then
	for badhit in "$(cat /tmp/urfuct.txt)" ; do
		echo ${badhit} | cut -d":" -f1 >> /tmp/badfiles.txt
	done
	for badfile in $(cat /tmp/badfiles.txt); do
		qfile -C ${badfile} | cut -d' ' -f1 >> /tmp/badpkg_us.txt
	done
	cat /tmp/badpkg_us.txt | sort -u > /tmp/badpkg.txt
	emerge -1 --buildpkg=y --nodeps $(cat /tmp/badpkg.txt) || /bin/bash
	rm -f /tmp/urfuct.txt /tmp/badfiles.txt /tmp/badpkg_us.txt /tmp/badpkg.txt
fi

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

eclean-pkg
