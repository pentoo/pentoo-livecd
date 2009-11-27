#/bin/sh!

# Purge the uneeded locale, should keeps only en
localepurge

# Set the timezone
if [[ -e /etc/conf.d/clock ]]
then
	sed -i -e 's/#TIMEZONE="Factory"/TIMEZONE="UTC"/' /etc/conf.d/clock
fi

# Parallel_startup and net hotplug
if [[ -e /etc/rc.conf ]]
then
	sed -i -e '/#rc_parallel/ s/NO/NO/' -e '/#rc_parallel/ s/#//' /etc/rc.conf
	sed -i -e '/#rc_hotplug/ s/\*/!net.\*/' -e '/#rc_hotplug/ s/#//' /etc/rc.conf
fi

# Fix provide rc-script annoyance
cd /etc/init.d/
ln -s net.lo net.wlan0
ln -s net.lo net.eth0
sed -e '/provide net/D' -i dhcpcd

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
# Over 1Mb doc is too much for now, we save some space
cd /usr/share/doc
du -sh * | grep M | sed -e 's/.*\t//' | xargs rm -rf

# Runs the incredible menu generator! Twice !
genmenu.py -v -t urxvt
genmenu.py -e -v -t urxvt

# Fixes icons
cp -a /usr/share/icons/hicolor/48x48/apps/*.png /usr/share/pixmaps/

# Fixes menu
cp -a /etc/xdg/menus/gnome-applications.menu /etc/xdg/menus/applications.menu

# Fixes mkxf86config
sed -i -e 's:/sbin/functions.sh:/lib/rc/sh/functions.sh:' /usr/sbin/mkxf86config.sh

# Fix the root login by emptying the root password. No ssh will be allowed until 'passwd root'
sed -i -e 's/^root:\*:/root::/' /etc/shadow

# Remove useless opengl setup
rm /etc/init.d/x-setup
eselect opengl set xorg-x11 --dst-prefix=/etc/opengl/
rm /usr/lib/libGLcore.so
[ -e /usr/lib64 ] && ln -s /etc/opengl/lib64 /etc/opengl/lib
[ -e /usr/lib32 ] && rm -f /usr/lib32/libGLcore.so

# Set default java vm
eselect java-vm set system sun-jre-bin-1.6
if [ -e /usr/lib64 ] ; then
	eselect java-nsplugin set 64bit sun-jre-bin-1.6
else
	eselect java-nsplugin set sun-jre-bin-1.6
fi

# Configure mysql
emerge --config mysql

# Add e17 repo
rm -rf /usr/local/portage
layman -L
layman -a pentoo
layman -a enlightenment

# Build the metadata cache
sed -i -e 's:ccache:ccache /mnt/livecd /.unions:' /etc/updatedb.conf
emerge --metadata
eix-update
updatedb

# Fix /etc/make.conf
echo 'USE="X livecd -nls gtk -kde -eds gtk2 cairo pam firefox gpm dvdr oss
mmx sse sse2 mpi wps offensive
wifi injection lzma speed gnuplot pyx bluetooth test-programs fwcutter
-quicktime -qt -qt3 qt3support qt4 -webkit -cups -spell lua curl -dso
png jpeg gif dri svg aac nsplugin xrandr consolekit -ffmpeg
alsa esd gstreamer jack mp3 vorbis wavpack wma
dvd mpeg ogg rtsp x264 xvid sqlite truetype
opengl dbus binary-drivers -hal acpi usb subversion"' >> /etc/make.conf
echo 'INPUT_DEVICES="keyboard mouse"
VIDEO_CARDS="fbdev glint intel mach64 mga neomagic nv radeon radeonhd savage sis tdfx trident vesa vga via vmware voodoo apm ark chips cirrus cyrix epson i128 i740 imstt nsc rendition s3 s3virge siliconmotion"
MAKEOPTS="-j2"
#GENTOO_MIRRORS="ftp://mirror.switch.ch/mirror/gentoo"
#SYNC="rsync://rsync.europe.gentoo.org"' >> /etc/make.conf
echo 'PORTDIR_OVERLAY="/usr/local/portage"' >> /etc/make.conf
echo 'source /usr/local/portage/layman/make.conf' >> /etc/make.conf

# Apply patches to root
cd /
patch bin/bashlogin patches/bashlogin.patch 
patch etc/init.d/halt.sh patches/halt.patch 
patch sbin/livecd-functions.sh patches/livecd-functions.patch
patch lib/rc/sh/init.sh patches/rc.patch
patch etc/init.d/autoconfig patches/autoconfig.patch
patch /usr/lib/metasploit3/lib/rex/socket/ssl_tcp_server.rb patches/patch-sslsniff.patch
rm -rf patches

# Fix net services
sed -e '/PORTMAP_OPTS/ s/^#//' -i /etc/conf.d/portmap
sed -e '/ESD_OPTIONS/ s/ -public//' -i /etc/conf.d/esound

# Fix the kernel dir & config
for krnl in `ls /lib/modules/`; do
	rm /usr/src/linux
	ln -s /usr/src/linux-$krnl /usr/src/linux
	cp /var/tmp/pentoo.config /usr/src/linux/.config
	rm /lib/modules/$krnl/source /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/build
	ln -s /usr/src/linux-$krnl /lib/modules/$krnl/source
	cd /usr/src/linux
	make prepare && make modules_prepare
	cp -a /tmp/kerncache/pentoo/usr/src/linux/?odule* ./
done

# Setup fonts
cd /usr/share/fonts
mkfontdir *

# Setup kismet & airmon-ng
[ -e /usr/sbin/airmon-ng ] && sed -i -e 's:/kismet::' /usr/sbin/airmon-ng
[ -e /etc/kismet.conf ] && sed -i -e '/^source=.*/d' /etc/kismet.conf
[ -e /etc/kismet.conf ] && sed -i -e 's:configdir=.*:configdir=/root/kismet:' -e 's/your_user_here/kismet/' /etc/kismet.conf
[ -e /etc/kismet.conf ] && useradd -g root kismet
[ -e /etc/kismet.conf ] && cp -a /etc/kismet.conf /etc/kismet.conf~
[ -e /etc/kismet.conf ] && mkdir /root/kismet && chown kismet /root/kismet

# Setup tor-privoxy
echo 'forward-socks4a / 127.0.0.1:9050' >> /etc/privoxy/config
cp /etc/tor/torrc.sample /etc/tor/torrc
mkdir /var/log/tor
chown tor:tor /var/lib/tor
chown tor:tor /var/log/tor

# Setup ntop
chmod 777 -R /var/lib/ntop
ntop --set-admin-password=pentoo

# compile mingw32
#crossdev --portage -bk i686-mingw32

# Adds sploit collection
cd /opt/
mkdir exploits
#mkdir exploits/packetstorm -p
#for file in `ls *.tgz`
#do
#	tar -zxf ${file} -C exploits/packetstorm/
#	rm -f ${file}
#done
tar -jxf archive.tar.bz2 -C exploits/
rm -f archive.tar.bz2
