#!/bin/sh

set -e

DISTRO=pentoo

CI_REGISTRY_IMAGE=pentoolinux
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_VERSION=$(date -u +"%Y-%m-%d")

IMAGE=${DISTRO}-gui
VERSION=${BUILD_VERSION}

docker build --pull -t "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    --build-arg VERSION="${VERSION}" \
    --progress=plain \
    .

docker rm -f "${IMAGE}-ci" > /dev/null 2>&1 || true
# no --rm: a container that dies early has to keep its state and logs for the else branch
docker run -d --name "${IMAGE}-ci" ${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}
trap 'docker rm -f "${IMAGE}-ci" > /dev/null 2>&1 || true' EXIT
sleep 20
docker cp gui-checker "${IMAGE}-ci":/root/
sleep 40
if docker exec "${IMAGE}-ci" /root/gui-checker excessive; then
  docker stop "${IMAGE}-ci"
  docker tag "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}" "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
  docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:${VERSION}"
  #this seems required to update the "latest" tag upstream
  docker push "${CI_REGISTRY_IMAGE}/${IMAGE}:latest"
else
  docker inspect -f 'status {{.State.Status}}, exit code {{.State.ExitCode}}, OOM killed {{.State.OOMKilled}}, error "{{.State.Error}}"' "${IMAGE}-ci" || true
  docker logs --tail 200 "${IMAGE}-ci" || true
  exit 1
fi
