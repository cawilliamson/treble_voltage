# Makefile for VoltageOS GSI builds
# Structured to match the GitHub pipeline with modular steps

.PHONY: all clean setup build-container \
	build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 \
	build-vanilla-a64 build-microg-a64 build-gapps-a64 \
	build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64 \
	build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64

# Configuration variables
DEBUG_PATCHES ?= false
ROM_NAME ?= VoltageOS
ROM_VERSION ?= 4.2
OUTPUT_DIR ?= $(PWD)/out
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
	-v "$(PWD):/repo:Z" \
	-e DEBUG_PATCHES="$(DEBUG_PATCHES)" \
	-e ROM_NAME="$(ROM_NAME)" \
	-e ROM_VERSION="$(ROM_VERSION)"

# Default target
all: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64

# Setup output directory
setup:
	mkdir -p $(OUTPUT_DIR)

# Build container image
build-container:
	podman build --no-cache -t voltage-gsi-builder -f Containerfile .

# Clean build directories
clean:
	rm -rf $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)


# Step 1: Clone ROM manifest
define CLONE_MANIFEST
	mkdir -p src/ && \
	cd src/ && \
	repo init -u https://github.com/VoltageOS/manifest.git -b 15-qpr1 --depth=1 --git-lfs
endef

# Step 2: Copy manifest config
define COPY_MANIFEST_CONFIG
	mkdir -p .repo/local_manifests && \
	cp -v /repo/configs/*.xml .repo/local_manifests/
endef

# Step 3: Perform full sources sync
define SYNC_SOURCES
	repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags
endef

# Step 4: Apply patches
define APPLY_PATCHES
	/repo/patches/apply.sh . trebledroid && \
	/repo/patches/apply.sh . personal
endef

# Step 5: Apply debug patches (conditional)
define APPLY_DEBUG_PATCHES
	if [ '$(DEBUG_PATCHES)' = 'true' ]; then \
		/repo/patches/apply.sh . debug \
	fi
endef

# Step 6: Setup tmp directory and stash gapps variants
define SETUP_TMP_DIR
	mkdir -p ../tmp/ && \
	echo $$(date +%Y%m%d) > ../tmp/cachedBuildDate.txt && \
	BUILD_DATE=$$(cat ../tmp/cachedBuildDate.txt) && \
	mv -v vendor/gapps ../tmp/ 2>/dev/null || echo 'vendor/gapps not found' && \
	mv -v vendor/partner_gms ../tmp/ 2>/dev/null || echo 'vendor/partner_gms not found'
endef

# Step 7: Generate signing keys
define GENERATE_KEYS
	. build/envsetup.sh && \
	pushd vendor/voltage-priv/keys && \
	./gen_keys && \
	popd
endef

# Step 8: Configure device
define CONFIGURE_DEVICE
	pushd device/phh/treble && \
	cp -fv /repo/configs/voltage-$(1).mk voltage.mk && \
	bash generate.sh voltage && \
	popd
endef

# Step 9: Build treble app (vanilla only)
define BUILD_TREBLE_APP
	. build/envsetup.sh && \
	pushd treble_app/ && \
	bash build.sh release && \
	cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk && \
	popd && \
	pushd device/phh/treble && \
	cp -v /repo/configs/voltage-vanilla.mk voltage.mk && \
	bash generate.sh voltage && \
	popd
endef

# Step 10: Copy vendor files (microg/gapps)
define COPY_VENDOR_FILES
	if [ "$(1)" = "microg" ]; then \
		cp -Rfv ../tmp/partner_gms vendor/ \
	elif [ "$(1)" = "gapps" ]; then \
		cp -Rfv ../tmp/gapps vendor/ \
	fi
endef

# Step 11: Build system image
define BUILD_SYSTEM_IMAGE
	. build/envsetup.sh && \
	lunch treble_$(1)_b$(2)N-ap1a-userdebug && \
	make systemimage -j$(CPU_LIMIT) && \
	if [ "$(1)" = "arm64" ]; then \
		mv -v out/target/product/tdgsi_arm64_ab/system.img ../tmp/system_$(3)_$(1).img \
	else \
		mv -v out/target/product/tdgsi_a64_ab/system.img ../tmp/system_$(3)_$(1).img \
	fi
endef

# Step 12: Run vndk sepolicy tests (vanilla only)
define RUN_SEPOLICY_TESTS
	make vndk-test-sepolicy -j$(CPU_LIMIT)
endef

# Step 13: Cleanup vendor files
define CLEANUP_VENDOR_FILES
	if [ "$(1)" = "microg" ]; then \
		rm -Rfv vendor/partner_gms \
	elif [ "$(1)" = "gapps" ]; then \
		rm -Rfv vendor/gapps \
	fi
endef

# Step 14: Prepare output
define PREPARE_OUTPUT
	cd ../tmp && \
	if [ "$(1)" = "arm64" ]; then \
		mv -v system_$(2)_$(1).img $(ROM_NAME)-$(2)-$(1)-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img \
	else \
		mv -v system_$(2)_$(1).img $(ROM_NAME)-$(2)-arm32_binder64-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img \
	fi && \
	find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \  && \
	cp -fv *.img.xz /out/ && \
	cp -v cachedBuildDate.txt /out/
endef

# Step 15: Setup for vndklite build using normal build output
define SETUP_VNDKLITE_WORKSPACE
	# Create tmp directory if it doesn't exist
	mkdir -p ../tmp/ && \
	# Copy normal build output from output directory
	cp -v /out/*.img.xz . 2>/dev/null || echo 'No images found' && \
	# Extract the compressed images
	find . -name '*.img.xz' -exec xz -d "{}" \  2>/dev/null || true && \
	# Get the build date from the normal build or create it if it doesn't exist
	BUILD_DATE=$$(cat /out/cachedBuildDate.txt 2>/dev/null || (echo $$(date +%Y%m%d) | tee ../tmp/cachedBuildDate.txt))
endef

# Step 16: Initialize repo for vndklite
define INIT_VNDKLITE_REPO
	mkdir -p src/ && cd src/ && \
	repo init -u https://github.com/VoltageOS/manifest.git -b 15-qpr1 --depth=1 --git-lfs && \
	mkdir -p .repo/local_manifests && \
	cp -v /repo/configs/*.xml .repo/local_manifests/ && \
	repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags --current-branch treble_adapter
endef

# Step 17: Process vndklite image using normal build output
define PROCESS_VNDKLITE_IMAGE
	cd src/treble_adapter && \
	# Copy the normal build image to use as input for vndklite conversion
	cp -v ../../$(ROM_NAME)-$(1)-$(if $(filter $(2),a64),arm32_binder64,$(2))-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img standard_system_$(1)_$(2).img && \
	# Run the lite-adapter script to convert the normal build to vndklite
	bash lite-adapter.sh $(if $(filter $(2),a64),32,64) standard_system_$(1)_$(2).img && \
	# Move the resulting vndklite image
	mv s.img ../../s_$(1)_$(2)_vndklite.img
endef

# Step 18: Rename and compress vndklite image for output
define RENAME_VNDKLITE_IMAGE
	# Rename the vndklite image to follow the naming convention
	mv -v s_$(1)_$(2)_vndklite.img $(ROM_NAME)-$(1)-$(if $(filter $(2),a64),arm32_binder64,$(2))-ab-vndklite-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img && \
	# Compress the image
	find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \  && \
	# Copy the compressed image to the output directory
	cp -fv *.img.xz /out/
endef

# Build standard GSI (vanilla/microg/gapps)
define BUILD_STANDARD_GSI
	mkdir -p $(OUTPUT_DIR)
	$(CONTAINER_RUN) \
		-e BUILD_TYPE="$(1)" \
		-e ARCH="$(2)" \
		voltage-gsi-builder \
		/bin/bash -c "cd /src && \
			mkdir -p src/ && cd src/ && \
			$(CLONE_MANIFEST) && \
			$(COPY_MANIFEST_CONFIG) && \
			$(SYNC_SOURCES) && \
			$(APPLY_PATCHES) && \
			$(APPLY_DEBUG_PATCHES) && \
			$(SETUP_TMP_DIR) && \
			$(GENERATE_KEYS) && \
			$(call CONFIGURE_DEVICE,$(1)) && \
			$(if $(filter $(1),vanilla),$(BUILD_TREBLE_APP),) && \
			$(call COPY_VENDOR_FILES,$(1)) && \
			$(call BUILD_SYSTEM_IMAGE,$(2),$(3),$(1)) && \
			$(if $(filter $(1),vanilla),$(RUN_SEPOLICY_TESTS),) && \
			$(call CLEANUP_VENDOR_FILES,$(1)) && \
			$(call PREPARE_OUTPUT,$(2),$(1))"
endef

# Build vndklite GSI (using normal build output)
define BUILD_VNDKLITE_GSI
	mkdir -p $(OUTPUT_DIR)
	# This target depends on the normal build target, ensuring the normal build is completed first
	# The normal build output is then used as input for the vndklite build
	$(CONTAINER_RUN) \
		-e BUILD_TYPE="vndklite-$(1)" \
		-e ARCH="$(2)" \
		voltage-gsi-builder \
		/bin/bash -c "cd /src && \
			$(SETUP_VNDKLITE_WORKSPACE) && \
			$(INIT_VNDKLITE_REPO) && \
			$(call PROCESS_VNDKLITE_IMAGE,$(1),$(2)) && \
			$(call RENAME_VNDKLITE_IMAGE,$(1),$(2))"
endef

# Build vanilla arm64 GSI
build-vanilla-arm64: setup build-container
	$(call BUILD_STANDARD_GSI,vanilla,arm64,v)

# Build microG arm64 GSI
build-microg-arm64: setup build-container
	$(call BUILD_STANDARD_GSI,microg,arm64,m)

# Build GApps arm64 GSI
build-gapps-arm64: setup build-container
	$(call BUILD_STANDARD_GSI,gapps,arm64,g)

# Build vanilla arm32_binder64 GSI
build-vanilla-a64: setup build-container
	$(call BUILD_STANDARD_GSI,vanilla,a64,v)

# Build microG arm32_binder64 GSI
build-microg-a64: setup build-container
	$(call BUILD_STANDARD_GSI,microg,a64,m)

# Build GApps arm32_binder64 GSI
build-gapps-a64: setup build-container
	$(call BUILD_STANDARD_GSI,gapps,a64,g)

# Build vndklite vanilla arm64 GSI (depends on normal vanilla arm64 build)
build-vndklite-vanilla-arm64: setup build-container build-vanilla-arm64
	# This target depends on build-vanilla-arm64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,vanilla,arm64)

# Build vndklite microG arm64 GSI (depends on normal microG arm64 build)
build-vndklite-microg-arm64: setup build-container build-microg-arm64
	# This target depends on build-microg-arm64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,microg,arm64)

# Build vndklite GApps arm64 GSI (depends on normal GApps arm64 build)
build-vndklite-gapps-arm64: setup build-container build-gapps-arm64
	# This target depends on build-gapps-arm64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,gapps,arm64)

# Build vndklite vanilla arm32_binder64 GSI (depends on normal vanilla a64 build)
build-vndklite-vanilla-a64: setup build-container build-vanilla-a64
	# This target depends on build-vanilla-a64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,vanilla,a64)

# Build vndklite microG arm32_binder64 GSI (depends on normal microG a64 build)
build-vndklite-microg-a64: setup build-container build-microg-a64
	# This target depends on build-microg-a64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,microg,a64)

# Build vndklite GApps arm32_binder64 GSI (depends on normal GApps a64 build)
build-vndklite-gapps-a64: setup build-container build-gapps-a64
	# This target depends on build-gapps-a64, ensuring the normal build is completed first
	$(call BUILD_VNDKLITE_GSI,gapps,a64)

# Convenience targets for building all variants of a specific type
build-vanilla: build-vanilla-arm64 build-vanilla-a64
build-microg: build-microg-arm64 build-microg-a64
build-gapps: build-gapps-arm64 build-gapps-a64
build-vndklite: build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64 build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64

# Build all arm64 variants
build-arm64: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64

# Build all arm32_binder64 variants
build-a64: build-vanilla-a64 build-microg-a64 build-gapps-a64 build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64