#!/usr/bin/env bash

# This script allows you to build an individual image (but always builds both standard and vndklite variants.)
# The reason for this is that the vndklite variant is adapted from the standard image and adapting a build to
# vndklite is a very short process anyway.
# Arguments: architecture = [arm64/arm32_binder64], variant = [vanilla/microg/gapps]

# set all errors to immediately exit the script
set -e

# source functions
source includes/functions.sh

# Check if two arguments are provided
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <architecture> <variant>"
  exit 1
fi

# Assign arguments to variables
architecture="${1}"
variant="${2}"

# Validate variant and architecture
allowed_architectures=("arm64" "arm32_binder64")
allowed_variants=("vanilla" "microg" "gapps")
if [[ ! "${allowed_architectures[*]}" =~ $architecture ]]; then
  echo "Invalid architecture: $architecture. Allowed architectures are: ${allowed_architectures[*]}"
  exit 1
fi
if [[ ! "${allowed_variants[*]}" =~ $variant ]]; then
  echo "Invalid variant: $variant. Allowed variants are: ${allowed_variants[*]}"
  exit 1
fi

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

# Build standard image (if vndklite needed - )
buildStandardImage "$variant" "$architecture"

# Build vndklite image
buildVndkLiteImage "$variant" "$architecture"

# rename, compress, and upload all images
renameAndCompressImages
