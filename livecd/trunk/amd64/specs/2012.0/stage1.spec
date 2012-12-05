subarch: amd64
target: stage1
version_stamp: 2012.0
rel_type: hardened
profile: pentoo:pentoo/hardened/linux/amd64
snapshot: 20121204
update_seed:"--update sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2"
source_subpath: hardened/stage3-amd64-hardened-20121013
cflags: -Os -mtune=nocona -pipe -ggdb
cxxflags: -Os -mtune=nocona -pipe -ggdb
pkgcache_path: /catalyst/tmp/packages/amd64-hardened
portage_overlay: /usr/src/pentoo/portage/trunk
