#!/usr/bin/env bash

set -ex

cd / # the jobs source /.venv: the GPU vendor base images may set another WORKDIR

PKGS="git make cmake g++ ninja-build ccache python3-dev python3-pip python3-venv gfortran clang"
PKGS="${PKGS} curl sudo"
# hpc-containers bases have their own Open MPI (/opt/mpi) and parallel HDF5 (/opt/hdf5) on PATH
#  and HDF5_ROOT: the distro packages would shadow them
[ -x /opt/mpi/bin/mpicc ] || PKGS="${PKGS} libopenmpi-dev libhdf5-openmpi-dev"
# CUDA bases: Umpire (NUMA) RAJA and SAMRAI for CUDA, built with clang, see below
#  clang-22: clang 21 (26.04 default) can't parse CUDA 13 headers (texture_fetch_functions.h removed)
[ -x /usr/local/cuda/bin/nvcc ] && PKGS="${PKGS} libnuma-dev clang-22"

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

# CUDA bases: Umpire, RAJA, then SAMRAI on both, built by the mkn-nix/llnl.* phare branch scripts
#  clang only, no nvcc. Each script installs into its own clone dir: /opt/llnl/<lib>/{include,lib,share}
#  CUDA_ARCH: sm_90, the simulated H100 of the hpc-containers cuda image
if [ -x /usr/local/cuda/bin/nvcc ]; then
    # the scripts call plain clang/clang++: /usr/local/bin is ahead of /usr/bin on PATH
    ln -sf /usr/bin/clang-22 /usr/local/bin/clang
    ln -sf /usr/bin/clang++-22 /usr/local/bin/clang++
    LLNL=/opt/llnl
    for r in umpire raja samrai; do # in order, SAMRAI needs both
        git clone --depth 1 -b phare https://github.com/mkn-nix/llnl.$r ${LLNL}/$r
        # the scripts build -march=native: the image runs on whatever CPU pulls it
        sed -i 's/-march=native -mtune=native/-march=x86-64-v3/' ${LLNL}/$r/mkn.sh
        (cd ${LLNL}/$r && THREADS=$(nproc) CUDA_ARCH=sm_90 CMAKE_POLICY_VERSION_MINIMUM=3.5 \
            CUDA_HOME=$(readlink -f /usr/local/cuda) UMPIRE_DIR=${LLNL}/umpire RAJA_DIR=${LLNL}/raja bash mkn.sh)
        # the scripts end "make && make install; cd .. && rm -rf build": a failed make still exits 0
        #  so look for the package config: lib/cmake/<pkg>/ (umpire, raja) or share/SAMRAI/cmake/
        [ -n "$(find ${LLNL}/$r/lib ${LLNL}/$r/share -name '*[Cc]onfig.cmake' -print -quit 2>/dev/null)" ] \
            || { echo "$r: no install in ${LLNL}/$r" >&2; exit 1; }
        rm -rf ${LLNL}/$r/$r ${LLNL}/$r/.git # sources and build dir, the install is include/ lib/ share/
    done
fi

rm -rf phare
apt-get autoclean

echo ". $PWD/.venv/bin/activate" >> ~/.bashrc
