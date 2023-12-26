#!/usr/bin/env bash

# Quick 'N dirty script to build gapps-free VoltageOS for arm64

repo init -u https://github.com/VoltageOS/manifest.git -b 14 --depth=1

git lfs install

mkdir -p .repo/local_manifests
cp manifest.xml .repo/local_manifests/

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
repo forall -c git lfs pull

./apply-patches.sh . trebledroid
./apply-patches.sh . ponces
./apply-patches.sh . personal

pushd device/phh/treble
bash generate.sh Voltage
popd

CCACHE_COMPRESS=1
CCACHE_MAXSIZE=50G
USE_CCACHE=1
export CCACHE_COMPRESS CCACHE_MAXSIZE USE_CCACHE

. build/envsetup.sh
ccache -M 50G -F 0
lunch treble_arm64_bvN-userdebug
make systemimage -j$(nproc --all)
