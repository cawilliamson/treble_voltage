.PHONY: all clean setup build-container build-vanilla-arm64 build-microg-arm64 build-gapps-arm64 build-vanilla-a64 build-microg-a64 build-gapps-a64
# Commented out vndklite targets - will address later
#	build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64 \
#	build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64

# Configuration variables
BUILD_DATE := $(shell date "+%Y-%m-%d")
DEBUG_PATCHES ?= false
ROM_NAME ?= VoltageOS
ROM_TAG ?= 15-qpr1
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
	-v "$(PWD):/work/repo:Z" \
	-e BUILD_DATE="$(BUILD_DATE)" \
	-e DEBUG_PATCHES="$(DEBUG_PATCHES)" \
	-e ROM_NAME="$(ROM_NAME)" \
	-e ROM_VERSION="$(ROM_VERSION)"

# Default target
all: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64
# Commented out vndklite targets - will address later
# build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64

# Setup output directory
setup:
	mkdir -p $(OUTPUT_DIR)

# Build container image
build-container:
	podman build -t voltage-gsi-builder -f Containerfile .

# Clean build directories
clean:
	rm -rf $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)

# Step 1: Clone ROM manifest
define CLONE_MANIFEST
	echo "Step 1: Cloning ROM manifest..." && \
	mkdir -p /work/repo/src && \
	pushd /work/repo/src && \
		repo init -u https://github.com/VoltageOS/manifest.git -b ${ROM_TAG} --depth=1 --git-lfs && \
	popd
endef

# Step 2: Copy manifest config
define COPY_MANIFEST_CONFIG
	echo "Step 2: Copying manifest config..." && \
	pushd /work/repo/src && \
		mkdir -p .repo/local_manifests && \
		cp -v /work/repo/configs/*.xml .repo/local_manifests/ && \
	popd
endef

# Step 3: Perform full sources sync with retry mechanism
define SYNC_SOURCES
	echo "Step 3: Syncing sources..." && \
	pushd /work/repo/src && \
		while true; do \
			echo "Attempting repo sync..." && \
			if repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags; then \
				echo "Repo sync completed successfully!" && \
				break; \
			else \
				echo "Repo sync failed. Waiting 30 seconds before retrying..." && \
				sleep 30; \
			fi \
		done && \
	popd
endef

# Step 4: Apply patches
define APPLY_PATCHES
	echo "Step 4: Applying patches..." && \
	pushd /work/repo/src && \
		echo "Applying trebledroid patches..." && \
		/work/repo/patches/apply.sh . trebledroid && \
		echo "Applying personal patches..." && \
		/work/repo/patches/apply.sh . personal && \
		if [ '$(DEBUG_PATCHES)' = 'true' ]; then \
			echo "Applying debug patches..." && \
			/work/repo/patches/apply.sh . debug; \
		fi && \
	popd
endef

# Step 5: Setup tmp directory and stash gapps variants
define SETUP_TMP_DIR
	echo "Step 5: Setting up tmp directory and stashing gapps variants..." && \
	mv -v /work/repo/src/vendor/gapps /work/tmp/ && \
	mv -v /work/repo/src/vendor/partner_gms /work/tmp/
endef

# Step 6: Generate signing keys
define GENERATE_KEYS
	echo "Step 6: Generating signing keys..." && \
	pushd /work/repo/src/vendor/voltage-priv/keys && \
		./keys.sh || true && \
	popd
endef

# Step 7: Generate ROM config
define GENERATE_ROM_CONFIG
	echo "Step 7: Generating ROM config for $(1)..." && \
	pushd /work/repo/src && \
		. build/envsetup.sh && \
		pushd /work/repo/src/device/phh/treble && \
			cp -fv /work/repo/configs/voltage-$(1).mk voltage.mk && \
			bash generate.sh voltage && \
		popd && \
	popd
endef

# Step 8: Build treble app
define BUILD_TREBLE_APP
	echo "Step 8: Building treble app..." && \
	pushd /work/repo/src/treble_app/ && \
		bash build.sh release && \
		cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk && \
	popd && \
	$(call GENERATE_ROM_CONFIG,$(1))
endef

# Step 9: Copy vendor files (microg/gapps)
define COPY_VENDOR_FILES
	echo "Step 9: Copying vendor files for $(1)..." && \
	if [ "$(1)" = "microg" ]; then \
		cp -Rfv /work/tmp/partner_gms /work/repo/src/vendor/; \
	elif [ "$(1)" = "gapps" ]; then \
		cp -Rfv /work/tmp/gapps /work/repo/src/vendor/; \
	fi
endef

# Step 10: Build system image
define BUILD_SYSTEM_IMAGE
	echo "Step 10: Building system image for $(1) ($(3))..." && \
	pushd /work/repo/src && \
		lunch treble_$(1)_b$(2)N-ap4a-userdebug && \
		make systemimage -j$(CPU_LIMIT) && \
		if [ "$(1)" = "arm64" ]; then \
			mv -v out/target/product/tdgsi_arm64_ab/system.img /work/tmp/system_$(3)_$(1).img; \
		else \
			mv -v out/target/product/tdgsi_a64_ab/system.img /work/tmp/system_$(3)_$(1).img; \
		fi && \
	popd
endef

# Step 11: Run vndk sepolicy tests
define RUN_SEPOLICY_TESTS
	echo "Step 11: Running vndk sepolicy tests..." && \
	pushd /work/repo/src && \
		make vndk-test-sepolicy -j$(CPU_LIMIT) && \
	popd
endef

# Step 12: Prepare output
define PREPARE_OUTPUT
	echo "Step 12: Preparing output for $(2) ($(1))..." && \
	pushd /work/tmp && \
		if [ "$(1)" = "arm64" ]; then \
			mv -v system_$(2)_$(1).img $(ROM_NAME)-$(2)-$(1)-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img; \
		else \
			mv -v system_$(2)_$(1).img $(ROM_NAME)-$(2)-arm32_binder64-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img; \
		fi && \
		find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \; && \
		cp -fv *.img.xz /out/ && \
	popd
endef

# Commented out vndklite functions - will address later
# # Step 14: Setup for vndklite build using normal build output
# define SETUP_VNDKLITE_WORKSPACE
# 	echo "Step 14: Setting up vndklite workspace..." && \
# 	# Create tmp directory if it doesn't exist
# 	mkdir -p /work/tmp/ && \
# 	# Copy normal build output from output directory
# 	cp -v /out/*.img.xz . 2>/dev/null || echo 'No images found' && \
# 	# Extract the compressed images
# 	find . -name '*.img.xz' -exec xz -d "{}" \; 2>/dev/null || true
# endef
#
# # Step 15: Initialize repo for vndklite
# define INIT_VNDKLITE_REPO
# 	echo "Step 15: Initializing repo for vndklite..." && \
# 	mkdir -p src/ && cd src/ && \
# 	repo init -u https://github.com/VoltageOS/manifest.git -b 15-qpr1 --depth=1 --git-lfs && \
# 	mkdir -p .repo/local_manifests && \
# 	cp -v /work/repo/configs/*.xml .repo/local_manifests/ && \
# 	repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags --current-branch treble_adapter
# endef
#
# # Step 16: Process vndklite image using normal build output
# define PROCESS_VNDKLITE_IMAGE
# 	echo "Step 16: Processing vndklite image for $(1) ($(2))..." && \
# 	cd src/treble_adapter && \
# 	# Copy the normal build image to use as input for vndklite conversion
# 	cp -v ../../$(ROM_NAME)-$(1)-$(if $(filter $(2),a64),arm32_binder64,$(2))-ab-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img standard_system_$(1)_$(2).img && \
# 	# Run the lite-adapter script to convert the normal build to vndklite
# 	bash lite-adapter.sh $(if $(filter $(2),a64),32,64) standard_system_$(1)_$(2).img && \
# 	# Move the resulting vndklite image
# 	mv s.img ../../s_$(1)_$(2)_vndklite.img
# endef
#
# # Step 17: Rename and compress vndklite image for output
# define RENAME_VNDKLITE_IMAGE
# 	echo "Step 17: Renaming and compressing vndklite image for $(1) ($(2))..." && \
# 	# Rename the vndklite image to follow the naming convention
# 	mv -v s_$(1)_$(2)_vndklite.img $(ROM_NAME)-$(1)-$(if $(filter $(2),a64),arm32_binder64,$(2))-ab-vndklite-$(ROM_VERSION)-$${BUILD_DATE}-UNOFFICIAL.img && \
# 	# Compress the image
# 	find . -maxdepth 1 -name '*.img' -exec xz -9 -T0 -v -z "{}" \; && \
# 	# Copy the compressed image to the output directory
# 	cp -fv *.img.xz /out/
# endef

# Build standard GSI (vanilla/microg/gapps)
define BUILD_STANDARD_GSI
	$(CONTAINER_RUN) \
		-e BUILD_TYPE="$(1)" \
		-e ARCH="$(2)" \
		voltage-gsi-builder \
		/bin/bash -c '$(CLONE_MANIFEST) && \
		$(COPY_MANIFEST_CONFIG) && \
		$(SYNC_SOURCES) && \
		$(APPLY_PATCHES) && \
		$(SETUP_TMP_DIR) && \
		$(GENERATE_KEYS) && \
		$(call GENERATE_ROM_CONFIG,$(1)) && \
		$(call BUILD_TREBLE_APP,$(1)) && \
		$(call COPY_VENDOR_FILES,$(1)) && \
		$(call BUILD_SYSTEM_IMAGE,$(2),$(3),$(1)) && \
		$(RUN_SEPOLICY_TESTS) && \
		$(call PREPARE_OUTPUT,$(2),$(1))'
endef
# Commented out vndklite function - will address later
# # Build vndklite GSI (using normal build output)
# define BUILD_VNDKLITE_GSI
# 	mkdir -p $(OUTPUT_DIR)
# 	# This target depends on the normal build target, ensuring the normal build is completed first
# 	# The normal build output is then used as input for the vndklite build
# 	$(CONTAINER_RUN) \
# 		-e BUILD_TYPE="vndklite-$(1)" \
# 		-e ARCH="$(2)" \
# 		voltage-gsi-builder \
# 		/bin/bash -c '$(SETUP_VNDKLITE_WORKSPACE) && \
# 		$(INIT_VNDKLITE_REPO) && \
# 		$(call PROCESS_VNDKLITE_IMAGE,$(1),$(2)) && \
# 		$(call RENAME_VNDKLITE_IMAGE,$(1),$(2))'
# endef

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

# Commented out vndklite build targets - will address later
# # Build vndklite vanilla arm64 GSI (depends on normal vanilla arm64 build)
# build-vndklite-vanilla-arm64: setup build-container build-vanilla-arm64
# 	# This target depends on build-vanilla-arm64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,vanilla,arm64)
#
# # Build vndklite microG arm64 GSI (depends on normal microG arm64 build)
# build-vndklite-microg-arm64: setup build-container build-microg-arm64
# 	# This target depends on build-microg-arm64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,microg,arm64)
#
# # Build vndklite GApps arm64 GSI (depends on normal GApps arm64 build)
# build-vndklite-gapps-arm64: setup build-container build-gapps-arm64
# 	# This target depends on build-gapps-arm64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,gapps,arm64)
#
# # Build vndklite vanilla arm32_binder64 GSI (depends on normal vanilla a64 build)
# build-vndklite-vanilla-a64: setup build-container build-vanilla-a64
# 	# This target depends on build-vanilla-a64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,vanilla,a64)
#
# # Build vndklite microG arm32_binder64 GSI (depends on normal microG a64 build)
# build-vndklite-microg-a64: setup build-container build-microg-a64
# 	# This target depends on build-microg-a64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,microg,a64)
#
# # Build vndklite GApps arm32_binder64 GSI (depends on normal GApps a64 build)
# build-vndklite-gapps-a64: setup build-container build-gapps-a64
# 	# This target depends on build-gapps-a64, ensuring the normal build is completed first
# 	$(call BUILD_VNDKLITE_GSI,gapps,a64)

# Convenience targets for building all variants of a specific type
build-vanilla: build-vanilla-arm64 build-vanilla-a64
build-microg: build-microg-arm64 build-microg-a64
build-gapps: build-gapps-arm64 build-gapps-a64
# Commented out vndklite target - will address later
# build-vndklite: build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64 build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64

# Build all arm64 variants
build-arm64: build-vanilla-arm64 build-microg-arm64 build-gapps-arm64
# Commented out vndklite targets - will address later
# build-vndklite-vanilla-arm64 build-vndklite-microg-arm64 build-vndklite-gapps-arm64

# Build all arm32_binder64 variants
build-a64: build-vanilla-a64 build-microg-a64 build-gapps-a64
# Commented out vndklite targets - will address later
# build-vndklite-vanilla-a64 build-vndklite-microg-a64 build-vndklite-gapps-a64
