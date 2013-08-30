#!/bin/sh -x
source /etc/profile
env-update
source /tmp/envscript

#somehow the default .bashrc runs X.... WTF????
rm -f /root/.bashrc

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
#sed '/^es/d' /etc/locale.nopurge #pretty sure this isn't needed
echo en_US ISO-8859-1 >> /etc/locale.nopurge
echo en_US.UTF-8 UTF-8 >> /etc/locale.nopurge
sed -i -e '/en_US ISO-8859-1/s/^# *//' -e '/en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen || /bin/bash
localepurge || /bin/bash
locale-gen || /bin/bash

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
cd /etc/init.d/
ln -s net.lo net.wlan0
ln -s net.lo net.eth0
rc-update -u || /bin/bash
sed -e '/provide net/D' -i dhcpcd || /bin/bash

#default net to null
echo modules=\"\!wireless\" >> /etc/conf.d/net
echo config_eth0=\"null\" >> /etc/conf.d/net
echo config_wlan0=\"null\" >> /etc/conf.d/net

# trigger load of modules we want to load no matter what
# all entries must have a confirmed reason why it is
# a module and not built in yet must still be loaded
#microcode - module load triggers cpu microcode update, builtin doesn't
echo 'modules="microcode"' >> /etc/conf.d/modules

# Bunzip all docs since they'll be in sqlzma format
#cd /usr/share/doc
#for maindir in `find ./ -maxdepth 1 -type d | sed -e 's:^./::'`
#do
#        cd "${maindir}"
#        for file in `ls *.bz2`
#        do
#                bunzip2 "${file}"
#        done
#        cd ..
#done

# Over 1Mb doc is too much for now, we save some space <-- not sure I care anymore
#cd /usr/share/doc
#du -sh * | grep M | sed -e 's/.*\t//' | xargs rm -rf

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
eselect java-vm set system icedtea-bin-7 || /bin/bash
if [ -e /usr/lib64 ] ; then
	eselect java-nsplugin set 64bit icedtea-bin-7 || /bin/bash
else
	eselect java-nsplugin set icedtea-bin-7 || /bin/bash
fi

#mark all news read
eselect news read --quiet all || /bin/bash
#eselect news purge || /bin/bash

# Add pentoo repo
rm -rf /usr/local/portage/* || /bin/bash
layman -L || /bin/bash
layman -s pentoo || ( layman -a pentoo || /bin/bash )
echo "source /var/lib/layman/make.conf" >> /etc/portage/make.conf || /bin/bash

arch=$(uname -m)
if [ $arch = "i686" ]; then
	ARCH="x86"
	#no matter what I do, the x86 build just fails miserably when hardened, and can't even build on default
	#sigh
	eselect profile set pentoo:pentoo/hardened/linux/${ARCH} || /bin/bash
	portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/hardened/linux/${ARCH}/bleeding_edge
elif [ $arch = "x86_64" ]; then
	ARCH="amd64"
	eselect profile set pentoo:pentoo/hardened/linux/${ARCH} || /bin/bash
	portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/hardened/linux/${ARCH}/bleeding_edge
else
	echo "failed to handle arch"
	exit
fi

# Build the metadata cache
sed -i -e 's:ccache:ccache /mnt/livecd /.unions:' /etc/updatedb.conf || /bin/bash
emerge --metadata || /bin/bash
eix-update || /bin/bash

# Fix /etc/portage/make.conf
sed -i 's#USE="mmx sse sse2"##' /etc/portage/make.conf || /bin/bash

#WARNING WARNING WARING
#DO NOT edit the line "aufs bindist livecd" without also adjusting pentoo-installer
#We need to amend pentoo-installer to optionally toggle on and off these use flags, some of may be non-desirable for an installed system
cat <<-EOF > /etc/portage/make.conf
	#Please adjust your use flags, if you don't use gpu cracking remove cuda and opencl
	USE="binary-drivers cuda opencl qemu -doc -examples -gtk-autostart"
	USE="${USE} aufs bindist livecd"
	#MAKEOPTS is set automatically by the profile to jobs equal to processors
	#Please set your input devices, if you are only using evdev you may completely remove this line
	INPUT_DEVICES="${INPUT_DEVICES} synaptics"
	#Default VIDEO_CARDS setting enables nearly everything, you can enable fewer here if you like:
	#At a minimum you should have these PLUS your specific videocard
	#VIDEO_CARDS="vesa vga fbdev"
	#you can check available options with "emerge -vp xorg-drivers"
	ACCEPT_LICENSE="AdobeFlash-11.x Intel-SDP"
	source /var/lib/layman/make.conf
EOF
portageq has_version / pentoo/tribe && echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
portageq has_version / pentoo/tribe && echo 'USE="${USE} -bluetooth -database -exploit -footprint -forensics -forging -fuzzers -mitm -mobile -proxies -qemu -radio -rce -scanner -voip -wireless -wireless-compat"' >> /etc/portage/make.conf

emerge -1 pentoo-installer || /bin/bash

# Fix the kernel dir & config
for krnl in `ls /usr/src/ | grep -e "linux-" | sed -e 's/linux-//'`; do
	rm -rf /usr/src/linux
	ln -s linux-$krnl /usr/src/linux
	cp /var/tmp/pentoo.config /usr/src/linux/.config
	rm -rf /lib/modules/$krnl/source /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/source
	cd /usr/src/linux
	make -j prepare
	make -j modules_prepare
	cp -a /tmp/kerncache/pentoo/usr/src/linux/?odule* ./
	cp -a /tmp/kerncache/pentoo/usr/src/linux/System.map ./
done

emerge --deselect=y livecd-tools || /bin/bash
emerge --deselect=y sys-fs/zfs || /bin/bash

emerge -qN -kb -D --with-bdeps=y @world -vt
layman -S
emerge -qN -kb -D --with-bdeps=y @world -vt || /bin/bash
#dropping usepkg on x11-modules-rebuild, doesn't make sense to use
emerge -qN -D --buildpkg=y @x11-module-rebuild || /bin/bash
emerge --depclean || /bin/bash
revdep-rebuild -- --buildpkg=y
if [ $? -ne 0 ]; then
	rm -rf /var/cache/revdep-rebuild/*.rr
	revdep-rebuild -- --buildpkg=y || rm -rf /var/cache/revdep-rebuild/*.rr
fi


eselect python set python2.7 || /bin/bash
python-updater -- --buildpkg=y|| /bin/bash
perl-cleaner --modules -- --buildpkg=y || /bin/bash

# This makes sure we have the latest and greatest genmenu!
emerge -1 app-admin/genmenu || /bin/bash

# Runs the menu generator with a specific parameters for a WM
genmenu.py -e || /bin/bash
genmenu.py -x || /bin/bash

# Fixes icons
#cp -af /usr/share/icons/hicolor/48x48/apps/*.png /usr/share/pixmaps/

# Fixes menu
cp -af /etc/xdg/menus/gnome-applications.menu /etc/xdg/menus/applications.menu || /bin/bash

# Apply patches to root
cd /
#replaced by livecd-tools-2.0.3
#patch bin/bashlogin patches/bashlogin.patch || /bin/bash
#halt fails but shouldn't
#patch etc/init.d/halt.sh patches/halt.patch || /bin/bash
patch sbin/livecd-functions.sh patches/livecd-functions.patch || /bin/bash
#patch lib/rc/sh/init.sh patches/rc.patch
#autoconf fails
#patch etc/init.d/autoconfig patches/autoconfig.patch || /bin/bash
rm -rf patches || /bin/bash

# fixes pax for binary drivers GPGPU
paxctl -m /usr/bin/X || /bin/bash
# fixes pax for metasploit/java attacks/wpscan
paxctl -m /usr/bin/ruby19 || /bin/bash

# Setup fonts
cd /usr/share/fonts
mkfontdir * || /bin/bash
eselect fontconfig enable 10-sub-pixel-rgb.conf || /bin/bash
eselect fontconfig enable 57-dejavu-sans-mono.conf || /bin/bash
eselect fontconfig enable 57-dejavu-sans.conf || /bin/bash
eselect fontconfig enable 57-dejavu-serif.conf || /bin/bash

# Setup kismet & airmon-ng
[ -e /usr/sbin/airmon-ng ] && sed -i -e 's:/kismet::' /usr/sbin/airmon-ng
[ -e /etc/kismet.conf ] && sed -i -e '/^source=.*/d' /etc/kismet.conf
[ -e /etc/kismet.conf ] && sed -i -e 's:configdir=.*:configdir=/root/kismet:' -e 's/your_user_here/kismet/' /etc/kismet.conf
[ -e /etc/kismet.conf ] && useradd -g root kismet
[ -e /etc/kismet.conf ] && cp -a /etc/kismet.conf /etc/kismet.conf~
[ -e /etc/kismet.conf ] && mkdir /root/kismet && chown kismet /root/kismet

# Setup tor-privoxy
echo 'forward-socks4a / 127.0.0.1:9050' >> /etc/privoxy/config
mv -f /etc/tor/torrc.sample /etc/tor/torrc || /bin/bash
mkdir /var/log/tor || /bin/bash
chown tor:tor /var/lib/tor || /bin/bash
chown tor:tor /var/log/tor || /bin/bash

# Setup ntop
chmod 777 -R /var/lib/ntop || /bin/bash
ntop --set-admin-password=pentoo || /bin/bash

# Configure mysql
echo '[client]' > /root/.my.cnf
echo 'password=pentoo' >> /root/.my.cnf
emerge --config mysql || /bin/bash
rm -f /root/.my.cnf || /bin/bash

#configure postgres
echo y | emerge --config dev-db/postgresql-server || /bin/bash
touch /run/openrc/softlevel
/etc/init.d/postgresql-9.2 start || /bin/bash
emerge --config net-analyzer/metasploit || /bash/bash

#metasploit first run to create db, etc, and speed up livecd first run
echo -e exit | msfconsole

/etc/init.d/postgresql-9.2 stop || /bin/bash
rm -rf /run/openrc/softlevel || /bin/bash

#configure freeradius
emerge --config net-dialup/freeradius || /bin/bash

#gtk-theme-switch segfaults
#gtk-theme-switch /usr/share/themes/Xfce-basic || /bin/bash
echo gtk-theme-name="Xfce-basic" >> /root/.gtkrc-2.0
echo gtk-icon-theme-name="Tango" >> /root/.gtkrc-2.0

mkdir -p /root/.config/gtk-3.0/
cat <<-EOF > /root/.config/gtk-3.0/settings.ini
	[Settings]
	gtk-theme-name = Xfce-basic
	gtk-icon-theme-name = Tango
	gtk-fallback-icon-theme = gnome
EOF

mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/pentoo/wallpaper/xfce4-desktop.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || /bin/bash
#easy way to adjust wallpaper per install

smart-live-rebuild -E --timeout=60 -- --buildpkg=y

emerge --oneshot --usepkg=n --buildpkg=y media-gfx/graphviz

#prevent the "new style" network interface names for now
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

#forcibly untrounce our blacklist, caused by udev remerging
rm -f /etc/modprobe.d/._cfg0000_blacklist.conf

#merge all other desired changes into /etc
etc-update --automode -5 || /bin/bash

#set the hostname properly
sed -i 's/livecd/pentoo/' /etc/conf.d/hostname

#forcibly remove binary driver files, unmerge isn't good enough it seems
rm -rf /lib/modules/$(uname -r)/video

eselect ruby set ruby19 || /bin/bash
eselect bashcomp enable --global base || /bin/bash
eselect bashcomp enable --global eselect || /bin/bash
eselect bashcomp enable --global gentoo || /bin/bash
eselect bashcomp enable --global procps || /bin/bash
eselect bashcomp enable --global screen || /bin/bash
eselect bashcomp enable --global module-init-tools || /bin/bash

revdep-rebuild -- --buildpkg=y
if [ $? -ne 0 ]; then
	rm -rf /var/cache/revdep-rebuild/*.rr
	revdep-rebuild -- --buildpkg=y || /bin/bash
fi
rc-update -u || /bin/bash

## XXX: THIS IS A HORRIBLE IDEA!!!!
# So here is what is happening, we are building the iso with -ggdb and splitdebug so we can figure out wtf is wrong when things are wrong
# The issue is it isn't really possible (nor desirable) to have all this extra debug info on the iso so here is what we do...
#We make a dir with full path for where the debug info goes abusing the fancy /var/tmp/portage tmpfs mount
mkdir -p /var/tmp/portage/debug/rootfs/usr/lib/debug/ || /bin/bash
#then we rsync all the debug info into a rootfs for building a module
rsync -aEXu /usr/lib/debug/ /var/tmp/portage/debug/rootfs/usr/lib/debug/ || /bin/bash
# last we build the module and stash it in PORT_LOGDIR as it is definately on the host system but not the chroot
mksquashfs /var/tmp/portage/debug/rootfs/ /var/log/portage/debug-info-`date "+%Y%m%d"`.lzm -comp xz -Xbcj x86 -b 1048576 -Xdict-size 1048576 -no-recovery -noappend || /bin/bash
# and we add /usr/lib/debug to cleanables in livecd-stage2.spec
rm -rf /var/tmp/portage/debug

## More with the horrible hack
# So it seems I have picked /var/log/portage to just randomly spew stuff into
wget https://pentoo.googlecode.com/svn/genhtml/gen_installedlist.sh
wget https://pentoo.googlecode.com/svn/genhtml/header.inc
wget https://pentoo.googlecode.com/svn/genhtml/footer.inc
sh gen_installedlist.sh > /var/log/portage/tools_list_${arch}_`date "+%Y%m%d"`.html
rm -rf gen_installedlist.sh header.inc footer.inc

rm -rf /var/tmp/portage/*
eclean-pkg
sync
sleep 60
updatedb || /bin/bash
sync
sleep 60
rm -f /root/.bash_history
