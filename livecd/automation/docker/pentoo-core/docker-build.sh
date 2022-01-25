#!/bin/sh

set -e

DISTRO=pentoo
TARBALL=stage4-amd64-docker-2022.0.tar.xz
cp "/catalyst/builds/hardened/${TARBALL}" .

CI_REGISTRY_IMAGE=pentoolinux
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_VERSION=$(date -u +"%Y-%m-%d")

IMAGE=$DISTRO-core
VERSION=$BUILD_VERSION

docker build -t "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" \
    --build-arg TARBALL=${TARBALL} \
    --build-arg BUILD_DATE=${BUILD_DATE} \
    --build-arg VERSION=${VERSION} \
    .

docker tag "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}"
#this seems required to update the "latest" tag upstream
docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
rm "${TARBALL}"
