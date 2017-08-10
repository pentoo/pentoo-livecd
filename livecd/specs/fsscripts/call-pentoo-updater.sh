#!/bin/sh
source /tmp/envscript

#emerge --usepkg=n --buildpkg=y --quiet --update --newuse --rebuild-if-new-ver sys-devel/gcc dev-libs/mpfr dev-libs/mpc dev-libs/gmp sys-libs/glibc app-arch/lbzip2 sys-devel/libtool
#emerge -C "dev-ruby/*" www-apps/beef www-servers/thin virtual/rubygems app-text/docbook-xsl-stylesheets net-libs/webkit-gtk dev-lang/ruby
#emerge -C "app-text/docbook*" app-text/enchant app-text/qpdf dev-qt/qtdeclarative dev-qt/qtopengl
#emerge -C dev-libs/boost dev-util/boost-build app-misc/hivex

#gcc_target="x86_64-pc-linux-gnu-5.4.0"
#if [ "$(gcc-config -c)" != "${gcc_target}" ]; then
#  if gcc-config -l | grep -q "${gcc_target}"; then
#    gcc-config "${gcc_target}"
#    . /etc/profile
#    revdep-rebuild --library 'libstdc++.so.6' -- --buildpkg=y --usepkg=n --exclude gcc
#  fi
#fi

/usr/local/portage/scripts/pentoo-updater.sh
