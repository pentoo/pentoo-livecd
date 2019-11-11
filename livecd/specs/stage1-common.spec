update_seed:yes
update_seed_command:"--usepkg --quiet --update --newuse --changed-deps --oneshot --deep --changed-use --rebuild-if-new-rev sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2 sys-devel/libtool dev-lang/perl net-misc/openssh dev-libs/openssl sys-libs/readline sys-libs/ncurses"
#update_seed_command:"--deep --update --newuse --changed-use --changed-deps --usepkg=y --buildpkg=n @world"
#update_seed_command:"--quiet --update --deep --newuse --complete-graph --changed-use --rebuild-if-new-ver gcc openssh openssl perl ncurses bash
