subarch: amd64
target: stage1
version_stamp: 2013.0
rel_type: hardened
profile: --force pentoo:pentoo/hardened/linux/amd64/bootstrap
snapshot: 20130222
update_seed:yes
update_seed_command:"--update sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2"
source_subpath: hardened/stage3-amd64-hardened-20130110
cflags: -Os -mtune=nocona -pipe -ggdb
cxxflags: -Os -mtune=nocona -pipe -ggdb
pkgcache_path: /catalyst/tmp/packages/amd64-hardened
portage_overlay: /usr/src/pentoo/portage/trunk
