#!/usr/bin/env bash

# This script builds all images sequentially.

# set all errors to immediately exit the script
set -e

# source functions
source includes/functions.sh

# setup environment
setupEnv

# clone sources
cloneAndPrepareSources

# apply patches
# NOTE: debug can be added to patchTypes list to get early adb logs but it completely breaks adb security so use sparingly!
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

# rename and compress all images
renameAndCompressImages

# upload all images to github (can be commented out to prevent this functionality)
uploadAsGitHubRelease
