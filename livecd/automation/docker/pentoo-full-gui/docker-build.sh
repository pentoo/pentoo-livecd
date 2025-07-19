#!/bin/sh

set -e

DISTRO=pentoo

CI_REGISTRY_IMAGE=pentoolinux
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_VERSION=$(date -u +"%Y-%m-%d")

IMAGE=${DISTRO}-full-gui
VERSION=${BUILD_VERSION}

docker build --pull -t "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg VERSION="${VERSION}" \
    .

docker run -d --rm --name "${IMAGE}-ci" ${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}
sleep 10
docker cp gui-checker "${IMAGE}-ci":/root/
sleep 30
if docker exec "${IMAGE}-ci" /root/gui-checker excessive; then
  docker stop "${IMAGE}-ci"
  docker tag "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
  docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}"
  #this seems required to update the "latest" tag upstream
  docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
else
  docker stop "${IMAGE}-ci"
fi
