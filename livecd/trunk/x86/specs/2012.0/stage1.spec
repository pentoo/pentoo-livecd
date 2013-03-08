subarch: i686
target: stage1
version_stamp: 2013.0
rel_type: hardened
profile: --force pentoo:pentoo/hardened/linux/x86/bootstrap
snapshot: 20130308
update_seed:yes
update_seed_command:"--update sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2"
source_subpath: hardened/stage3-i686-hardened-20121213
pkgcache_path: /catalyst/tmp/packages/x86-hardened/bootstrap/stage1
portage_overlay:/usr/src/pentoo/portage/trunk
cflags: -Os -march=pentium-m -mtune=nocona -pipe -fomit-frame-pointer -ggdb
cxxflags: -Os -march=pentium-m -mtune=nocona -pipe -fomit-frame-pointer -ggdb
