update_seed:yes
#update_seed_command:"--usepkg --quiet --update --newuse --changed-deps --oneshot --deep --rebuild-if-new-rev sys-devel/gcc --rebuild-if-new-rev dev-libs/mpfr --rebuild-if-new-rev dev-libs/mpc --rebuild-if-new-rev dev-libs/gmp --rebuild-if-new-rev sys-libs/glibc --rebuild-if-new-rev app-arch/lbzip2 --rebuild-if-new-rev sys-devel/libtool --rebuild-if-new-rev dev-lang/perl"
#update_seed_command:"--deep --update --newuse --changed-use --changed-deps --usepkg=y --buildpkg=n @system"
update_seed_command:"--quiet --update --deep --newuse --complete-graph --changed-use --rebuild-if-new-ver gcc openssh openssl perl
