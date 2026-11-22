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

# disable minimal (pentoo-core is default minimal)
#RUN sed -i 's# pentoo-minimal##' /etc/portage/make.conf

RUN --mount=type=bind,from=portage,source=/var/db/repos,target=/var/db/repos \
  #the image has no /etc/portage/gnupg and builds don't sync, so trust the binhost keys before emerging
  helper="$(portageq get_repo_path / pentoo)/pentoo/pentoo-core/files/pentoo-trust-helper" && \
  if [ -f "${helper}" ]; then bash "${helper}"; fi && \
  #only python -O and -OO use these
  export INSTALL_MASK="$(portageq envvar INSTALL_MASK) *.opt-1.pyc *.opt-2.pyc" && \
  goornogo="$(portageq match / 'dev-lang/go')" && \
  if [ -z "${goornogo}" ]; then \
    FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge -1 --usepkg=y dev-lang/go-bootstrap --jobs="$(nproc)" --load-average="$(nproc)" --quiet; \
    FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge -1 --usepkg=y dev-lang/go --jobs="$(nproc)" --load-average="$(nproc)" --quiet; \
    FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge -C dev-lang/go-bootstrap --quiet; \
  fi; \
  USE="-natspec" FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge -1 --usepkg=y  --jobs="$(nproc)" --load-average="$(nproc)" --verbose --quiet app-arch/unzip && \
  USE="-verify-sig" FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge -1 --usepkg=y --jobs="$(nproc)" --load-average="$(nproc)" --verbose --quiet dev-build/automake && \
  FEATURES="-getbinpkg -ipc-sandbox -network-sandbox -pid-sandbox" emerge --usepkg=y --with-bdeps=y --jobs="$(nproc)" --load-average="$(nproc)" --verbose --quiet @world && \
  eselect news read && \
  #nothing is installed in /var/empty, so with it as ROOT eclean-pkg --deep empties PKGDIR and every binrepos.conf location
  mkdir -p "$(portageq pkgdir)" && ROOT=/var/empty eclean-pkg --deep && \
  rm -rf /var/cache/{distfiles,edb/binhost,edb/dep}/* /etc/portage/gnupg /run/* /tmp/* /usr/lib/debug && \
  DISTDIR="$(portageq envvar DISTDIR)" && \
  if [ -d "${DISTDIR}" ]; then rm -rf "${DISTDIR:?}"/* ; fi
