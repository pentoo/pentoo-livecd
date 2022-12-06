#!/bin/bash -x
source /etc/profile
env-update
source /tmp/envscript

fix_locale() {
  for i in /etc/locale.nopurge /etc/locale.gen; do
  	echo C.UTF-8 UTF-8 > "${i}"
  	echo en_US ISO-8859-1 >> "${i}"
  	echo en_US.UTF-8 UTF-8 >> "${i}"
  done
	eselect locale set C.utf8 || error_handler
  env-update
  . /etc/profile
	locale-gen || error_handler
}

error_handler() {
  if [ -n "${PS1}" ]; then
    #this is an interactive shell, so ask the user for help
    /bin/bash
  else
    #not interactive, fail hard
    exit 1
  fi
}


if [ "${clst_subarch}" = "pentium-m" ]; then
	ARCH="x86"
  PROFILE_ARCH="x86"
elif [ "${clst_subarch}" = "amd64" ]; then
	ARCH="amd64"
  PROFILE_ARCH="amd64_r1"
else
	echo "failed to handle arch"
	/bin/bash
fi

#just in case, this seems to keep getting messed up
chown -R portage:portage /usr/portage
chown -R portage:portage /var/gentoo/repos/local
chown -R portage:portage /var/db/repos/gentoo
chown -R portage:portage /var/db/repos/pentoo
chown -R portage:portage /var/db/repos/local

emerge -1kb --newuse --update sys-apps/portage || error_handler

#somehow the default .bashrc runs X.... WTF????
\cp -f /etc/skel/.bashrc /root/.bashrc || error_handler

#user gets wierd groups, fix it for us
#defaults users,wheel,audio,plugdev,games,cdrom,disk,floppy,usb
gpasswd -d pentoo games || error_handler #remove from games group
if portageq has_version / pentoo/pentoo; then
  #default and full isos have these groups
  usermod -a -G audio,cdrom,cdrw,kismet,pcscd,plugdev,portage,usb,users,uucp,video,wheel,pcap pentoo || error_handler
else
  #pentoo-core is missing kismet and pcap
  usermod -a -G audio,cdrom,cdrw,pcscd,plugdev,portage,usb,users,uucp,video,wheel pentoo || error_handler
fi

#things are a little wonky with the move from /etc/ to /etc/portage of some key files so let's fix things a bit
rm -rf /etc/make.conf /etc/make.profile || error_handler

# Purge the uneeded locale, should keeps only en and utf8
fix_locale

# Set the timezone
if [[ -e /etc/conf.d/clock ]]
then
	sed -i -e 's/#TIMEZONE="Factory"/TIMEZONE="UTC"/' /etc/conf.d/clock || error_handler
fi

# Parallel_startup and net hotplug
if [[ -e /etc/rc.conf ]]
then
	sed -i -e '/#rc_parallel/ s/NO/NO/' -e '/#rc_parallel/ s/#//' /etc/rc.conf || error_handler
	sed -i -e '/#rc_hotplug/ s/\*/!net.\*/' -e '/#rc_hotplug/ s/#//' /etc/rc.conf || error_handler
fi

# Fixes libvirtd
if [[ -e /etc/libvirtd/libvirtd.conf ]]
then
	sed -i -e '/#listen_addr/ s/192.168.0.1/127.0.0.1/' -e '/#listen_addr/ s/#//' /etc/libvirtd/libvirtd.conf || error_handler
fi

# Fix provide rc-script annoyance
pushd /etc/init.d/
ln -s net.lo net.wlan0
ln -s net.lo net.eth0
sed -e '/provide net/D' -i dhcpcd || error_handler
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
rc-update -u || error_handler

#default net to null
echo modules=\"\!wireless\" >> /etc/conf.d/net
echo config_wlan0=\"null\" >> /etc/conf.d/net
echo config_eth0=\"null\" >> /etc/conf.d/net

# Fixes functions.sh location since baselayout-2
ln -s /lib/rc/sh/functions.sh /sbin/functions.sh || error_handler

# Fix the root login by emptying the root password. No ssh will be allowed until 'passwd root'
sed -i -e 's/^root:\*:/root::/' /etc/shadow || error_handler

# Set default java vm
if eselect java-vm list | grep openjdk-8; then
  eselect java-vm set system openjdk-8 || error_handler
fi

#mark all news read
eselect news read --quiet all || error_handler
#eselect news purge || error_handler

# Add pentoo repo but use only the version we are packaging in the iso
# this avoids corrupting timestamps in /var/cache/edb/mtimedb
#mkdir -p /var/db/repos/pentoo || error_handler
#rsync -aEXu --delete /var/gentoo/repos/local/ /var/db/repos/pentoo/ || error_handler
#rm -rf /var/gentoo/repos/local
chown -R portage:portage /var/db/repos || error_handler
mkdir -p /var/cache/distfiles || error_handler
chown portage:portage /var/cache/distfiles || error_handler

if [ "${clst_version_stamp/full}" != "${clst_version_stamp}" ]; then
  #full is the profile default
  detected_use=""
elif [ "${clst_version_stamp/core}" != "${clst_version_stamp}" ]; then
  #core is as slim as possible
  detected_use="pentoo-minimal -office -pentoo-full"
else
  #not full is not default due to hysterical raisens
  detected_use="-office -pentoo-full"
fi
if [ "${clst_version_stamp/kde}" != "${clst_version_stamp}" ]; then
  detected_use="${detected_use} -xfce kde"
fi
if [ "${clst_subarch}" = "amd64" ]; then
  detected_use="opencl ${detected_use}"
fi

#WARNING WARNING WARING
#DO NOT edit the line "bindist livecd" without also adjusting pentoo-installer
#We need to amend pentoo-installer to optionally toggle on and off these use flags, some of may be non-desirable for an installed system
cat <<-EOF > /etc/portage/make.conf.new
	#This is the default Pentoo make.conf file, it controls many basic system settings.
	#You can find information on how to edit this file in "man make.conf" as well as
	#on the web at https://wiki.gentoo.org/wiki/etc/portage/make.conf

	DISTDIR="$(portageq envvar DISTDIR)"
	PKGDIR="$(portageq envvar PKGDIR)"

	#Please adjust your CFLAGS as desired, information can be found here: https://wiki.gentoo.org/wiki/CFLAGS
	#Do not modify these FLAGS unless you know what you are doing, always check the defaults first with "portageq envvar CFLAGS"
	#This is the default for pentoo at the time of build:
	#CFLAGS="$(portageq envvar CFLAGS)"
	#A safe choice would be to keep whatever Pentoo defaults are, but optimize for your specific machine:
	#CFLAGS="\${CFLAGS} -march=native"
	#If you do change your CFLAGS, it is best for all the compile flags to match so uncomment the following three lines:
	#CXXFLAGS="\${CFLAGS}"
	#FCFLAGS="\${CFLAGS}"
	#FFLAGS="\${CFLAGS}"

EOF
if [ "${clst_subarch}" = "amd64" ]; then
cat <<-EOF >> /etc/portage/make.conf.new
	#Please adjust your use flags, if you don't use gpu cracking, it is probably safe to remove opencl
EOF
fi
if [ -n "${detected_use}" ]; then
	cat <<-EOF >> /etc/portage/make.conf.new
	USE="\${USE} ${detected_use}"
EOF
fi
cat <<-EOF >> /etc/portage/make.conf.new
	USE="\${USE} bindist livecd"

	#MAKEOPTS is set automatically by the profile to jobs equal to processors, you do not need to set it.

	#Default VIDEO_CARDS setting enables nearly everything, you can enable fewer here if you like:
	#VIDEO_CARDS="nvidia nouveau amdgpu radeon"
	#Intel gpu should use modesetting driver which isn't optional but the recommended setting is: VIDEO_CARDS="intel i965"
	#you can check available options with "emerge -vp xorg-drivers"
EOF
mv -f /etc/portage/make.conf.new /etc/portage/make.conf || error_handler
if [ ! -f "/etc/portage/repos.conf/pentoo.conf" ]; then
  #XXX for the incredibly tiny, make sure we have pentoo defined
  #XXX remove this hack when we have a super tiny metapackage to handle such things, which needs to be soon
  mkdir /etc/portage/repos.conf
  cp /var/db/repos/pentoo/pentoo/pentoo-system/files/pentoo-r2.conf /etc/portage/repos.conf/pentoo.conf
  #XXX the above is shit, make a tiny metapackage
fi

#deleting this earlier causes the above calls to portageq to break
rm -rf /usr/local/portage || error_handler

#foo=$(readlink /etc/portage/make.profile); foo="${PORTDIR}/profiles/${foo#*profiles/}; ln -snf "${foo}" /etc/portage/make.profile

if gcc -v 2>&1 | grep -q Hardened
then
	hardening=hardened
else
  hardening=default
fi

eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH} || error_handler
portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH}/bleeding_edge

# Build the metadata cache
rm -rf /var/cache/edb/dep || error_handler
emerge --regen || error_handler

#this file isn't created but eix needs it
touch /var/cache/eix/portage.eix
chown root:portage /var/cache/eix/portage.eix
chmod 664 /var/cache/eix/portage.eix
HOME=/tmp eix-update || error_handler

portageq has_version / pentoo/tribe && echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf
portageq has_version / pentoo/tribe && echo 'USE="${USE} -bluetooth -database -exploit -footprint -forensics -forging -fuzzers -mitm -mobile -proxies -qemu -radio -rce -scanner -voip -wireless -wireless-compat"' >> /etc/portage/make.conf

if [ "$(equery --quiet list pentoo/pentoo-installer 2> /dev/null)" = "pentoo/pentoo-installer-99999999" ]; then
  emerge -1 pentoo-installer || error_handler
fi

# Fix the kernel config
for krnl in `ls /usr/src/ | grep -e "linux-" | sed -e 's/linux-//'`; do
	if [ -d /tmp/kernel_maps ] ; then
		rm -rf /tmp/kernel_maps
	fi
	mkdir /tmp/kernel_maps
	cp -a /usr/src/linux/?odule* /tmp/kernel_maps/
  #make clean doesn't remove this
  rm -f /tmp/kernel_maps/Module.symvers
	cp -a /usr/src/linux/System.map /tmp/kernel_maps/
	pushd /usr/src/linux
	#mrproper wipes the random seed and means we cannot build modules, be careful here
	make -j clean
	#cp -a /var/tmp/pentoo.config /usr/src/linux/.config
	cp -a /tmp/kernel_maps/* /usr/src/linux
	make -j prepare
	make -j modules_prepare
  popd
done

emerge --deselect=y livecd-tools || error_handler
emerge --deselect=y sys-fs/zfs || error_handler
emerge --deselect=y sys-kernel/pentoo-sources || error_handler

for i in /var/gentoo/repos/local /var/db/repos/local /var/db/repos/pentoo; do
  [ -x ${i}/scripts/bug-461824.sh ] && ${i}/scripts/bug-461824.sh
done

emerge -qN -kb -D --with-bdeps=y @world -vt --backtrack=99 --update
if portageq has_version / pentoo/pentoo; then
  if ! emerge -qN -kb -D --with-bdeps=y pentoo/pentoo -vt --update; then
    emerge -qN -kb -D --with-bdeps=y pentoo/pentoo -vt --update || error_handler
  fi
fi
#layman -S
emerge -qN -kb -D --with-bdeps=y @world -vt --backtrack=99 --update || error_handler
if portageq list_preserved_libs /; then
	emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

#dropping usepkg on x11-modules-rebuild, doesn't make sense to use
emerge -qN -D --usepkg=n --buildpkg=y @x11-module-rebuild || error_handler
if portageq list_preserved_libs /; then
        emerge --buildpkg=y @preserved-rebuild -q || echo "preserved-rebuild failed"
fi

#if ! revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y; then
#	revdep-rebuild -i -- --rebuild-exclude dev-java/swt --exclude dev-java/swt --buildpkg=y || error_handler
#fi
if ! revdep-rebuild -i -- --usepkg=n --buildpkg=y; then
	revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler
fi


if [ -x /usr/sbin/python-updater ]; then
	python-updater -- --buildpkg=y || error_handler
fi
perl-cleaner --ph-clean --modules -- --usepkg=n --buildpkg=y || safe_exit
#the above line should always be enough
#perl-cleaner --all -- --usepkg=n --buildpkg=y || error_handler

/var/db/repos/local/scripts/bug-461824.sh
/var/db/repos/pentoo/scripts/bug-461824.sh

if portageq has_version / pentoo/pentoo-desktop; then
  # This makes sure we have the latest and greatest genmenu!
  emerge -1 app-admin/genmenu || error_handler

  # Runs the menu generator with a specific parameters for a WM
  su pentoo -c "genmenu.py -e" || error_handler
  su pentoo -c "genmenu.py -x" || error_handler
fi

# Fixes menu (may no longer be needed)
if [ -f /etc/xdg/menus/gnome-applications.menu ]; then
	cp -af /etc/xdg/menus/gnome-applications.menu /etc/xdg/menus/applications.menu || error_handler
fi

#if [ $(command -v paxctl-ng 2> /dev/null) ]; then
#	# fixes pax for metasploit/java attacks/wpscan
#	for i in $(ls /usr/bin/ruby2[1-9]); do
#		paxctl-ng -m ${i} || error_handler
#	done
#fi

# Setup fonts
pushd /usr/share/fonts
mkfontdir * || error_handler
popd
if portageq has_version / media-libs/fontconfig; then
  eselect fontconfig enable 10-sub-pixel-rgb.conf || error_handler
  if portageq has_version / media-fonts/dejavu; then
    eselect fontconfig enable 57-dejavu-sans-mono.conf || error_handler
    eselect fontconfig enable 57-dejavu-sans.conf || error_handler
    eselect fontconfig enable 57-dejavu-serif.conf || error_handler
  fi
fi

# Setup kismet
#if [ -e /etc/kismet.conf ]; then
#  sed -i -e 's#.kismet#kismet#' /etc/kismet.conf
#fi

# Setup tor-privoxy
if [ -d /etc/privoxy ]; then
  echo 'forward-socks4a / 127.0.0.1:9050 .' >> /etc/privoxy/config
fi
if [ -f /etc/tor/torrc.sample ]; then
  mv -f /etc/tor/torrc.sample /etc/tor/torrc || error_handler
  mkdir /var/log/tor || error_handler
  chown tor:tor /var/lib/tor || error_handler
  chown tor:tor /var/log/tor || error_handler
fi

#allow this to fail for right now so builds don't randomly stop and piss me off
smart-live-rebuild -E --timeout=60 -- --buildpkg=y

if portageq has_version / postgres; then
  #configure postgres
  echo y | emerge --config dev-db/postgresql || error_handler
  sleep 1m
  touch /run/openrc/softlevel
  /etc/init.d/postgresql-"$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}')" start
  if [ $? -ne 0 ]; then
    sleep 5m
    /etc/init.d/postgresql-"$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}')" start
    if [ $? -ne 0 ]; then
      sleep 5m
      killall postgres
      /etc/init.d/postgresql-"$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}')" start || error_handler
    fi
  fi

  if portageq has_version / metasploit; then
    emerge --config net-analyzer/metasploit || /bash/bash

    #metasploit first run to create db, etc, and speed up livecd first run
    if [ -x "/usr/bin/msfconsole" ]; then
      HOME=/root msfconsole -x exit || error_handler
    fi
  fi

  /etc/init.d/postgresql-"$(qlist -SC dev-db/postgresql | awk -F':' '{print $2}')" stop || error_handler
  rm -rf /run/openrc/softlevel || error_handler
fi


if [ -f /etc/skel/Desktop/pentoo-installer.desktop ] && [ ! -f /home/pentoo/Desktop/pentoo-installer.desktop ]; then
	su pentoo -c 'mkdir -p /home/pentoo/desktop'
	cp /etc/skel/Desktop/pentoo-installer.desktop /home/pentoo/Desktop/pentoo-installer.deskop
	chown pentoo:users /home/pentoo/Desktop/pentoo-installer.deskop
fi

#basic xfce4 setup
#mkdir -p /root/.config/xfce4/
#cp -r /etc/xdg/xfce4/panel/ /root/.config/xfce4/ || error_handler
#magic to autohide panel 2
#magic_number=$(($(sed -n '/<value type="int" value="14"\/>/=' /root/.config/xfce4/panel/default.xml)+1))
#sed -i "${magic_number} a\    <property name=\"autohide-behavior\" type=\"uint\" value=\"1\"/>" /root/.config/xfce4/panel/default.xml
#easy way to adjust wallpaper per install
#mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || error_handler
#cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/ || error_handler

if portageq has_version / pentoo/pentoo-desktop; then
  su pentoo -c "mkdir -p /home/pentoo/.config/xfce4/" || error_handler
  su pentoo -c "cp -r /etc/xdg/xfce4/panel/ /home/pentoo/.config/xfce4/" || error_handler

  #magic to autohide panel 2
  magic_number=$(($(sed -n '/<value type="int" value="14"\/>/=' /home/pentoo/.config/xfce4/panel/default.xml)+1))
  sed -i "${magic_number} a\    <property name=\"autohide-behavior\" type=\"uint\" value=\"1\"/>" /home/pentoo/.config/xfce4/panel/default.xml

  #magic to enable gnome-keyring, this file gets pulled when xfce4 starts for the first time
  head -n-1 /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml > /tmp/xfce4-session.xml
  echo '  <property name="compat" type="empty">' >> /tmp/xfce4-session.xml
  echo '    <property name="LaunchGNOME" type="bool" value="true"/>' >> /tmp/xfce4-session.xml
  echo '  </property>' >> /tmp/xfce4-session.xml
  tail -n1 /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml >> /tmp/xfce4-session.xml
  mv -f /tmp/xfce4-session.xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml

  #slim dm is much nicer than default xdm
  sed -i 's/"xdm"/"slim"/' /etc/conf.d/display-manager

  #blueman doesn't create this but needs it
  su pentoo -c "mkdir -p /home/pentoo/Downloads"
fi

#force password setting for pentoo user then prompt for starting X
echo "exec /usr/sbin/livecd-setpass" >> /home/pentoo/.bashrc

#forcibly untrounce our blacklist, caused by udev remerging
rm -f /etc/modprobe.d/._cfg0000_blacklist.conf

#merge all other desired changes into /etc
etc-update --automode -5 || error_handler

#etc-update looks like it sometimes crushes our locale settings
fix_locale
#set sudoers after etc-update as well
sed -i 's/# %wheel ALL=(ALL) NOPASSWD/%wheel ALL=(ALL) NOPASSWD/' /etc/sudoers

#set the hostname properly
sed -i 's/livecd/pentoo/' /etc/conf.d/hostname || error_handler
#set the hostname in /etc/hosts too (bug #236)
sed -i "/#/! s#localhost\(.*\)#localhost pentoo#" /etc/hosts || error_handler

#make nano pretty, turn on all syntax hilighting
sed -i '/include/s/# //' /etc/nanorc

if portageq has_version / dev-lang/ruby; then
  eselect ruby set ruby27 || error_handler
fi

find /var/db/pkg -name CXXFLAGS -exec grep -Hv -- "$(portageq envvar CFLAGS)" {} \; | awk -F/ '{print "="$5"/"$6}'
find /var/db/pkg -name CXXFLAGS -exec grep -Hv -- "$(portageq envvar CFLAGS)" {} \; | awk -F/ '{print "="$5"/"$6}' | wc -l

#short term insanity, rebuild everything which was built with debug turned on to shrink file sizes
#emerge --oneshot --usepkg=n --buildpkg=y $(grep -ir ggdb /var/db/pkg/*/*/CFLAGS | sed -e 's#/var/db/pkg/#=#' -e 's#/CFLAGS.*##')

if portageq list_preserved_libs /; then
	emerge --buildpkg=y @preserved-rebuild -q || error_handler
fi

if ! revdep-rebuild -i -- --usepkg=n --buildpkg=y; then
	revdep-rebuild -i -- --usepkg=n --buildpkg=y || error_handler
fi
rc-update -u || error_handler

#last let's make sure we have all the binpkgs we expect
quickpkg --include-config=y $($(portageq get_repo_path / pentoo)/scripts/binpkgs-missing-rebuild)

update-ca-certificates

#setup pinentry to a sane default
eselect pinentry set pinentry-gtk-2 || eselect pinentry set pinentry-curses

#cleanup temp stuff in /etc/portage from catalyst build
rm -f /etc/portage/make.conf.old
rm -f /etc/portage/make.conf.catalyst
rm -f /etc/portage/depcheck
rm -rf /etc/portage/profile

emerge -1kb portage || error_handler
if [ "${clst_version_stamp/full}" = "${clst_version_stamp}" ] || [ "${clst_version_stamp/core}" = "${clst_version_stamp}" ]; then
  #non-full iso means we expect things like builddeps sacrificed for size
  emerge --depclean --with-bdeps=n sys-kernel/genkernel --exclude sys-kernel/pentoo-sources
else
  emerge --depclean --with-bdeps=y --exclude sys-kernel/pentoo-sources
  #full expects most things present, but this shit is huge and bdep only
  emerge --depclean --with-bdeps=n 'dev-go/*' dev-lang/go dev-lang/go-bootstrap dev-java/gradle-bin virtual/rust virtual/cargo dev-lang/rust dev-lang/rust-bin sys-devel/gcc-arm-none-eabi sys-kernel/genkernel --exclude sys-kernel/pentoo-sources
fi

#cleanup binary drivers
if portageq has_version / x11-drivers/nvidia-drivers; then
  emerge -C nvidia-drivers || error_handler
  rm -f /lib/modules/*/video/*
fi

## XXX: THIS IS A HORRIBLE IDEA!!!!
# So it seems I have picked /var/log/portage to just randomly spew stuff into
if portageq has_version / dev-lang/ruby; then
  pushd /root/gentoollist
  mkdir -p /var/log/portage/tool-list
  ./gen_installedlist.rb > /var/log/portage/tool-list/tools_list_${ARCH}-${hardening}.json || error_handler
  sync
  popd
fi
rm -rf /root/gentoollist

rm -rf /var/tmp/portage/*
fixpackages
eclean-pkg -t 3m

#bug #477498
ln -snf /proc/self/mounts /etc/mtab

#reset profile to binary profile so users get it as default
eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH}/binary || error_handler
portageq has_version / pentoo/tribe && eselect profile set pentoo:pentoo/${hardening}/linux/${PROFILE_ARCH}/bleeding_edge

sync
sleep 20

for i in $(ls /var/cache); do
  [ "${i}" = "edb" ] && continue
  [ "${i}" = "eix" ] && continue
  [ "${i}" = "distfiles" ] && continue
  [ "${i}" = "binpkgs" ] && continue
  rm -rf "/var/cache/${i}"
done
#once more, with feeling
chown -R portage:portage /var/cache/distfiles || error_handler
chown root:portage -R /var/cache/edb
chown root:portage -R /var/cache/eix

#todo when we no longer need this stub for testing, replace with default
if [ -r /etc/issue.pentoo.logo ]; then
  rm -f /etc/issue
  cp -f /etc/issue.pentoo.logo /etc/issue
fi
find /root -uid 1001 -exec chown -h root:root {} \;
find /etc -uid 1001 -exec chown -h root:root {} \;

updatedb
#equery check -o '*' || error_handler
sync
sleep 60
rm -f /root/.bash_history
true
