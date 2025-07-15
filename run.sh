#!/usr/bin/env bash

set -ex

apt-get update
apt-get install -y git make cmake libopenmpi-dev libhdf5-openmpi-dev g++ ninja-build \
                   ccache python3-dev python3-pip gfortran python3-venv gfortran

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
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_SAMRAI_TESTS=OFF -DCMAKE_BUILD_TYPE=Release
    make -j2
    make install
    cd ../..
    rm -rf samrai
)

rm -rf phare
apt-get autoclean

echo ". $PWD/.venv/bin/activate" >> ~/.bashrc
