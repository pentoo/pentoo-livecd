update_seed:yes
update_seed_command:"--usepkg --quiet --update --newuse --changed-deps --oneshot --deep --changed-use --rebuild-if-new-rev sys-devel/gcc --rebuild-if-new-rev dev-libs/mpfr --rebuild-if-new-rev dev-libs/mpc --rebuild-if-new-rev dev-libs/gmp --rebuild-if-new-rev sys-libs/glibc --rebuild-if-new-rev app-arch/lbzip2 --rebuild-if-new-rev sys-devel/libtool --rebuild-if-new-rev dev-lang/perl net-misc/openssh dev-libs/openssl sys-libs/readline sys-libs/ncurses --jobs"
#update_seed_command:"--deep --update --newuse --changed-use --changed-deps --usepkg=y --buildpkg=n @world"
#update_seed_command:"--quiet --update --deep --newuse --complete-graph --changed-use --rebuild-if-new-ver gcc openssh openssl perl ncurses bash
