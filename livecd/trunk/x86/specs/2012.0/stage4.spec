subarch: i686
target: stage4
version_stamp: 2012.0
rel_type: hardened
profile: pentoo:pentoo/hardened/linux/x86
snapshot: 20121204
source_subpath: hardened/stage3-i686-2012.0
pkgcache_path: /catalyst/tmp/packages/x86-hardened
portage_overlay: /usr/src/pentoo/portage/trunk
stage4/use: python opengl
stage4/packages: dev-lang/python:2.7
stage4/fsscript: /usr/src/pentoo/livecd/trunk/amd64/specs/2012.0/fsscript-stage4.sh
cflags: -Os -march=i686 -mtune=generic -pipe -fomit-frame-pointer -ggdb
cxxflags: -Os -march=i686 -mtune=generic -pipe -fomit-frame-pointer -ggdb

