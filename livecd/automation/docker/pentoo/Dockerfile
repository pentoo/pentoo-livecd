FROM scratch AS portage
ADD portage_and_overlay.tar.xz /

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

# --security=insecure is only needed for go
RUN --mount=type=bind,from=portage,source=/var/db/repos,target=/var/db/repos \
  #only python -O and -OO use these
  export INSTALL_MASK="$(portageq envvar INSTALL_MASK) *.opt-1.pyc *.opt-2.pyc" && \
  sed -i 's#pentoo-in-a-container#pentoo-in-a-container -pentoo-full#' /etc/portage/make.conf && \
  #disable minimal
  sed -i 's# pentoo-minimal##' /etc/portage/make.conf && \
  #install libsndfile minimal to break circular deps
  USE=minimal FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --rebuilt-binaries=n --jobs=$(nproc) --load-average=$(nproc) --deep --newuse media-libs/libsndfile && \
  #install pentoo/pentoo
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --rebuilt-binaries=n --jobs=$(nproc) --load-average=$(nproc) --deep --newuse pentoo/pentoo && \
  #deselect pentoo-core as pentoo/pentoo deps on it
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --deselect=y pentoo/pentoo-core && \
  #ensure we are up to date (should be a no-op)
  #FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --deep --update --newuse @world && \
  #minimize things not needed to run
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --jobs=$(nproc) --load-average=$(nproc) --depclean --with-bdeps=n && \
  #double check nothing is broken
  FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox" emerge --getbinpkg=y --buildpkg=n --rebuilt-binaries=n --jobs=$(nproc) --load-average=$(nproc) @preserved-rebuild && \
  #cleanup
  eselect news read && \
  rm -rf /var/cache/{binpkgs,distfiles,edb/binhost,edb/dep}/* /run/* /tmp/* /usr/lib/debug && \
  DISTDIR="$(portageq envvar DISTDIR)" && \
  if [ -d "${DISTDIR}" ]; then rm -rf "${DISTDIR:?}"/* ; fi && \
  PKGDIR="$(portageq envvar PKGDIR)" && \
  if [ -d "${PKGDIR}" ]; then rm -rf "${PKGDIR:?}"/* ; fi

CMD ["/bin/bash"]
