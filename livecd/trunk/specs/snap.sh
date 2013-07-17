#!/bin/bash

catalyst -s `date "+%Y%m%d"`
sed -i "s#$(awk '/snapshot:/ {print $3}' build_spec.sh)#$(date "+%Y%m%d")#" build_spec.sh
