
set -ex
BASE_URL="docker.io/"
FROM_IMAGE=${1:-"ubuntu:22.04"}
IMAGE="ghcr.io/pharchive/phare_dep/${FROM_IMAGE}"
FROM_IMAGE="${BASE_URL}${FROM_IMAGE}"
docker build --build-arg FROM_IMAGE=$FROM_IMAGE -t ${IMAGE} .
