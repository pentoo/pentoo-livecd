FROM pentoolinux/pentoo-core

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
# --security=insecure is only needed for go
RUN sed -i 's#pentoo-in-a-container#pentoo-in-a-container -pentoo-full -drivers#' /etc/portage/make.conf && \
  #disable minimal
  sed -i 's# pentoo-minimal##' /etc/portage/make.conf && \
  #install libsndfile minimal to break circular deps
  USE=minimal FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --deep --update --newuse media-libs/libsndfile && \
  #install pentoo/pentoo
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --deep --update --newuse pentoo/pentoo && \
  #deselect pentoo-core as pentoo/pentoo deps on it
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --deselect=y pentoo/pentoo-core && \
  #ensure we are up to date (should be a no-op)
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --deep --update --newuse @world && \
  #minimize things not needed to run
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --depclean --with-bdeps=n && \
  #double check nothing is broken
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) @preserved-rebuild && \
  #cleanup
  eselect news read && \
  rm -rf /var/cache/{binpkgs,distfiles}/* /var/db/repos/*

CMD ["/bin/bash"]
