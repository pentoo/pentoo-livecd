#if [[ $CATEGORY/$PN == www-client/chromium ]]; then
#  export CFLAGS=${CFLAGS/-Os/-O2/}
#fi
if [[ $CATEGORY/$PN == x11-base/xorg-server ]]; then export CFLAGS=${CFLAGS/-Os/-O2}; fi
