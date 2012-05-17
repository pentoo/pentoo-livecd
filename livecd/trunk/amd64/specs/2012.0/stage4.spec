subarch: amd64
target: stage4
version_stamp: 2012.0
rel_type: default
profile: default/linux/amd64/10.0
snapshot: 20120515
source_subpath: default/stage3-amd64-2012.0
cflags: -Os -mtune=nocona -pipe
cxxflags: -Os -mtune=nocona -pipe
stage4/packages: dev-lang/python:2.7
stage4/fsscript: fsscript-stage4.sh
stage4/unmerge: >=dev-lang/python-3
