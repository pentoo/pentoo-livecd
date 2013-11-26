#!/bin/sh -x
source /etc/profile
env-update
source /tmp/envscript

emerge --update --newuse portage || /bin/bash
emerge --deep --update --newuse -kb @world || /bin/bash
#add gnome/kde use flags
echo "pentoo/pentoo gnome kde" >> /etc/portage/package.use
emerge --onlydeps --oneshot --deep --update --newuse pentoo/pentoo || /bin/bash
#unstable no binpkgs yet
#emerge --oneshot --deep --update --newuse pentoo/pentoo-cinnamon || /bin/bash
etc-update --automode -5 || /bin/bash
#emerge --depclean || /bin/bash
emerge @preserved-rebuild --buildpkg=y || /bin/bash
smart-live-rebuild || /bin/bash
revdep-rebuild || /bin/bash
etc-update --automode -5 || /bin/bash
#remove gnome/kde use flags
rm /etc/portage/package.use
python-updater -- --buildpkg=y|| /bin/bash
perl-cleaner --modules -- --buildpkg=y || /bin/bash

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
eclean-pkg || /bin/bash
emaint binhost || /bin/bash

emerge --info > /var/log/portage/emerge-info-$(date "+%Y%m%d").txt
