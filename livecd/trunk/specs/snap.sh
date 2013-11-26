#!/bin/bash

set -e

sed "s#$(awk '/snapshot:/ {print $3}' /usr/src/pentoo/livecd/trunk/specs/build_spec.sh)#$(date "+%Y%m%d")#" /usr/src/pentoo/livecd/trunk/specs/build_spec.sh > /tmp/build_spec.sh
catalyst -s $(date "+%Y%m%d")
mv /tmp/build_spec.sh /usr/src/pentoo/livecd/trunk/specs/build_spec.sh
