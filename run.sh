#!/usr/bin/env bash

set -ex

cd / # the jobs source /.venv: the GPU vendor base images may set another WORKDIR

PKGS="git make cmake g++ ninja-build ccache python3-dev python3-pip python3-venv gfortran clang"
PKGS="${PKGS} curl sudo"
# hpc-containers bases have their own Open MPI (/opt/mpi) and parallel HDF5 (/opt/hdf5) on PATH
#  and HDF5_ROOT: the distro packages would shadow them
[ -x /opt/mpi/bin/mpicc ] || PKGS="${PKGS} libopenmpi-dev libhdf5-openmpi-dev"
# CUDA bases: Umpire (NUMA) RAJA and SAMRAI for CUDA, built with clang, see below
[ -x /usr/local/cuda/bin/nvcc ] && PKGS="${PKGS} libnuma-dev"

apt-get update
apt-get install -y ${PKGS}

git clone https://github.com/PHAREHUB/PHARE -b master --depth 1 --recursive --shallow-submodules phare

python3 -m venv .venv

. .venv/bin/activate

(
    cd phare
    python3 -m pip install -U pip
    python3 -m pip install -r requirements.txt
    mkdir build
    cd build
    cmake ..
)

( 
    cd phare/subprojects/samrai
    mkdir build
    cd build
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_SAMRAI_TESTS=OFF -DCMAKE_BUILD_TYPE=Release \
             -DENABLE_TIMERS=OFF -DENABLE_CHECK_ASSERTIONS=OFF \
             -DCMAKE_POLICY_VERSION_MINIMUM=3.5 # TORM after https://github.com/LLNL/SAMRAI/issues/266
    make -j2
    make install
    cd ../..
    rm -rf samrai
)

# CUDA bases: Umpire, RAJA, then SAMRAI on both, from the mkn-nix/llnl.* phare branches
#  clang only, no nvcc. Into /mkn/r/llnl/<lib>/phare, where PHARE's CI and tools look for them
#  CUDA_ARCH: sm_90, the simulated H100 of the hpc-containers cuda image
if [ -x /usr/local/cuda/bin/nvcc ]; then
    LLNL=/mkn/r/llnl
    for r in umpire raja samrai; do # in order, SAMRAI needs both
        git clone --depth 1 -b phare https://github.com/mkn-nix/llnl.$r ${LLNL}/$r/phare
        # the scripts build -march=native: the image runs on whatever CPU pulls it
        sed -i 's/-march=native -mtune=native/-march=x86-64-v3/' ${LLNL}/$r/phare/mkn.sh
        (cd ${LLNL}/$r/phare && THREADS=$(nproc) CUDA_ARCH=sm_90 CMAKE_POLICY_VERSION_MINIMUM=3.5 \
            CUDA_HOME=$(readlink -f /usr/local/cuda) LLNL=${LLNL} bash mkn.sh)
        rm -rf ${LLNL}/$r/phare/$r # sources and build dir, the install is include/ lib/ share/
    done
fi

rm -rf phare
apt-get autoclean

echo ". $PWD/.venv/bin/activate" >> ~/.bashrc
