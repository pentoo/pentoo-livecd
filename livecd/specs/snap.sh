#!/bin/bash

set -e
find /catalyst/log -type f ! -name "summary.log*" -mtime +7 -delete
#sometimes snap.sh gets run by user and cron at the same time and badness results. prevent badness.
while ps aux | grep "[c]atalyst -s"
do
	echo snap.sh already running, sleeping 5 minutes
	sleep 5m
done
emerge --sync || exit 1
sed "s#$(awk '/snapshot:/ {print $3}' /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh)#$(date "+%Y%m%d").tar.xz#" /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh > /tmp/build_spec.sh
catalyst -s $(date "+%Y%m%d") -C options=keepwork compression_mode=pixz_x
mv /tmp/build_spec.sh /usr/src/pentoo/pentoo-livecd/livecd/specs/build_spec.sh
/usr/src/pentoo/pentoo-livecd/livecd/specs/make_modules.sh
