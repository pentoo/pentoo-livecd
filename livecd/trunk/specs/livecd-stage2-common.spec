livecd/fstype: squashfs
#livecd/cdtar: /usr/lib/catalyst/livecd/cdtar/grub-memtest86+-cdtar.tar.bz2
#livecd/cdtar: /usr/lib/catalyst/livecd/cdtar/isolinux-3.72-memtest86+-cdtar.tar.bz2
livecd/cdtar: /usr/src/pentoo/livecd/trunk/isolinux-elilo-memtest86+-cdtar.tar.bz2

# A fsscript is simply a shell script that is copied into the chroot of the CD
# after the kernel(s) and any external modules have been compiled and is 
# executed within the chroot.  It can contain any commands that are available
# via the packages installed by our stages or by the packages installed during
# the livecd-stage1 build.  We do not use one for the official release media, so
# there will not be one listed below.  The syntax is simply the full path and
# filename to the shell script that you wish to execute.  The script is copied
# into the chroot by catalyst automatically.
livecd/fsscript: fsscript-livecd-stage2.sh

# This is a set of arguments that get passed to the bootloader for your CD.  It
# is used on the x86/amd64 release media to enable keymap selection.
livecd/bootargs: nodetect aufs max_loop=256 dokeymap

# This option controls quite a bit of catalyst internals and sets up several
# defaults.  Each type behaves slightly differently and is explained below.
# generic-livecd - This should be used for all non-official media.
livecd/type: generic-livecd

# This is for blacklisting modules from being hotplugged that are known to cause
# problems.  Putting a module name here will keep it from being auto-loaded,
# even if ti is detected by hotplug.
livecd/modblacklist: arusb_lnx rt2870sta rt3070sta prism54 r8187 pcspkr ieee1394 ar9170usb rtl2832 rtl2830 dvb_usb_rtl28xxu

# This is for adding init scripts to runlevels.  The syntax for the init script
# is the script name, followed by a pipe, followed by the runlevel in which you
# want the script to run.  It looks like spind|default and is space delimited.
# We do not use this on the official media, as catalyst sets up the runlevels
# correctly for us.  Since we do not use this, it is left blank below.
# This option will automatically create missing runlevels
livecd/rcadd: autoconfig|default acpid|default bluetooth|default consolekit|default firmware|boot gpm|default dbus|default

# This is for removing init script from runlevels.  It is executed after the
# defaults shipped with catalyst, so it is possible to remove the defaults using
# this option.  It can follow the same syntax as livcd/rcadd, or you can leave
# the runlevel off to remove the script from any runlevels detected.  We do not
# use this on the official media, so it is left blank.
livecd/rcdel: keymaps|boot netmount|default mdraid|boot

# This overlay is dropped onto the CD filesystem and is outside any loop which
# has been configured.  This is typically used for adding the documentation,
# distfiles, snapshots, and stages to the official media.  These files will not 
# be available if docache is enabled, as they are outside the loop.
livecd/overlay: /usr/src/pentoo/livecd/trunk/isoroot

# This overlay is dropped onto the filesystem within the loop.  This can be used
# for such things as updating configuration files or adding anything else you
# would want within your CD filesystem.  Files added here are available when
# docache is used.  We do not use this on the official media, so we will leave
# it blank below.
livecd/root_overlay: /usr/src/pentoo/livecd/trunk/root_overlay

# This option is used to create non-root users on your CD.  It takes a space
# separated list of user names.  These users will be added to the following
# groups: users,wheel,audio,games,cdrom,usb
# If this is specified in your spec file, then the first user is also the user
# used to start X. Since this is not used on the release media, it is blank.
livecd/users: pentoo

# This option is used to specify the number of kernels to build and also the
# labels that will be used by the CD bootloader to refer to each kernel image.
boot/kernel: pentoo

boot/kernel/pentoo/sources: pentoo-sources

# This option sets genkernel parameters on a per-kernel basis and applies only
# to this kernel label.  This can be used for building options into only a
# single kernel, where compatibility may be an issue.  Since we do not use this
# on the official release media, it is left blank, but it follows the same
# syntax as livecd/gk_mainargs.
boot/kernel/pentoo/gk_kernargs: 

# This option sets the USE flags used to build the kernel and also any packages
# which are defined under this kernel label.  These USE flags are additive from
# the default USE for the specified profile.
boot/kernel/pentoo/use: aufs livecd
#X aufs livecd gtk -kde -eds gtk2 cairo pam firefox gpm dvdr oss
#cuda opencl mpi wps offensive dwm -doc -examples
#wifi injection lzma speed gnuplot python pyx test-programs fwcutter
#-quicktime -qt -qt3 qt3support qt4 -cups -spell lua curl -dso
#png jpeg fuse gif dri svg aac nsplugin xrandr consolekit -ffmpeg fontconfig
#alsa esd jack mp3 vorbis wavpack wma
#dvd mpeg ogg rtsp x264 xvid sqlite truetype nss
#opengl dbus acpi usb subversion libkms
#-livecd-stage1 symlink

# This option appends an extension to the name of your kernel, as viewed by a
# uname -r/  This also affects any modules built under this kernel label.  This
# is useful for having two kernels using the same sources to keep the modules
# from overwriting each other.  We do not use this on the official media, so it
# is left blank.
# example:
# boot/kernel/gentoo/extraversion:

# This is a list of packages that will be unmerged after all the kernels have
# been built.  There are no checks on these packages, so be careful what you
# add here.  They can potentially break your CD.
livecd/unmerge: x11-drivers/ati-drivers x11-drivers/nvidia-drivers

# This option is used to empty the directories listed.  It is useful for getting
# rid of files that don't belong to a particular package, or removing files from
# a package that you wish to keep, but won't need the full functionality.
livecd/empty: /var/empty /run/lock /var/log /var/tmp /var/spool /tmp /usr/local/portage/ /var/lib/layman/pentoo /usr/lib/debug

# This option tells catalyst to clean specific files from the filesystem and is
# very usefu in cleaning up stray files in /etc left over after livecd/unmerge.
livecd/rm: /etc/resolv.conf /usr/share/doc/lib* /usr/share/doc/g* /usr/share/doc/tiff* /usr/share/doc/twisted* /usr/share/doc/ruby* /usr/share/doc/paramiko* /usr/share/doc/perl* /usr/share/doc/pcre*  /usr/share/doc/binutils* /usr/share/doc/ntp* /usr/share/doc/readline*
