#!/bin/bash

catalyst -s `date "+%Y%m%d"`
sed -i "s#$(awk '/snapshot:/ {print $2}' livecd-stage1.spec)#$(date "+%Y%m%d")#" *.spec
sed -i "s#$(awk '/snapshot:/ {print $2}' ../../../x86/specs/2012.0/livecd-stage1.spec)#$(date "+%Y%m%d")#" ../../../x86/specs/2012.0/*.spec
