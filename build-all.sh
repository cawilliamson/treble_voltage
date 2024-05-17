#!/usr/bin/env bash

#
### START: FUNCTIONS
#

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

  # create directories
  mkdir -p src/ tmp/
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
    done

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
    # define arrays for variants and architectures
    declare -a variants=("vanilla" "microg" "gapps")
    declare -a architectures=("arm64" "arm32_binder64")
    declare -a types=("standard" "vndklite")

    # loop through each variant and architecture
    for variant in "${variants[@]}"; do
      for arch in "${architectures[@]}"; do
        for type in "${types[@]}"; do
          if [[ "$type" == "standard" ]]; then
            mv -v "system_${variant}_${arch}.img" "${ROM_NAME}-${variant}-${arch}-ab-${ROM_VERSION}-${BUILD_DATE}-UNOFFICIAL.img"
          elif [[ "$type" == "vndklite" ]]; then
            mv -v "s_${variant}_${arch}_vndklite.img" "${ROM_NAME}-${variant}-${arch}-ab-vndklite-${ROM_VERSION}-${BUILD_DATE}-UNOFFICIAL.img"
          fi
        done
      done
    done

    # perform compression
    find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \;
  popd || exit
}

function uploadAsGitHubRelease() {
  pushd tmp/ || exit
    # create release
    gh release create "${ROM_VERSION}"-"${BUILD_DATE}" -d "${ROM_NAME}"-"${ROM_VERSION}"-"${BUILD_DATE}" -p

    # upload images
    gh release upload "${ROM_VERSION}"-"${BUILD_DATE}" --clobber -- *.img.xz
  popd || exit
}

#
### END: FUNCTIONS
#

#
### START: BUILD
#

# setup environment
setupEnv

# clone sources
cloneAndPrepareSources

# apply patches
patchTypes=("pre" "trebledroid" "personal")
for patchType in "${patchTypes[@]}"; do
  applyPatches "$patchType"
done

# stash gapps implementations
stashGappsImplementations

# build treble app
buildTrebleApp

# define arrays for variants and architectures
variants=("vanilla" "microg" "gapps")
architectures=("arm64" "arm32_binder64")

# loop through each variant and architecture for standard and vndklite images
for variant in "${variants[@]}"; do
  for arch in "${architectures[@]}"; do
    # build standard image
    buildStandardImage "$variant" "$arch"

    # run vndk sepolicy tests (only after the first build of each type)
    if [[ "$arch" == "arm64" && "$variant" == "vanilla" ]]; then
      runVndkSepolicyTests "$variant" "$arch"
    fi

    # build vndklite image
    buildVndkLiteImage "$variant" "$arch"
  done
done

# rename, compress, and upload all images
renameAndCompressImages
uploadAsGitHubRelease

#
### END: BUILD
#
