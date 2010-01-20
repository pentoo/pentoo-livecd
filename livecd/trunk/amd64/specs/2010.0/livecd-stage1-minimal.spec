subarch: x86
version_stamp: 2005.1
target: livecd-stage1
rel_type: default
profile: default-linux/x86/2005.1
snapshot: official
source_subpath: default/stage3-x86-2005.1
livecd/use:
	-*
	ipv6
	socks5
	livecd
	fbcon
	ncurses
	readline
	ssl
	atm
	
livecd/packages:
	livecd-tools
	gentoo-sources
	dhcpcd
	acpid
	apmd
	coldplug
	fxload
	irssi
	gpm
	syslog-ng
	parted
	lynx
	links
	raidtools
	dosfstools
	nfs-utils
	jfsutils
	xfsprogs
	alsa-utils
	e2fsprogs
	reiserfsprogs
	ntfsprogs
	pwgen
	popt
	dialog
	rp-pppoe
	screen
	mirrorselect
	penggy
	iputils
	hwsetup
	lvm2
	evms
	vim
	pptpclient
	mdadm
	ethtool
	wireless-tools
#	prism54-firmware
	zd1201-firmware
	wpa_supplicant
#	vlock
