#!/bin/bash

set -e

#sometimes snap.sh gets run by user and cron at the same time and badness results. prevent badness.
while ps aux | grep "[c]atalyst -s"
do
	echo snap.sh already running, sleeping 5 minutes
	sleep 5m
done
emerge --sync
sed "s#$(awk '/snapshot:/ {print $3}' /usr/src/pentoo/livecd/trunk/specs/build_spec.sh)#$(date "+%Y%m%d")#" /usr/src/pentoo/livecd/trunk/specs/build_spec.sh > /tmp/build_spec.sh
catalyst -s $(date "+%Y%m%d")
mv /tmp/build_spec.sh /usr/src/pentoo/livecd/trunk/specs/build_spec.sh
/usr/src/pentoo/livecd/trunk/specs/make_modules.sh
