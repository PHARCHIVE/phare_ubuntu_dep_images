
set -ex
# usage: ./build.sh [image]
#   ubuntu:26.04                         -> ghcr.io/pharchive/phare_dep/ubuntu:26.04
#   ghcr.io/0xz/hpc-containers:cuda      -> ghcr.io/pharchive/phare_dep/ubuntu:26.04-cuda
FROM_IMAGE=${1:-"ubuntu:26.04"}
case "${FROM_IMAGE}" in
ghcr.io/0xz/hpc-containers:*) # MPI + parallel HDF5 on the vendor's ubuntu CUDA/ROCm image
    VERSION_ID=$(docker run --rm "${FROM_IMAGE}" sh -c '. /etc/os-release && echo $VERSION_ID')
    IMAGE="ghcr.io/pharchive/phare_dep/ubuntu:${VERSION_ID}-${FROM_IMAGE##*:}"
    ;;
*)
    IMAGE="ghcr.io/pharchive/phare_dep/${FROM_IMAGE}"
    FROM_IMAGE="docker.io/${FROM_IMAGE}"
    ;;
esac
docker build --build-arg FROM_IMAGE=$FROM_IMAGE -t ${IMAGE} .
echo "IMAGE=${IMAGE}" >> "${GITHUB_ENV:-/dev/null}"
