#!/usr/bin/env bash

# This script builds all images sequentially.

# set all errors to immediately exit the script
set -e

# source functions
# shellcheck disable=SC1091
source includes/functions.sh

# setup environment
setupEnv

# clone sources
cloneSources

# apply patches
# NOTE: debug can be added to patchTypes list to get early adb logs but it completely breaks adb security so use sparingly!
patchTypes=("pre" "trebledroid" "personal")
for patchType in "${patchTypes[@]}"; do
  applyPatches "${patchType}"
done

# prepare sources
prepareSources

# stash gapps implementations
stashGappsImplementations

# build treble app
buildTrebleApp

# define arrays for variants and architectures
architectures=("arm64" "arm32_binder64")
variants=("vanilla" "microg" "gapps")

# loop through each variant and architecture for standard and vndklite images
for arch in "${architectures[@]}"; do
  for variant in "${variants[@]}"; do
    # build standard image
    buildStandardImage "${arch}" "${variant}"

    # run vndk sepolicy tests (only after the first build)
    if [[ "${arch}" == "arm64" && "${variant}" == "vanilla" ]]; then
      runVndkSepolicyTests "${arch}" "${variant}"
    fi

    # build vndklite image
    buildVndkLiteImage "${arch}" "${variant}"
  done
done

# rename and compress all images
renameAndCompressImages

# upload all images to github (can be commented out to prevent this functionality)
uploadAsGitHubRelease
