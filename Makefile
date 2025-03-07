# Make sure Make stops if any command fails
.SHELLFLAGS := -e -c
.ONESHELL:

# Define a function to print section headers
define print_section
	@echo ""
	@echo "#######################"
	@echo "# $(1)"
	@echo "#######################"
	@echo ""
endef

# Configuration variables
BUILD_DATE := $(shell date "+%Y%m%d")
APPLY_DEBUG_PATCHES ?= false
ROM_TAG ?= 15-qpr1
ROM_VERSION ?= 4.2
MAX_CPU_PERCENT ?= 100
MAX_MEM_PERCENT ?= 100
CONTAINER_RUNTIME ?= podman

# Calculate resource limits
CPU_LIMIT := $(shell echo $$(( $(shell nproc --all) * $(MAX_CPU_PERCENT) / 100 )))
MEM_LIMIT := $(shell echo "$$(( $(shell free -m | awk '/^Mem:/{print $$2}') * $(MAX_MEM_PERCENT) / 100 ))m")

# Common container parameters
CONTAINER_RUN = $(CONTAINER_RUNTIME) run --rm --privileged \
	--cpus="$(CPU_LIMIT)" \
	--memory="$(MEM_LIMIT)" \
	--pids-limit=0 \
	-v "$(PWD):/repo:Z" \
	-e BUILD_DATE="$(BUILD_DATE)" \
	-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)" \
	-e ROM_VERSION="$(ROM_VERSION)" \
	-e ROM_TAG="$(ROM_TAG)"

# Define all phony targets
.PHONY: all all-images clean build-container create-folders \
	clone-rom-manifest copy-manifest-config sync-sources \
	apply-patches stash-gapps-variants generate-signing-keys \
	prepare-treble-config build-treble-app vndk-test-sepolicy \
	build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 \
	build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	rename-images compress-images

# Default target is now full-build
all: full-build

# Target for building all images without source preparation
all-images: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	rename-images compress-images

# Clean build directories
clean:
	rm -rfv out/ src/ tmp/

# Build container image
build-container:
	$(CONTAINER_RUNTIME) build -t voltage-gsi-builder -f Containerfile .

create-folders:
	mkdir -p out/ src/ tmp/

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
	apply-patches stash-gapps-variants generate-signing-keys \
	prepare-treble-config build-treble-app build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 \
	build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	vndk-test-sepolicy \
	rename-images compress-images

# Step 1: Clone ROM manifest
clone-rom-manifest: build-container create-folders
	$(call print_section,Clone ROM Manifest)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				repo init -u https://github.com/VoltageOS/manifest.git -b ${ROM_TAG} --depth=1 --git-lfs && \
			popd'

# Step 2: Copy manifest config
copy-manifest-config: build-container create-folders
	$(call print_section,Copy Manifest Config)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /repo/src/.repo/local_manifests && \
			cp -v /repo/configs/*.xml /repo/src/.repo/local_manifests/'

# Step 3: Perform full sources sync (with auto retry)
sync-sources: build-container create-folders
	$(call print_section,Sync Sources)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				until repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags; do \
					echo "Sync failed, retrying in 30 seconds..."; \
					sleep 30; \
				done && \
			popd'

# Step 4: Apply patches (including optional debug patches)
apply-patches: build-container create-folders
	$(call print_section,Apply Patches)
	$(CONTAINER_RUN) \
		-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)" \
		voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				/repo/patches/apply.sh . trebledroid && \
				/repo/patches/apply.sh . personal && \
				if [ "$$APPLY_DEBUG_PATCHES" = "true" ]; then \
					/repo/patches/apply.sh . debug; \
				fi && \
			popd'

# Step 5: Setup tmp directory and stash gapps variants
stash-gapps-variants: build-container create-folders
	$(call print_section,Stash GApps Variants)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mv -v /repo/src/vendor/gapps /repo/tmp/ && \
			mv -v /repo/src/vendor/partner_gms /repo/tmp/'

# Step 6: Generate signing keys
generate-signing-keys: build-container create-folders
	$(call print_section,Generate Signing Keys)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/vendor/voltage-priv/keys && \
				./keys.sh || true && \
			popd'

# Step 7: Prepare treble config (only needs to be run once)
prepare-treble-config: build-container create-folders
	$(call print_section,Prepare Treble Config)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src && \
				pushd device/phh/treble && \
					cp -fv /repo/configs/voltage-vanilla.mk voltage.mk && \
					bash generate.sh voltage && \
				popd && \
			popd'

# Step 8: Build treble app
build-treble-app: build-container create-folders prepare-treble-config
	$(call print_section,Build Treble App)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src && \
				pushd treble_app/ && \
					bash build.sh release && \
					cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk && \
				popd && \
			popd'

# Step 9: Helper function to build a specific GSI variant
define build_gsi_variant
	$(CONTAINER_RUN) \
	-e BUILD_TYPE="$(1)" \
	-e ARCH="$(2)" \
	voltage-gsi-builder \
	/bin/bash -e -c ' \
		pushd /repo/src && \
			if [ "$(1)" = "microg" ]; then \
				cp -Rfv /repo/tmp/partner_gms vendor/; \
			elif [ "$(1)" = "gapps" ]; then \
				cp -Rfv /repo/tmp/gapps vendor/; \
			fi && \
			. build/envsetup.sh && \
			lunch treble_$(2)_b$(3)N-ap4a-userdebug && \
			make systemimage -j$(CPU_LIMIT) && \
			if [ "$(2)" = "arm64" ]; then \
				mv -v out/target/product/tdgsi_arm64_ab/system.img /repo/tmp/system_$(1)_$(2).img; \
			else \
				mv -v out/target/product/tdgsi_a64_ab/system.img /repo/tmp/system_$(1)_$(2).img; \
			fi && \
			if [ "$(1)" = "microg" ]; then \
				rm -Rfv vendor/partner_gms; \
			elif [ "$(1)" = "gapps" ]; then \
				rm -Rfv vendor/gapps; \
			fi && \
		popd'
endef

# Build standard vanilla arm64 image
build-vanilla-arm64: build-container create-folders prepare-treble-config
	$(call print_section,Build Vanilla ARM64)
	$(call build_gsi_variant,vanilla,arm64,v)

# Build standard microg arm64 image
build-microg-arm64: build-container create-folders prepare-treble-config
	$(call print_section,Build MicroG ARM64)
	$(call build_gsi_variant,microg,arm64,m)

# Build standard gapps arm64 image
build-gapps-arm64: build-container create-folders prepare-treble-config
	$(call print_section,Build GApps ARM64)
	$(call build_gsi_variant,gapps,arm64,g)

# Build standard vanilla arm32_binder64 image
build-vanilla-a64: build-container create-folders prepare-treble-config
	$(call print_section,Build Vanilla A64)
	$(call build_gsi_variant,vanilla,a64,v)

# Build standard microg arm32_binder64 image
build-microg-a64: build-container create-folders prepare-treble-config
	$(call print_section,Build MicroG A64)
	$(call build_gsi_variant,microg,a64,m)

# Build standard gapps arm32_binder64 image
build-gapps-a64: build-container create-folders prepare-treble-config
	$(call print_section,Build GApps A64)
	$(call build_gsi_variant,gapps,a64,g)

# Step 10: Run vndk sepolicy tests
vndk-test-sepolicy: build-container create-folders
	$(call print_section,VNDK Test SEPolicy)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src && \
				. build/envsetup.sh && \
				lunch treble_arm64_bvN-ap4a-userdebug && \
				make vndk-test-sepolicy -j$(CPU_LIMIT) && \
			popd'

# Step 11: Rename image files
rename-images: build-container create-folders
	$(call print_section,Rename Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				if [ -f system_vanilla_arm64.img ]; then \
					mv -v system_vanilla_arm64.img "VoltageOS"-vanilla-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
				if [ -f system_microg_arm64.img ]; then \
					mv -v system_microg_arm64.img "VoltageOS"-microg-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
				if [ -f system_gapps_arm64.img ]; then \
					mv -v system_gapps_arm64.img "VoltageOS"-gapps-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
				if [ -f system_vanilla_a64.img ]; then \
					mv -v system_vanilla_a64.img "VoltageOS"-vanilla-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
				if [ -f system_microg_a64.img ]; then \
					mv -v system_microg_a64.img "VoltageOS"-microg-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
				if [ -f system_gapps_a64.img ]; then \
					mv -v system_gapps_a64.img "VoltageOS"-gapps-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img; \
				fi && \
			popd'

# Step 12: Compress all images with xz
compress-images: build-container create-folders
	$(call print_section,Compress Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				find . -maxdepth 1 -name "*.img" -exec xz -9 -T0 -v -z "{}" \; && \
				cp -fv *.img.xz /repo/out/ && \
			popd'
