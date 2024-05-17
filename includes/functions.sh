#!/usr/bin/env bash

function setupEnv() {
  # setup environment vars
  AOSP_SOURCE_VERSION="ap1a"
  BUILD_DATE=$(date +%Y%m%d)
  ROM_NAME="VoltageOS"
  ROM_VERSION="3.4"
  export ROM_NAME ROM_VERSION

  # setup git config
  git config --global user.email "androidbuild@localhost"
  git config --global user.name "androidbuild"
  git config --global color.ui false

  # clean out and tmp directories
  rm -rf out/ tmp/

  # create directories
  mkdir -p out/ src/ tmp/
}

function cloneAndPrepareSources() {
  mkdir -p src/
  pushd src/ || exit
    # init repo
    repo init -u https://github.com/VoltageOS/manifest.git -b 14 --depth=1 --git-lfs

    # copy local manifests
    mkdir -p .repo/local_manifests
    cp -v ../configs/*.xml .repo/local_manifests/

    # sync sources with retry logic, retry indefinitely with 1 minute delay
    until repo sync -c -j"$(nproc --all)" --force-sync --no-clone-bundle --no-tags; do
      echo "Repo sync failed, retrying in 1min..."
      sleep 60
    done || true # <-- workaround needed to allow retry to work without "set -e" causing script exit.

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
  mv -v src/packages/apps/GmsCompat tmp/
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
  targetArch="${1}"
  targetVariant="${2}"

  pushd src/ || exit
    # process variant config
    if [[ "${targetVariant}" == "vanilla" ]]; then
      # set variant code
      variantCode="v"

      # copy gmscompat to apps
      cp -Rfv "../tmp/GmsCompat" packages/apps/
    elif [[ "${targetVariant}" == "microg" ]]; then
      # set variant code
      variantCode="M"

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
    if [[ "${targetVariant}" == "vanilla" ]]; then
      rm -rf packages/apps/GmsCompat
    elif [[ "${targetVariant}" == "gapps" ]]; then
      rm -rf vendor/gapps
    elif [[ "${targetVariant}" == "microg" ]]; then
      rm -rf vendor/partner_gms
    fi
  popd || exit
}

function buildVndkLiteImage() {
  # parse inputs
  targetArch="${1}"
  targetVariant="${2}"

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
    targetArch="${1}"
    targetVariant="${2}"

    # determine variant code
    if [[ "${targetVariant}" == "vanilla" ]]; then
      variantCode="v"
    elif [[ "${targetVariant}" == "microg" ]]; then
      variantCode="M"
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
    # define arrays for variants and architectures
    declare -a architectures=("arm64" "arm32_binder64")
    declare -a variants=("vanilla" "microg" "gapps")
    declare -a types=("standard" "vndklite")

    # loop through each arch and variant
    for arch in "${architectures[@]}"; do
      for variant in "${variants[@]}"; do
        for type in "${types[@]}"; do
          if [[ "$type" == "standard" ]]; then
            mv -v "system_${variant}_${arch}.img" ../out/"${ROM_NAME}-${variant}-${arch}-ab-${ROM_VERSION}-${BUILD_DATE}-UNOFFICIAL.img"
          elif [[ "$type" == "vndklite" ]]; then
            mv -v "s_${variant}_${arch}_vndklite.img" ../out/"${ROM_NAME}-${variant}-${arch}-ab-vndklite-${ROM_VERSION}-${BUILD_DATE}-UNOFFICIAL.img"
          fi
        done
      done
    done
  popd || exit

  pushd out/ || exit
    # perform compression
    find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \;
  popd || exit
}

function uploadAsGitHubRelease() {
  pushd out/ || exit
    # create release
    gh release create "${ROM_VERSION}"-"${BUILD_DATE}" -d "${ROM_NAME}"-"${ROM_VERSION}"-"${BUILD_DATE}" -p

    # upload images
    gh release upload "${ROM_VERSION}"-"${BUILD_DATE}" --clobber -- *.img.xz
  popd || exit
}
