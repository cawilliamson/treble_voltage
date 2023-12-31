#!/usr/bin/env bash

# initialize repo
repo init -u https://github.com/VoltageOS/manifest.git -b 14 --depth=1

# copy manifest file
mkdir -p .repo/local_manifests
cp manifest.xml .repo/local_manifests/

# setup git-lfs
git lfs install

# sync all necessary repos
repo sync -c -j"$(nproc --all)" --force-sync --no-clone-bundle --no-tags

# sync all git-lfs files
repo forall -c git lfs pull

# apply all necessary patches
./patches/apply.sh . trebledroid
./patches/apply.sh . ponces
./patches/apply.sh . personal
./patches/apply.sh . graphene

# generate basic device config
pushd device/phh/treble || exit
  bash generate.sh Voltage
popd || exit

# setup ccache
CCACHE_COMPRESS=1
CCACHE_MAXSIZE=50G
USE_CCACHE=1
export CCACHE_COMPRESS CCACHE_MAXSIZE USE_CCACHE
ccache -M 50G -F 0

# setup build environment
# shellcheck source=/dev/null
. build/envsetup.sh
lunch treble_arm64_bvN-userdebug

# build system image
make systemimage -j"$(nproc --all)"
