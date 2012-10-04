#!/bin/sh

#things are a little wonky with the move from /etc/ to /etc/portage of some key files so let's fix things a bit
rm -rf /etc/make.conf /etc/make.profile || exit
#ln -s ../../usr/local/portage/profiles/pentoo/default/linux/amd64 /etc/portage/make.profile
eselect profile set pentoo:pentoo/hardened/linux/amd64 || exit

#check lib link and fix
if [ ! -L /lib ]
then
	if [ -d /lib64 ]
	then
		mv /lib/* /lib64/
		rm -rf /lib
		ln -s /lib64 lib
	fi
fi

# Purge the uneeded locale, should keeps only en and utf8
#sed '/^es/d' /etc/locale.nopurge #pretty sure this isn't needed
echo en_US ISO-8859-1 >> /etc/locale.nopurge
echo en_US.UTF-8 UTF-8 >> /etc/locale.nopurge
sed -i -e '/en_US ISO-8859-1/s/^# *//' -e '/en_US.UTF-8 UTF-8/s/^# *//' /etc/locale.gen || exit
localepurge || exit
locale-gen || exit

# Set the timezone
if [[ -e /etc/conf.d/clock ]]
then
	sed -i -e 's/#TIMEZONE="Factory"/TIMEZONE="UTC"/' /etc/conf.d/clock || exit
fi

# Parallel_startup and net hotplug
if [[ -e /etc/rc.conf ]]
then
	sed -i -e '/#rc_parallel/ s/NO/NO/' -e '/#rc_parallel/ s/#//' /etc/rc.conf || exit
	sed -i -e '/#rc_hotplug/ s/\*/!net.\*/' -e '/#rc_hotplug/ s/#//' /etc/rc.conf || exit
fi

# Fixes libvirtd
if [[ -e /etc/libvirtd/libvirtd.conf ]]
then
	sed -i -e '/#listen_addr/ s/192.168.0.1/127.0.0.1/' -e '/#listen_addr/ s/#//' /etc/libvirtd/libvirtd.conf || exit
fi

# Fix provide rc-script annoyance
cd /etc/init.d/
ln -s net.lo net.wlan0
ln -s net.lo net.eth0
rc-update -u || die
sed -e '/provide net/D' -i dhcpcd || exit

#default net to null
echo modules=\"\!wireless\" >> /etc/conf.d/net
echo config_eth0=\"null\" >> /etc/conf.d/net
echo config_wlan0=\"null\" >> /etc/conf.d/net


# Bunzip all docs since they'll be in sqlzma format
cd /usr/share/doc
for maindir in `find ./ -maxdepth 1 -type d | sed -e 's:^./::'`
do
        cd "${maindir}"
        for file in `ls *.bz2`
        do
                bunzip2 "${file}"
        done
        cd ..
done
# Over 1Mb doc is too much for now, we save some space <-- not sure I care anymore
#cd /usr/share/doc
#du -sh * | grep M | sed -e 's/.*\t//' | xargs rm -rf

# Fixes functions.sh location since baselayout-2
ln -s /lib/rc/sh/functions.sh /sbin/functions.sh || exit

# Fix the root login by emptying the root password. No ssh will be allowed until 'passwd root'
sed -i -e 's/^root:\*:/root::/' /etc/shadow || exit

# Remove useless opengl setup <--remove or fix this right
rm /etc/init.d/x-setup
eselect opengl set xorg-x11 --dst-prefix=/etc/opengl/
rm /usr/lib/libGLcore.so
[ -e /usr/lib64 ] && ln -s /etc/opengl/lib64 /etc/opengl/lib
[ -e /usr/lib32 ] && rm -f /usr/lib32/libGLcore.so
eselect opengl set xorg-x11

# Set default java vm <-- switch to icedtea
eselect java-vm set system sun-jdk-1.6
if [ -e /usr/lib64 ] ; then
	eselect java-nsplugin set 64bit sun-jdk-1.6
else
	eselect java-nsplugin set sun-jdk-1.6
fi

# Fix the name of firefox so the user know it:
#sed -e 's/Namoroka/Firefox/' -i /usr/share/applications/mozilla-firefox-3.6.desktop

#mark all news read
eselect news read --quiet all || exit
eselect news purge || exit

# Add pentoo repo
layman -L || exit
layman -a pentoo || exit
rm -rf /usr/local/portage/* || exit
eselect profile set pentoo:pentoo/default/linux/amd64 || exit
layman -S || die
eselect profile set pentoo:pentoo/default/linux/amd64 || exit
#layman -a enlightenment

# Build the metadata cache
sed -i -e 's:ccache:ccache /mnt/livecd /.unions:' /etc/updatedb.conf || exit
emerge --metadata || exit
eix-update || exit

# Fix /etc/portage/make.conf
sed -i 's#USE="mmx sse sse2"##' /etc/portage/make.conf || exit

#WARNING WARNING WARING
#DO NOT edit the line "aufs bindist livecd" without also adjusting pentoo-installer
echo 'USE="X gtk -kde -eds gtk2 cairo pam firefox gpm dvdr oss
cuda opencl mmx sse sse2 mpi wps offensive dwm 32bit -doc -examples
wifi injection lzma speed gnuplot pyx test-programs fwcutter qemu
-quicktime -qt -qt3 qt3support qt4 -webkit -cups -spell lua curl -dso
png jpeg gif dri svg aac nsplugin xrandr consolekit -ffmpeg fontconfig
alsa esd gstreamer jack mp3 vorbis wavpack wma
dvd mpeg ogg rtsp x264 xvid sqlite truetype nss
opengl dbus binary-drivers hal acpi usb subversion libkms
aufs bindist livecd
analyzer bluetooth cracking databse exploit forensics mitm proxies
scanner rce footprint forging fuzzers voip wireless xfce"' >> /etc/portage/make.conf
echo 'INPUT_DEVICES="evdev synaptics"
VIDEO_CARDS="virtualbox nvidia fglrx nouveau fbdev glint intel mach64 mga neomagic nv radeon radeonhd savage sis tdfx trident vesa vga via vmware voodoo apm ark chips cirrus cyrix epson i128 i740 imstt nsc rendition s3 s3virge siliconmotion"
ACCEPT_LICENSE="Oracle-BCLA-JavaSE AdobeFlash-10.3 google-talkplugin"
MAKEOPTS="-j2 -l1"' >> /etc/portage/make.conf
echo 'source /var/lib/layman/make.conf' >> /etc/portage/make.conf
echo 'ACCEPT_LICENSE="*"
RUBY_TARGETS="ruby18 ruby19"' >> /etc/portage/make.conf

eselect profile set pentoo:pentoo/hardened/linux/amd64 || exit
emerge -1 pentoo-installer || exit

# Fix the kernel dir & config
for krnl in `ls /usr/src/ | grep -e "linux-" | sed -e 's/linux-//'`; do
	rm /usr/src/linux
	ln -s linux-$krnl /usr/src/linux
	cp /var/tmp/pentoo.config /usr/src/linux/.config
	rm /lib/modules/$krnl/source /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/source
	cd /usr/src/linux
	make prepare && make modules_prepare
	cp -a /tmp/kerncache/pentoo/usr/src/linux/?odule* ./
	cp -a /tmp/kerncache/pentoo/usr/src/linux/System.map ./
done

emerge --deselect=y livecd-tools || exit
emerge --deselect=y app-text/build-docbook-catalog || exit

/bin/bash
MAKEOPTS="-j5 -l4" USE="-livecd-stage1" emerge -qN -kb -D --jobs=5 --load-average=4 --keep-going=y --binpkg-respect-use=y @world
layman -S
MAKEOPTS="-j5 -l4" USE="-livecd-stage1" emerge -qN -kb -D --jobs=5 --load-average=4 --keep-going=y --binpkg-respect-use=y @world || exit 1
emerge --depclean || die
revdep-rebuild
rm /var/cache/revdep-rebuild/*.rr

eselect python set python2.7 || exit
#eselect python set 1
MAKEOPTS="-j5 -l4" python-updater || exit 1
MAKEOPTS="-j5 -l4" perl-cleaner --modules || exit 1

# This makes sure we have the latest and greatest genmenu!
emerge -1 app-admin/genmenu || exit

# Runs the menu generator with a specific parameters for a WM
#genmenu.py -v -t urxvt
#genmenu.py -e -v -t urxvt
#genmenu.py -x -v -t Terminal
genmenu.py -x -v || exit 1

# Fixes icons
cp -a /usr/share/icons/hicolor/48x48/apps/*.png /usr/share/pixmaps/ || exit

# Fixes menu
cp -a /etc/xdg/menus/gnome-applications.menu /etc/xdg/menus/applications.menu || exit

# Apply patches to root
cd /
patch bin/bashlogin patches/bashlogin.patch || exit
patch etc/init.d/halt.sh patches/halt.patch || exit
patch sbin/livecd-functions.sh patches/livecd-functions.patch || exit
#patch lib/rc/sh/init.sh patches/rc.patch
patch etc/init.d/autoconfig patches/autoconfig.patch || exit
rm -rf patches || exit

# fixes pax for binary drviers GPGPU
paxctl -m /usr/bin/X || exit
# fixes pax for metasploit/java attacks/wpscan
paxctl -m /usr/bin/ruby19

# Setup fonts
cd /usr/share/fonts
mkfontdir * || exit
eselect fontconfig enable 10-sub-pixel-rgb.conf || exit
eselect fontconfig enable 57-dejavu-sans-mono.conf || exit
eselect fontconfig enable 57-dejavu-sans.conf || exit
eselect fontconfig enable 57-dejavu-serif.conf || exit

# Setup kismet & airmon-ng
[ -e /usr/sbin/airmon-ng ] && sed -i -e 's:/kismet::' /usr/sbin/airmon-ng
[ -e /etc/kismet.conf ] && sed -i -e '/^source=.*/d' /etc/kismet.conf
[ -e /etc/kismet.conf ] && sed -i -e 's:configdir=.*:configdir=/root/kismet:' -e 's/your_user_here/kismet/' /etc/kismet.conf
[ -e /etc/kismet.conf ] && useradd -g root kismet
[ -e /etc/kismet.conf ] && cp -a /etc/kismet.conf /etc/kismet.conf~
[ -e /etc/kismet.conf ] && mkdir /root/kismet && chown kismet /root/kismet

# Setup tor-privoxy
echo 'forward-socks4a / 127.0.0.1:9050' >> /etc/privoxy/config
cp /etc/tor/torrc.sample /etc/tor/torrc || exit
mkdir /var/log/tor || exit
chown tor:tor /var/lib/tor || exit
chown tor:tor /var/log/tor || exit

# Setup ntop
chmod 777 -R /var/lib/ntop || exit
ntop --set-admin-password=pentoo || exit

# Configure mysql
echo 'password=pentoo' > /root/.my.cnf
emerge --config mysql || exit
rm -f /root/.my.cnf || exit

gtk-theme-switch /usr/share/themes/Xfce-basic
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/
cp /usr/share/pentoo/wallpaper/xfce4-desktop.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || exit 1

smart-live-rebuild

#hack for openssh failing on livecd
CONFIG_PROTECT_MASK="/etc/" emerge openssh -1 || exit

CONFIG_PROTECT_MASK="/etc/" etc-update || exit

eselect ruby set ruby19 || exit
eselect bashcomp enable --global gentoo || exit
eselect bashcomp enable --global procps || exit
eselect bashcomp enable --global screen || exit
portageq has_version / module-init-tools && eselect bashcomp enable --global module-init-tools

revdep-rebuild
rm /var/cache/revdep-rebuild/*.rr
revdep-rebuild || exit
rc-update -u || exit
updatedb || exit
