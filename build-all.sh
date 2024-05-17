#!/usr/bin/env bash

function setupEnv() {
  # setup environment vars
  AOSP_SOURCE_VERSION="ap1a"
  ROM_NAME="VoltageOS"
  ROM_VERSION="3.4"
  export ROM_NAME ROM_VERSION

  # setup git config
  git config --global user.email "androidbuild@localhost"
  git config --global user.name "androidbuild"
  git config --global color.ui false

  # create directories
  mkdir -p src/ tmp/

  # generate build timestamp and use for entire build
  date +%Y%m%d > tmp/cachedBuildDate.txt
}

function cloneAndPrepareSources() {
  mkdir -p src/
  pushd src/ || exit
    # init repo
    repo init -u https://github.com/VoltageOS/manifest.git -b 14 --depth=1 --git-lfs

    # copy local manifests
    mkdir -p .repo/local_manifests
    cp -v ../configs/*.xml .repo/local_manifests/

    # sync sources
    repo sync -c -j"$(nproc --all)" --force-sync --no-clone-bundle --no-tags

    # generate base rom config
    pushd device/phh/treble || exit
      cp -v ../../../../configs/voltage.mk .
      bash generate.sh voltage
    popd || exit
  popd || exit
}

function applyPatches() {
  pushd src/ || exit
    ../patches/apply.sh . "${1}"
  popd || exit
}

function stashGappsImplementations() {
  mv -v src/vendor/gapps tmp/
  mv -v src/vendor/partner_gms tmp/
}

function buildTrebleApp() {
  pushd src/treble_app/ || exit
    bash build.sh release
    cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
  popd || exit
}

function buildStandardImage() {
  # parse inputs
  targetVariant="${1}"
  targetArch="${2}"

  pushd src/ || exit
    # process variant config
    if [[ "${targetVariant}" == "vanilla" ]]; then
      # set variant code
      variantCode="v"
    elif [[ "${targetVariant}" == "microg" ]]; then
      # set variant code
      variantCode="m"

      # copy partner_gms to vendor
      cp -Rfv "../tmp/partner_gms" vendor/
    elif [[ "${targetVariant}" == "gapps" ]]; then
      # set variant code
      variantCode="g"

      # copy gapps to vendor
      cp -Rfv ../tmp/gapps vendor/
    fi

    # setup build environment
    # shellcheck disable=SC1091
    . build/envsetup.sh

    # lunch build
    lunch "treble_${targetArch}_b${variantCode}N-${AOSP_SOURCE_VERSION}-userdebug"

    # build system image
    make systemimage -j"$(nproc --all)"

    # move system image to tmp
    mv -v "out/target/product/tdgsi_${targetArch}_ab/system.img" "../tmp/system_${targetVariant}_${targetArch}.img"

    # post build cleanup
    if [[ "${1}" == "gapps" ]]; then
      rm -rf vendor/gapps
    elif [[ "${1}" == "microg" ]]; then
      rm -rf vendor/partner_gms
    fi
  popd || exit
}

function buildVndkLiteImage() {
  # parse inputs
  targetVariant="${1}"
  targetArch="${2}"

  # build vndk lite image
  pushd src/treble_adapter || exit
    cp -v "../../tmp/system_${targetVariant}_${targetArch}.img" "standard_system_${targetVariant}_${targetArch}.img"
    sudo bash lite-adapter.sh 64 "standard_system_${targetVariant}_${targetArch}.img"
    sudo mv s.img "../../tmp/s_${targetVariant}_${targetArch}_vndklite.img"
    sudo chown "$(whoami):$(id | awk -F'[()]' '{ print $2 }')" "../../tmp/s_${targetVariant}_${targetArch}_vndklite.img"
  popd || exit
}

function runVndkSepolicyTests() {
  pushd src/ || exit
    # parse inputs
    targetVariant="${1}"
    targetArch="${2}"

    # determine variant code
    if [[ "${targetVariant}" == "vanilla" ]]; then
      variantCode="v"
    elif [[ "${targetVariant}" == "microg" ]]; then
      variantCode="m"
    elif [[ "${targetVariant}" == "gapps" ]]; then
      variantCode="g"
    fi

    # setup build environment
    # shellcheck disable=SC1091
    . build/envsetup.sh

    # lunch build
    lunch "treble_${targetArch}_b${variantCode}N-${AOSP_SOURCE_VERSION}-userdebug"

    # run vndk sepolicy tests
    make vndk-test-sepolicy -j"$(nproc --all)"
  popd || exit
}

function renameAndCompressImages() {
  pushd tmp/ || exit
    # determine build date
    buildDate=$(cat cachedBuildDate.txt)

    # arm64 - standard
    mv -v system_vanilla_arm64.img "${ROM_NAME}"-vanilla-arm64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v system_microg_arm64.img "${ROM_NAME}"-microg-arm64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v system_gapps_arm64.img "${ROM_NAME}"-gapps-arm64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img

    # arm32_binder64 - standard
    mv -v system_vanilla_arm32_binder64.img "${ROM_NAME}"-vanilla-arm32_binder64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v system_microg_arm32_binder64.img "${ROM_NAME}"-microg-arm32_binder64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v system_gapps_arm32_binder64.img "${ROM_NAME}"-gapps-arm32_binder64-ab-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img

    # arm64 - vndklite
    mv -v s_vanilla_arm64_vndklite.img "${ROM_NAME}"-vanilla-arm64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v s_microg_arm64_vndklite.img "${ROM_NAME}"-microg-arm64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v s_gapps_arm64_vndklite.img "${ROM_NAME}"-gapps-arm64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img

    # arm32_binder64 - vndklite
    mv -v s_vanilla_arm32_binder64_vndklite.img "${ROM_NAME}"-vanilla-arm32_binder64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v s_microg_arm32_binder64_vndklite.img "${ROM_NAME}"-microg-arm32_binder64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img
    mv -v s_gapps_arm32_binder64_vndklite.img "${ROM_NAME}"-gapps-arm32_binder64-ab-vndklite-"${ROM_VERSION}"-"${buildDate}"-UNOFFICIAL.img

    # perform compression
    find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \;
  popd || exit
}

function uploadAsGitHubRelease() {
  pushd tmp/ || exit
    # determine build date
    buildDate=$(cat cachedBuildDate.txt)

    # create release
    gh release create "${ROM_VERSION}"-"${buildDate}" -d "${ROM_NAME}"-"${ROM_VERSION}"-"${buildDate}" -p

    # upload images
    gh release upload "${ROM_VERSION}"-"${buildDate}" --clobber -- *.img.xz
  popd || exit
}

# setup environment
setupEnv

# clone sources
cloneAndPrepareSources

# apply prepatches
applyPatches pre

# apply trebledroid patches
applyPatches trebledroid

# apply personal patches
applyPatches personal

# stash gapps implementations
stashGappsImplementations

# build treble app
buildTrebleApp

### build standard vanilla arm64 image
buildStandardImage "vanilla" "arm64"

# run vndk sepolicy tests (after first build)
runVndkSepolicyTests "vanilla" "arm64"

### build standard microg arm64 image
buildStandardImage "microg" "arm64"

### build standard gapps arm64 image
buildStandardImage "gapps" "arm64"

### build standard vanilla arm32_binder64 image
buildStandardImage "vanilla" "arm32_binder64"

### build standard microg arm32_binder64 image
buildStandardImage "microg" "arm32_binder64"

### build standard gapps arm32_binder64 image
buildStandardImage "gapps" "arm32_binder64"

### build vndklite vanilla arm64 image
buildVndkLiteImage "vanilla" "arm64"

### build vndklite microg arm64 image
buildVndkLiteImage "microg" "arm64"

### build vndklite gapps arm64 image
buildVndkLiteImage "gapps" "arm64"

### build vndklite vanilla arm32_binder64 image
buildVndkLiteImage "vanilla" "arm32_binder64"

### build vndklite microg arm32_binder64 image
buildVndkLiteImage "microg" "arm32_binder64"

### build vndklite gapps arm32_binder64 image
buildVndkLiteImage "gapps" "arm32_binder64"

### rename and compress all images
renameAndCompressImages

### upload as github release
uploadAsGitHubRelease
