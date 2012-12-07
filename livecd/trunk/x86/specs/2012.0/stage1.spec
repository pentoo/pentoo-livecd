subarch: i686
target: stage1
version_stamp: 2012.0
rel_type: hardened
profile: pentoo:pentoo/hardened/linux/x86
snapshot: 20121206
update_seed:yes
update_seed_command:"--update sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2"
source_subpath: hardened/stage3-i686-20121016
pkgcache_path: /catalyst/tmp/packages/x86-hardened
portage_overlay:/usr/src/pentoo/portage/trunk
cflags: -Os -march=i686 -mtune=generic -pipe -fomit-frame-pointer -ggdb
cxxflags: -Os -march=i686 -mtune=generic -pipe -fomit-frame-pointer -ggdb
