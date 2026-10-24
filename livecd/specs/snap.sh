#!/bin/bash

set -e
#clean old logs
find /catalyst/log -type f ! -name "summary.log*" -mtime +7 -delete
#clean old snapshots
#find /catalyst/snapshots -type f -mtime +7 -delete
#sometimes snap.sh gets run by user and cron at the same time and badness results. prevent badness.
while ps aux | grep "[c]atalyst --snapshot"
do
	echo snap.sh already running, sleeping 5 minutes
	sleep 1m
done
pushd /var/db/repos/pentoo
git pull
popd
chown -R portage:portage "$(portageq get_repo_path / gentoo)"
chown -R portage:portage "$(portageq get_repo_path / pentoo)"
#if [ $(($(date +%s) - $(stat -c %Y '/usr/portage/metadata/timestamp'))) -gt 259200 ]; then
#  printf "More than 72 hours out of date, snap is failing!\n"
#  exit 1
#fi
rm -rf /var/tmp/catalyst/snapshots/*
catalyst --snapshot stable
cd /var/tmp/catalyst/repos/gentoo.git
if [ "$(git branch -v | grep -v stable | wc -l)" -gt "0" ]; then
  printf "Something corrupted /var/tmp/catalyst/snapshots/gentoo.git\n"
  exit 1
fi
#cd /var/tmp/catalyst/snapshots/
#wget https://distfiles.gentoo.org/snapshots/squashfs/gentoo-current.xz.sqfs
mv /var/tmp/catalyst/snapshots/gentoo-*.sqfs /var/tmp/catalyst/snapshots/gentoo-latest.sqfs
/usr/src/pentoo/pentoo-livecd/livecd/specs/make_modules.sh
chown -R portage:portage "$(portageq get_repo_path / gentoo)"
chown -R portage:portage "$(portageq get_repo_path / pentoo)"
#the trees the binpkgs are built from, read by rfctf-container's make_gentoo_cache.sh
gentoo_commit="$(git -C /var/tmp/catalyst/repos/gentoo.git rev-parse stable)"
gentoo_time="$(git -C /var/tmp/catalyst/repos/gentoo.git log -1 --format=%ct stable)"
pentoo_commit="$(git -C /var/db/repos/pentoo rev-parse HEAD)"
tree="$(mktemp)"
printf 'PUBLISHED: %s\nGENTOO_MIRROR_COMMIT: %s\nGENTOO_MIRROR_COMMIT_TIME: %s\nPENTOO_COMMIT: %s\n' \
  "$(date +%s)" "${gentoo_commit}" "${gentoo_time}" "${pentoo_commit}" > "${tree}"
chmod 644 "${tree}"
mv "${tree}" /catalyst/packages/local_mirror/TREE
