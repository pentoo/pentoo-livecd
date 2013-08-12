#!/bin/bash

set -e

sed "s#$(awk '/snapshot:/ {print $3}' build_spec.sh)#$(date "+%Y%m%d")#" build_spec.sh > /tmp/build_spec.sh
catalyst -s $(date "+%Y%m%d")
mv /tmp/build_spec.sh build_spec.sh
