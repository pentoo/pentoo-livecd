#!/bin/sh -x
source /etc/profile
env-update
source /tmp/envscript
arch=$(uname -m)

fix_locale() {
	grep -q "en_US ISO-8859-1" /etc/locale.nopurge || echo en_US ISO-8859-1 >> /etc/locale.nopurge
	grep -q "en_US.UTF-8 UTF-8" /etc/locale.nopurge || echo en_US.UTF-8 UTF-8 >> /etc/locale.nopurge
	sed -i -e '/en_US ISO-8859-1/s/^# *//' -e '/en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen || /bin/bash
	#localepurge || /bin/bash
	locale-gen || /bin/bash
	eselect locale set en_US.utf8 || /bin/bash
}

#just in case, this seems to keep getting messed up
chown -R portage.portage /usr/portage
chown -R /var/gentoo/repos/local/

emerge -1kb --newuse --update sys-apps/portage || /bin/bash

#somehow the default .bashrc runs X.... WTF????
mv /root/.bashrc /root/.bashrc.bak

#user gets wierd groups, fix it for us
#defaults users,wheel,audio,plugdev,games,cdrom,disk,floppy,usb
gpasswd -d pentoo games #remove from games group
usermod -a -G video,cdrw,android,kismet,wireshark,portage pentoo

#things are a little wonky with the move from /etc/ to /etc/portage of some key files so let's fix things a bit
rm -rf /etc/make.conf /etc/make.profile || /bin/bash

#check lib link and fix
if [ ! -L /lib ]
then
	if [ -d /lib64 ]
	then
		echo "BLOODY MURDER"
		mv -f /lib/* /lib64/
		rm -rf /lib
		ln -s /lib64 lib
	fi
fi

# Purge the uneeded locale, should keeps only en and utf8
fix_locale

# Set the timezone
if [[ -e /etc/conf.d/clock ]]
then
	sed -i -e 's/#TIMEZONE="Factory"/TIMEZONE="UTC"/' /etc/conf.d/clock || /bin/bash
fi

# Parallel_startup and net hotplug
if [[ -e /etc/rc.conf ]]
then
	sed -i -e '/#rc_parallel/ s/NO/NO/' -e '/#rc_parallel/ s/#//' /etc/rc.conf || /bin/bash
	sed -i -e '/#rc_hotplug/ s/\*/!net.\*/' -e '/#rc_hotplug/ s/#//' /etc/rc.conf || /bin/bash
fi

# Fixes libvirtd
if [[ -e /etc/libvirtd/libvirtd.conf ]]
then
	sed -i -e '/#listen_addr/ s/192.168.0.1/127.0.0.1/' -e '/#listen_addr/ s/#//' /etc/libvirtd/libvirtd.conf || /bin/bash
fi

# Fix provide rc-script annoyance
pushd /etc/init.d/
ln -s net.lo net.wlan0
ln -s net.lo net.eth0
sed -e '/provide net/D' -i dhcpcd || /bin/bash
popd
if [ -d "/lib64" ]; then
	if [ ! -d "/lib64/rc/init.d" ]; then
		mkdir -p /lib64/rc/init.d
	fi
else
	if [ ! -d "/lib/rc/init.d" ]; then
		mkdir -p /lib/rc/init.d
	fi
fi
rc-update -u || /bin/bash

#default net to null
echo modules=\"\!wireless\" >> /etc/conf.d/net
echo config_wlan0=\"null\" >> /etc/conf.d/net
echo config_eth0=\"null\" >> /etc/conf.d/net

# Fixes functions.sh location since baselayout-2
ln -s /lib/rc/sh/functions.sh /sbin/functions.sh || /bin/bash

# Fix the root login by emptying the root password. No ssh will be allowed until 'passwd root'
sed -i -e 's/^root:\*:/root::/' /etc/shadow || /bin/bash

# Remove useless opengl setup <--remove or fix this right
rm -rf /etc/init.d/x-setup
eselect opengl set xorg-x11 --dst-prefix=/etc/opengl/ || /bin/bash
rm -rf /usr/lib/libGLcore.so
[ -e /usr/lib64 ] && ln -s /etc/opengl/lib64 /etc/opengl/lib
[ -e /usr/lib32 ] && rm -f /usr/lib32/libGLcore.so
eselect opengl set xorg-x11 || /bin/bash

# Set default java vm
if eselect java-vm list | grep icedtea-8; then
  eselect java-vm set system icedtea-8 || /bin/bash
fi

#mark all news read
eselect news read --quiet all || /bin/bash
#eselect news purge || /bin/bash

# Add pentoo repo but use only the version we are packaging in the iso
# this avoids corrupting timestamps in /var/cache/edb/mtimedb
layman -L || /bin/bash
#layman -s pentoo || ( layman -a pentoo || /bin/bash )
layman -a pentoo || /bin/bash
rsync -aEXu --delete /var/gentoo/repos/local/ /var/lib/layman/pentoo/ || /bin/bash
chown -R portage.portage /var/lib/layman/pentoo

#WARNING WARNING WARING
#DO NOT edit the line "bindist livecd" without also adjusting pentoo-installer
#We need to amend pentoo-installer to optionally toggle on and off these use flags, some of may be non-desirable for an installed system
cat <<-EOF > /etc/portage/make.conf
	#This is the default Pentoo make.conf file, it controls many basic system settings.
	#You can find information on how to edit this file in "man make.conf" as well as
	#on the web at https://wiki.gentoo.org/wiki//etc/portage/make.conf

	#Please adjust your CFLAGS as desired, information can be found here: https://wiki.gentoo.org/wiki/CFLAGS
	#Do not modify these FLAGS unless you know what you are doing, always check the defaults first with "portageq envvar CFLAGS"
	#This is the default for pentoo at the time of build:
	#CFLAGS="$(portageq envvar CFLAGS | sed 's#-ggdb##')"
	#A safe choice would be to keep whatever Pentoo defaults are, but optimize for your specific machine:
	#CFLAGS="\${CFLAGS} -march=native"
	#If you do change your CFLAGS, it is best for all the compile flags to match so uncomment the following three lines:
	#CXXFLAGS="\${CFLAGS}"
	#FCFLAGS="\${CFLAGS}"
	#FFLAGS="\${CFLAGS}"

EOF

if [ $arch = "i686" ]; then
	cat <<-EOF >> /etc/portage/make.conf
		#Please adjust your use flags, if you don't use gpu cracking, it is probably safe to remove opencl
		USE="opencl"
EOF
elif [ $arch = "x86_64" ]; then
	cat <<-EOF >> /etc/portage/make.conf
		#Please adjust your use flags, if you don't use gpu cracking, it is probably safe to remove opencl
		USE="opencl"
EOF
fi
cat <<-EOF >> /etc/portage/make.conf
	USE="\${USE} bindist livecd"

	#MAKEOPTS is set automatically by the profile to jobs equal to processors, you do not need to set it.

	#Please set your input devices, if you are only using evdev you may completely remove this line
	INPUT_DEVICES="${INPUT_DEVICES} synaptics"

	#Default VIDEO_CARDS setting enables nearly everything, you can enable fewer here if you like:
	#At a minimum you should have these PLUS your specific videocard
	#VIDEO_CARDS="vga fbdev"
	#you can check available options with "emerge -vp xorg-drivers"
EOF

#deleting this earlier causes the above calls to portageq to break
rm -rf /usr/local/portage || /bin/bash

#foo=$(readlink /etc/portage/make.profile); foo="${PORTDIR}/profiles/${foo#*profiles/}; ln -snf "${foo}" /etc/portage/make.profile

if gcc -v 2>&1 | grep -q Hardened
then
	hardening=hardened
else
        hardening=default
fi

if [ $arch = "i686" ]; then
	ARCH="x86"
	eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH} || /bin/bash
	portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH}/bleeding_edge
elif [ $arch = "x86_64" ]; then
	ARCH="amd64"
	eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH} || /bin/bash
	portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH}/bleeding_edge
else
	echo "failed to handle arch"
	exit
fi

#XXX fix this for the new location of the union
sed -i -e 's:ccache:ccache /mnt/livecd /.unions:' /etc/updatedb.conf || /bin/bash

# Build the metadata cache
rm -rf /var/cache/edb/dep || /bin/bash
emerge --regen || /bin/bash
HOME=/tmp eix-update || /bin/bash

portageq has_version / pentoo/tribe && echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
portageq has_version / pentoo/tribe && echo 'USE="${USE} -bluetooth -database -exploit -footprint -forensics -forging -fuzzers -mitm -mobile -proxies -qemu -radio -rce -scanner -voip -wireless -wireless-compat"' >> /etc/portage/make.conf

emerge -1 pentoo-installer || /bin/bash

# Fix the kernel config
for krnl in `ls /usr/src/ | grep -e "linux-" | sed -e 's/linux-//'`; do
	if [ -d /tmp/kernel_maps ] ; then
		rm -rf /tmp/kernel_maps
	fi
	mkdir /tmp/kernel_maps
	#cp -a /usr/src/linux/?odule* /tmp/kernel_maps/
	#cp -a /usr/src/linux/System.map /tmp/kernel_maps/
	pushd /usr/src/linux
	#mrproper wipes the random seed and means we cannot build modules, be careful here
	make -j clean
	#cp -a /var/tmp/pentoo.config /usr/src/linux/.config
	#cp -a /tmp/kernel_maps/* /usr/src/linux
	#make -j prepare
	#make -j modules_prepare
  popd
done

emerge --deselect=y livecd-tools || /bin/bash
emerge --deselect=y sys-fs/zfs || /bin/bash
emerge --deselect=y sys-kernel/pentoo-sources || /bin/bash

/var/lib/layman/pentoo/scripts/bug-461824.sh

#emerge -qN -kb -D --with-bdeps=y @world -vt --backtrack=99
#layman -S
emerge -qN -kb -D --with-bdeps=y @world -vt --backtrack=99 || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
	emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

#dropping usepkg on x11-modules-rebuild, doesn't make sense to use
emerge -qN -D --usepkg=n --buildpkg=y @x11-module-rebuild || /bin/bash
portageq list_preserved_libs /
if [ $? = 0 ]; then
        emerge --buildpkg=y @preserved-rebuild -q || echo "preserved-rebuild failed"
fi

revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y
if [ $? -ne 0 ]; then
	revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || /bin/bash
fi


eselect python set python2.7 || /bin/bash
if [ -x /usr/sbin/python-updater ]; then
	python-updater -- --buildpkg=y || /bin/bash
fi
perl-cleaner --all -- --buildpkg=y || /bin/bash

/var/lib/layman/pentoo/scripts/bug-461824.sh

# This makes sure we have the latest and greatest genmenu!
emerge -1 app-admin/genmenu || /bin/bash

# Runs the menu generator with a specific parameters for a WM
genmenu.py -e || /bin/bash
genmenu.py -x || /bin/bash
su pentoo -c "genmenu.py -e" || /bin/bash
su pentoo -c "genmenu.py -x" || /bin/bash

# Fixes menu (may no longer be needed)
if [ -f /etc/xdg/menus/gnome-applications.menu ]; then
	cp -af /etc/xdg/menus/gnome-applications.menu /etc/xdg/menus/applications.menu || /bin/bash
fi

#if [ $(command -v paxctl-ng 2> /dev/null) ]; then
#	# fixes pax for metasploit/java attacks/wpscan
#	for i in $(ls /usr/bin/ruby2[1-9]); do
#		paxctl-ng -m ${i} || /bin/bash
#	done
#fi

# Setup fonts
pushd /usr/share/fonts
mkfontdir * || /bin/bash
popd
eselect fontconfig enable 10-sub-pixel-rgb.conf || /bin/bash
eselect fontconfig enable 57-dejavu-sans-mono.conf || /bin/bash
eselect fontconfig enable 57-dejavu-sans.conf || /bin/bash
eselect fontconfig enable 57-dejavu-serif.conf || /bin/bash

# Setup kismet
if [ -e /etc/kismet.conf ]; then
  sed -i -e '/^source=.*/d' /etc/kismet.conf
  sed -i -e 's#.kismet#kismet#' /etc/kismet.conf
  useradd -g pentoo kismet
fi

# Setup tor-privoxy
echo 'forward-socks4a / 127.0.0.1:9050' >> /etc/privoxy/config
mv -f /etc/tor/torrc.sample /etc/tor/torrc || /bin/bash
mkdir /var/log/tor || /bin/bash
chown tor:tor /var/lib/tor || /bin/bash
chown tor:tor /var/log/tor || /bin/bash

#allow this to fail for right now so builds don't randomly stop and piss me off
smart-live-rebuild -E --timeout=60 -- --buildpkg=y

#configure postgres
echo y | emerge --config dev-db/postgresql || /bin/bash
sleep 1m
touch /run/openrc/softlevel
/etc/init.d/postgresql-$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}') start
if [ $? -ne 0 ]; then
  sleep 5m
  /etc/init.d/postgresql-$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}') start
  if [ $? -ne 0 ]; then
    sleep 5m
    killall postgres
    /etc/init.d/postgresql-$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}') start || /bin/bash
  fi
fi

emerge --config net-analyzer/metasploit || /bash/bash

#metasploit first run to create db, etc, and speed up livecd first run
if [ -x "/usr/bin/msfconsole" ]; then
	HOME=/root msfconsole -x exit || /bin/bash
fi

/etc/init.d/postgresql-$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}') stop || /bin/bash
rm -rf /run/openrc/softlevel || /bin/bash

if [ -f /etc/skel/Desktop/pentoo-installer.desktop ] && [ ! -f /home/pentoo/Desktop/pentoo-installer.desktop ]; then
	su pentoo -c 'mkdir -p /home/pentoo/desktop'
	cp /home/pentoo/Desktop/pentoo-installer.deskop
	chown pentoo.users /home/pentoo/Desktop/pentoo-installer.deskop
fi

#basic xfce4 setup
#mkdir -p /root/.config/xfce4/
#cp -r /etc/xdg/xfce4/panel/ /root/.config/xfce4/ || /bin/bash
#magic to autohide panel 2
#magic_number=$(($(sed -n '/<value type="int" value="14"\/>/=' /root/.config/xfce4/panel/default.xml)+1))
#sed -i "${magic_number} a\    <property name=\"autohide-behavior\" type=\"uint\" value=\"1\"/>" /root/.config/xfce4/panel/default.xml
#easy way to adjust wallpaper per install
#mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || /bin/bash
#cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || /bin/bash

su pentoo -c "mkdir -p /home/pentoo/.config/xfce4/" || /bin/bash
su pentoo -c "cp -r /etc/xdg/xfce4/panel/ /home/pentoo/.config/xfce4/" || /bin/bash
magic_number=$(($(sed -n '/<value type="int" value="14"\/>/=' /home/pentoo/.config/xfce4/panel/default.xml)+1))
sed -i "${magic_number} a\    <property name=\"autohide-behavior\" type=\"uint\" value=\"1\"/>" /home/pentoo/.config/xfce4/panel/default.xml
#slim dm is much nicer than default xdm
sed -i 's/"xdm"/"slim"/' /etc/conf.d/xdm

#force password setting for pentoo user
#todo take the livecd .bashrc and insert this before startx with tty check
echo "/usr/sbin/livecd-setpass" >> /home/pentoo/.bashrc

#forcibly untrounce our blacklist, caused by udev remerging
rm -f /etc/modprobe.d/._cfg0000_blacklist.conf

emerge --depclean --with-bdeps=y

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

#etc-update looks like it sometimes crushes our locale settings
fix_locale

#set the hostname properly
sed -i 's/livecd/pentoo/' /etc/conf.d/hostname || /bin/bash
#set the hostname in /etc/hosts too (bug #236)
sed -i '/^#/!s/localhost/localhost pentoo/' /etc/hosts || /bin/bash

#make nano pretty, turn on all syntax hilighting
sed -i '/include/s/# //' /etc/nanorc

eselect ruby set ruby23 || /bin/bash

#mossmann said do this or I'm lame
eselect lapack set 1

portageq list_preserved_libs /
if [ $? = 0 ]; then
	emerge --buildpkg=y @preserved-rebuild -q || /bin/bash
fi

revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y
if [ $? -ne 0 ]; then
	revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || /bin/bash
fi
rc-update -u || /bin/bash

update-ca-certificates

#cleanup temp stuff in /etc/portage from catalyst build
rm -f /etc/portage/make.conf.old
rm -f /etc/portage/make.conf.catalyst
rm -f /etc/portage/depcheck
rm -rf /etc/portage/profile

#cleanup binary drivers
rm -f /lib/modules/*/video/*

## XXX: THIS IS A HORRIBLE IDEA!!!!
# So here is what is happening, we are building the iso with -ggdb and splitdebug so we can figure out wtf is wrong when things are wrong
# The issue is it isn't really possible (nor desirable) to have all this extra debug info on the iso so here is what we do...
#We make a dir with full path for where the debug info goes abusing the fancy /var/tmp/portage tmpfs mount
mkdir -p /var/tmp/portage/debug/rootfs/usr/lib/debug/ || /bin/bash

#then we rsync all the debug info into a rootfs for building a module
rsync -aEXu /usr/lib/debug/ /var/tmp/portage/debug/rootfs/usr/lib/debug/ || /bin/bash

# last we build the module and stash it in PORT_LOGDIR as it is definately on the host system but not the chroot
mkdir -p /var/log/portage/debug/
mksquashfs /var/tmp/portage/debug/rootfs/ /var/log/portage/debug/debug-info-${ARCH}-${hardening}-`date "+%Y%m%d"`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || /bin/bash

# and we add /usr/lib/debug to cleanables in livecd-stage2.spec
rm -rf /var/tmp/portage/debug

## More with the horrible hack
# So it seems I have picked /var/log/portage to just randomly spew stuff into
pushd /root/gentoollist
mkdir -p /var/log/portage/tool-list
clst_rel_type=hardened
rel_version="$(printenv | grep clst_livecd_volid | awk '{print $3,$4,$5}')"
sh gen_installedlist.sh "${clst_rel_type} ${rel_version}" > /var/log/portage/tool-list/tools_list_${arch}-${hardening}_`date "+%Y%m%d"`.html
if [ $? -ne 0 ]; then
	/bin/bash
fi
popd
rm -rf /root/gentoollist

rm -rf /var/tmp/portage/*
eclean-pkg
fixpackages

#bug #477498
ln -snf /proc/self/mounts /etc/mtab

#reset profile to binary profile so users get it as default
arch=$(uname -m)
if [ $arch = "i686" ]; then
	ARCH="x86"
elif [ $arch = "x86_64" ]; then
	ARCH="amd64"
else
	echo "failed to handle arch"
	/bin/bash
fi
eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH}/binary || /bin/bash
portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/${hardening}/linux/${ARCH}/bleeding_edge

sync
sleep 60

rsync -aEXu --delete /var/cache/edb /tmp/
rm -rf /var/cache/*
rsync -aEXu --delete /tmp/edb /var/cache/
emerge --usepkg=n --buildpkg=y -1 portage || /bin/bash

#todo when we no longer need this stub for testing, replace with default
mv /root/.bashrc.bak /root/.bashrc
if [ -r /etc/issue.pentoo.logo ]; then
  rm -f /etc/issue
  cp -f /etc/issue.pentoo.logo /etc/issue
fi

updatedb
sync
sleep 60
rm -f /root/.bash_history
