#!/bin/bash

set -e
#clean old logs
find /catalyst/log -type f ! -name "summary.log*" -mtime +7 -delete
#clean old snapshots
find /catalyst/snapshots -type f -mtime +7 -delete
#sometimes snap.sh gets run by user and cron at the same time and badness results. prevent badness.
while ps aux | grep "[c]atalyst -s"
do
	echo snap.sh already running, sleeping 5 minutes
	sleep 5m
done
pushd /var/db/repos/pentoo
git pull
popd
emerge --sync || emerge --sync || exit 1
if [ $(($(date +%s) - $(stat -c %Y '/usr/portage/metadata/timestamp'))) -gt 259200 ]; then
  printf "More than 72 hours out of date, snap is failing!\n"
  exit 1
fi
catalyst -s latest -C options=keepwork compression_mode=pixz
xzcat /catalyst/snapshots/gentoo-latest.tar.xz | tar2sqfs /catalyst/snapshots/gentoo-latest.squashfs -j $(nproc) -f --compressor zstd -X level=19 -s
/usr/src/pentoo/pentoo-livecd/livecd/specs/make_modules.sh
