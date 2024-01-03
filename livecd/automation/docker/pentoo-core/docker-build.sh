#!/bin/sh

set -e

DISTRO=pentoo
CATALYST_PATH='/catalyst/builds/hardened'
if [ -f "${CATALYST_PATH}/stage4-amd64-docker-$(date +%Y).0.tar.xz" ]; then
  TARBALL="stage4-amd64-docker-$(date +%Y).0.tar.xz"
elif [ -f "${CATALYST_PATH}/stage4-amd64-docker-$(( "$(date +%Y)" - 1 )).0.tar.xz" ]; then
  TARBALL="stage4-amd64-docker-$(( "$(date +%Y)" - 1 )).0.tar.xz"
else
  printf "Unable to find a source path\n"
  exit 1
fi
cp "${CATALYST_PATH}/${TARBALL}" .

CI_REGISTRY_IMAGE=pentoolinux
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_VERSION=$(date -u +"%Y-%m-%d")

IMAGE=$DISTRO-core
VERSION=$BUILD_VERSION

docker build --no-cache -t "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" \
    --build-arg TARBALL=${TARBALL} \
    --build-arg BUILD_DATE=${BUILD_DATE} \
    --build-arg VERSION=${VERSION} \
    .

docker tag "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}"
#this seems required to update the "latest" tag upstream
docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
rm "${TARBALL}"
