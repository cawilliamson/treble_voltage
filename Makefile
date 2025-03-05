# Make sure Make stops if any command fails
.SHELLFLAGS := -e -c
.ONESHELL:

# Configuration variables
BUILD_DATE := $(shell date "+%Y%m%d")
APPLY_DEBUG_PATCHES ?= false
ROM_TAG ?= 15-qpr1
ROM_VERSION ?= 4.2
OUTPUT_DIR := $(PWD)/out
MAX_CPU_PERCENT ?= 100
MAX_MEM_PERCENT ?= 100

# Calculate resource limits
CPU_LIMIT := $(shell echo $$(( $(shell nproc --all) * $(MAX_CPU_PERCENT) / 100 )))
MEM_LIMIT := $(shell echo "$$(( $(shell free -m | awk '/^Mem:/{print $$2}') * $(MAX_MEM_PERCENT) / 100 ))m")

# Common container parameters
CONTAINER_RUN = podman run --rm --privileged \
	--cpus="$(CPU_LIMIT)" \
	--memory="$(MEM_LIMIT)" \
	--pids-limit=0 \
	-v "$(OUTPUT_DIR):/out:Z" \
	-v "$(PWD):/work/repo:Z" \
	-e BUILD_DATE="$(BUILD_DATE)" \
	-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)" \
	-e MAINTAINER="cawilliamson" \
	-e REPO_NAME="treble_voltage" \
	-e ROM_VERSION="$(ROM_VERSION)" \
	-e ROM_TAG="$(ROM_TAG)"

# Define all phony targets
.PHONY: all clean build-container \
	clone-rom-manifest copy-manifest-config sync-sources \
	apply-patches apply-debug-patches setup-tmp-dir generate-signing-keys \
	build-treble-app vndk-test-sepolicy \
	build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 \
	build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	adapt-vndklite-vanilla-arm64 adapt-vndklite-microg-arm64 adapt-vndklite-gapps-arm64 \
	adapt-vndklite-vanilla-a64 adapt-vndklite-microg-a64 adapt-vndklite-gapps-a64 \
	rename-images compress-images copy-to-web upload-to-github

# Default target
all: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	adapt-vndklite-vanilla-arm64 adapt-vndklite-microg-arm64 adapt-vndklite-gapps-arm64 \
	adapt-vndklite-vanilla-a64 adapt-vndklite-microg-a64 adapt-vndklite-gapps-a64 \
	rename-images compress-images

# Clean build directories
clean:
	rm -rf $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)

# Build container image
build-container:
	podman build -t voltage-gsi-builder -f Containerfile .

# Convenience targets for building all variants of a specific type
build-vanilla: build-vanilla-arm64 build-vanilla-a64
build-microg: build-microg-arm64 build-microg-a64
build-gapps: build-gapps-arm64 build-gapps-a64

# Build all arm64 variants
build-arm64: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64

# Build all arm32_binder64 variants
build-a64: build-vanilla-a64 build-microg-a64 build-gapps-a64

# Full build process
full-build: clone-rom-manifest copy-manifest-config sync-sources \
	apply-patches apply-debug-patches setup-tmp-dir generate-signing-keys \
	build-treble-app build-vanilla-arm64 vndk-test-sepolicy build-microg-arm64 build-gapps-arm64 \
	build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	adapt-vndklite-vanilla-arm64 adapt-vndklite-microg-arm64 adapt-vndklite-gapps-arm64 \
	adapt-vndklite-vanilla-a64 adapt-vndklite-microg-a64 adapt-vndklite-gapps-a64 \
	rename-images compress-images

# Include all step makefiles
include makefiles/*.mk
