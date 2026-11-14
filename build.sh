
set -ex
# usage: ./build.sh [image]
#   ubuntu:26.04                         -> ghcr.io/pharchive/phare_dep/ubuntu:26.04
#   ghcr.io/0xz/hpc-containers:cuda      -> ghcr.io/pharchive/phare_dep/ubuntu:26.04-cuda
FROM_IMAGE=${1:-"ubuntu:26.04"}
case "${FROM_IMAGE}" in
ghcr.io/0xz/hpc-containers:*) # MPI + parallel HDF5 on the vendor's ubuntu CUDA/ROCm image
    # --entrypoint: nvidia/cuda's prints a license banner on stdout
    VERSION_ID=$(docker run --rm --entrypoint sh "${FROM_IMAGE}" -c '. /etc/os-release && echo $VERSION_ID')
    [[ "${VERSION_ID}" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "bad VERSION_ID '${VERSION_ID}'" >&2; exit 1; }
    IMAGE="ghcr.io/pharchive/phare_dep/ubuntu:${VERSION_ID}-${FROM_IMAGE##*:}"
    ;;
*)
    IMAGE="ghcr.io/pharchive/phare_dep/${FROM_IMAGE}"
    FROM_IMAGE="docker.io/${FROM_IMAGE}"
    ;;
esac
docker build --build-arg FROM_IMAGE=$FROM_IMAGE -t ${IMAGE} .
echo "IMAGE=${IMAGE}" >> "${GITHUB_ENV:-/dev/null}"
