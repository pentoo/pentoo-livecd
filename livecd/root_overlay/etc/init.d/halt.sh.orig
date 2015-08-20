#!/bin/bash
# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

[[ ${RC_GOT_FUNCTIONS} != "yes" ]] && source /sbin/functions.sh

# Check to see if this is a livecd, if it is read the commandline
# this mainly makes sure $CDBOOT is defined if it's a livecd
[[ -f /sbin/livecd-functions.sh ]] && \
	source /sbin/livecd-functions.sh && \
	livecd_read_commandline

# livecd-functions.sh should _ONLY_ set this differently if CDBOOT is
# set, else the default one should be used for normal boots.
# say:  RC_NO_UMOUNTS="/mnt/livecd|/newroot"
RC_NO_UMOUNTS=${RC_NO_UMOUNTS:-^(/|/dev|/dev/pts|/lib/rcscripts/init.d|/proc|/proc/.*|/sys)$}

# Reset pam_console permissions if we are actually using it
if [[ -x /sbin/pam_console_apply && ! -c /dev/.devfsd && \
      -n $(grep -v -e '^[[:space:]]*#' /etc/pam.d/* | grep 'pam_console') ]]; then
	/sbin/pam_console_apply -r
fi

stop_addon devfs
stop_addon udev

# Try to unmount all tmpfs filesystems not in use, else a deadlock may
# occure, bug #13599.
umount -at tmpfs &>/dev/null

# Turn off swap and perhaps zero it out for fun
swap_list=$(swapon -s 2>/dev/null)

if [[ -n ${swap_list} ]] ; then
	ebegin $"Deactivating swap"
	swapoff -a
	eend $?
fi

# Write a reboot record to /var/log/wtmp before unmounting

halt -w &>/dev/null

# Unmounting should use /proc/mounts and work with/without devfsd running

# Credits for next function to unmount loop devices, goes to:
#
#	Miquel van Smoorenburg, <miquels@drinkel.nl.mugnet.org>
#	Modified for RHS Linux by Damien Neil
#
#
# Unmount file systems, killing processes if we have to.
# Unmount loopback stuff first
# Use `umount -d` to detach the loopback device

# Remove loopback devices started by dm-crypt

remaining=$(awk '!/^#/ && $1 ~ /^\/dev\/loop/ && $2 != "/" {print $2}' /proc/mounts | \
            sort -r | egrep -v "${RC_NO_UMOUNTS}")
[[ -n ${remaining} ]] && {
	sig=
	retry=3

	while [[ -n ${remaining} && ${retry} -gt 0 ]]; do
		if [[ ${retry} -lt 3 ]]; then
			ebegin "Unmounting loopback filesystems (retry)"
			umount -d ${remaining} &>/dev/null
			eend $? "Failed to unmount filesystems this retry"
		else
			ebegin "Unmounting loopback filesystems"
			umount -d ${remaining} &>/dev/null
			eend $? "Failed to unmount filesystems"
		fi

		remaining=$(awk '!/^#/ && $1 ~ /^\/dev\/loop/ && $2 != "/" {print $2}' /proc/mounts | \
		            sort -r | egrep -v "${RC_NO_UMOUNTS}")
		[[ -z ${remaining} ]] && break
		
		/bin/fuser -s -k ${sig} -m ${remaining}
		sleep 5
		retry=$((${retry} - 1))
		sig=-9
	done
}

# Try to unmount all filesystems (no /proc,tmpfs,devfs,etc).
# This is needed to make sure we dont have a mounted filesystem 
# on a LVM volume when shutting LVM down ...
ebegin "Unmounting filesystems"
for x in $(awk '{print $2}' /proc/mounts | sort -ur) ; do
	x=${x//\\040/ }
	# Do not umount these ... will be different depending on value of CDBOOT
	if [[ -n $(echo "${x}" | egrep "${RC_NO_UMOUNTS}") ]] ; then
		continue
	fi

	# If we're using the mount (probably /usr) then don't unmount us
	if [[ " $(fuser -m "${x}" 2>/dev/null) " == *" $$ "* ]] ; then
		continue
	fi

	if ! umount "${x}" &>/dev/null; then
		# Kill processes still using this mount
		/bin/fuser -s -k -9 -m "${x}"
		sleep 2
		# Now try to unmount it again ...
		umount -f -r "${x}" &>/dev/null
	fi
done
eend 0

# Try to remove any dm-crypt mappings
stop_addon dm-crypt
stop_addon truecrypt

# Stop LVM, etc
for x in $(reverse_list ${RC_VOLUME_ORDER}) ; do
	stop_addon "${x}"
done

# This is a function because its used twice below
ups_kill_power() {
	local UPS_CTL UPS_POWERDOWN
	if [[ -f /etc/killpower ]] ; then
		UPS_CTL=/sbin/upsdrvctl
		UPS_POWERDOWN="${UPS_CTL} shutdown"
	elif [[ -f /etc/apcupsd/powerfail ]] ; then
		UPS_CTL=/etc/apcupsd/apccontrol
		UPS_POWERDOWN="${UPS_CTL} killpower"
	else
		return 0
	fi
	if [[ -x ${UPS_CTL} ]] ; then
		ewarn "Signalling ups driver(s) to kill the load!"
		${UPS_POWERDOWN}
		ewarn "Halt system and wait for the UPS to kill our power"
		/sbin/halt -id
		while [ 1 ]; do sleep 60; done
	fi
}

mount_readonly() {
	local x=
	local retval=0
	local cmd=$1

	# Get better results with a sync and sleep
	sync; sync
	sleep 1

	for x in $(awk '{print $2}' /proc/mounts | sort -ur) ; do
		x=${x//\\040/ }

		# Do not umount these ... will be different depending on value of CDBOOT
		if [[ ${x} != "/" \
			&& -n $(echo "${x}" | egrep "${RC_NO_UMOUNTS}") ]] ; then
			continue
		fi
		
		if [[ ${cmd} == "u" ]]; then
			umount -n -r "${x}"
		else
			mount -n -o remount,ro "${x}" &>/dev/null
		fi
		retval=$((${retval} + $?))
	done
	[[ ${retval} -ne 0 ]] && killall5 -9 &>/dev/null

	return ${retval}
}

# Since we use `mount` in mount_readonly(), but we parse /proc/mounts, we 
# have to make sure our /etc/mtab and /proc/mounts agree
cp /proc/mounts /etc/mtab &>/dev/null
ebegin "Remounting remaining filesystems readonly"
mount_worked=0
if ! mount_readonly ; then
	if ! mount_readonly ; then
		# If these things really don't want to remount ro, then 
		# let's try to force them to unmount
		if ! mount_readonly u ; then
			mount_worked=1
		fi
	fi
fi
eend ${mount_worked}
if [[ ${mount_worked} -eq 1 ]]; then
	ups_kill_power
	sulogin -t 10 /dev/console
fi

# Inform if there is a forced or skipped fsck
if [[ -f /fastboot ]]; then
	echo
	ewarn "Fsck will be skipped on next startup"
elif [[ -f /forcefsck ]]; then
	echo
	ewarn "A full fsck will be forced on next startup"
fi

ups_kill_power

# Load the final script depending on how we are called
[[ -e /etc/init.d/"$1".sh ]] && source /etc/init.d/"$1".sh

# vim:ts=4
