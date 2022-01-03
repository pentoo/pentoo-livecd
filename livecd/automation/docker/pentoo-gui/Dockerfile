FROM pentoolinux/pentoo

# Metadata params
ARG BUILD_DATE
ARG VERSION

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.vendor='Pentoo Linux' \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.title="Pentoo Linux" \
      org.opencontainers.image.description="Official Pentoo Linux docker image" \
      org.opencontainers.image.url='https://www.pentoo.org' \
      org.opencontainers.image.authors="Zero_Chaos"

ADD portage_and_overlay.tar.xz /
RUN FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) www-apps/novnc x11-misc/x11vnc && \
  #ensure we are up to date (should be a no-op)
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --deep --update --newuse @world && \
  #minimize things not needed to run
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --depclean --with-bdeps=n && \
  #double check nothing is broken
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) @preserved-rebuild && \
  #cleanup
  eselect news read && \
  rm -rf /var/cache/{binpkgs,distfiles}/* /var/db/repos/*
RUN \
  # configure the gui to be nicer
  # magic to autohide panel 2
  magic_number=$(($(sed -n '/<value type="int" value="14"\/>/=' /etc/xdg/xfce4/panel/default.xml)+1)) && \
  sed -i "${magic_number} a\    <property name=\"autohide-behavior\" type=\"uint\" value=\"1\"/>" /etc/xdg/xfce4/panel/default.xml && \
  # set wallpaper
  mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml/ && \
  cp /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml /root/.config/xfce4/xfconf/xfce-perchannel-xml/
RUN \
  # make sure the menus exist
  genmenu.py -x


EXPOSE 8080/tcp
ENV DISPLAY=:0

WORKDIR /root/
COPY supervisord-pentoo.conf /etc/supervisord/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord/supervisord.conf", "--pidfile", "/run/supervisord.pid"]
ENTRYPOINT []
