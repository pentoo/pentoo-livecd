FROM scratch

# Metadata params
ARG BUILD_DATE
ARG VERSION
ARG TARBALL

# https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.vendor='Pentoo Linux' \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.title="Pentoo Linux" \
      org.opencontainers.image.description="Official Pentoo Linux docker image" \
      org.opencontainers.image.url='https://www.pentoo.org' \
      org.opencontainers.image.authors="Zero_Chaos"

#here we pull in the rootfs from catalyst
ADD $TARBALL /
COPY files/fix_make_conf.sh /etc/profile.d/fix_make_conf.sh
COPY files/openrc_sysinit.sh /etc/profile.d/openrc_sysinit.sh
COPY files/gentoo.conf /etc/portage/repos.conf/
COPY files/pentoo.conf /etc/portage/repos.conf/
RUN mkdir -p /etc/portage/profile/package.use && \
  echo 'pentoo/pentoo-wireless -drivers' >> /etc/portage/profile/package.use/pentoo && \
  # mark news read
  eselect news read && \
  # make openrc work
  if ! grep -- '-containers' /etc/init.d/udev; then echo 'rc_keyword="-containers"' >> /etc/conf.d/udev; fi && \
  # openrc sysinit
  rc-update del udev && \
  rc-update del udev-trigger && \
  rc-update del kmod-static-nodes && \
  rm -rf /run/* /tmp/*

CMD ["/bin/bash", "-l"]
