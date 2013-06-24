#!/bin/bash

catalyst -s `date "+%Y%m%d"`
sed -i "s#$(awk '/snapshot:/ {print $2}' full-common.spec)#$(date "+%Y%m%d")#" *.spec
