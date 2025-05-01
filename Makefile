# VoltageOS GSI Builder Makefile
#
# This Makefile automates the process of building VoltageOS GSI images for various
# architectures and configurations (vanilla, microG, GApps).
# It handles the entire build process from source preparation to final image compression.
#
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

#######################
# Configuration variables
#######################

# ROM configuration
ANDROID_VERSION_TAG ?= ap4a
APPLY_DEBUG_PATCHES ?= false
BUILD_DATE := $(shell date "+%Y%m%d")
BUILD_TIME := $(shell date "+%H%M%S")
ROM_TAG ?= 15-qpr2
ROM_VERSION ?= 4.3
VERIFY_SEPOLICY ?= true
UPLOAD_TO_GITHUB ?= false

# Build variants configuration
ARCHITECTURES := arm64 a64
ARCH_DISPLAY_NAMES := arm64 arm32_binder64
BUILD_TYPES := vanilla microg gapps
BUILD_TYPE_CODES := v m g

# Resource configuration
MAX_CPU_PERCENT ?= 100
MAX_MEM_PERCENT ?= 100

# Container configuration
CONTAINER_RUNTIME ?= podman

# System variables
# Store BUILD_NUMBER in a file to ensure consistency across make invocations
BUILD_NUMBER_FILE := tmp/.build_number
$(shell mkdir -p tmp)
ifeq ($(wildcard $(BUILD_NUMBER_FILE)),)
    $(shell echo "$(BUILD_DATE).$(BUILD_TIME)" > $(BUILD_NUMBER_FILE))
endif
BUILD_NUMBER := $(shell cat $(BUILD_NUMBER_FILE))
CPU_LIMIT := $(shell echo $$(( $(shell nproc --all) * $(MAX_CPU_PERCENT) / 100 )))
MEM_LIMIT := $(shell echo "$$(( $(shell free -m | awk '/^Mem:/{print $$2}') * $(MAX_MEM_PERCENT) / 100 ))m")

# Common container parameters
CONTAINER_RUN = $(CONTAINER_RUNTIME) run --rm --privileged \
	--cpus="$(CPU_LIMIT)" \
	--memory="$(MEM_LIMIT)" \
	--pids-limit=0 \
	-v "$(PWD):/repo:Z" \
	-e BUILD_DATE="$(BUILD_DATE)" \
	-e BUILD_NUMBER="$(BUILD_NUMBER)" \
	-e BUILD_NUMBER_FILE="$(BUILD_NUMBER_FILE)" \
	-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)"

#######################
# Define all phony targets
#######################
.PHONY: all all-images apply-patches build-container build-prerequisites build-treble-app \
	clean clone-rom-manifest compress-images copy-manifest-config create-folders \
	full-build generate-signing-keys post-build rename-images \
	stash-gapps-variants sync-sources upload-to-github \
	$(foreach type,$(BUILD_TYPES),build-$(type)) \
	$(foreach arch,$(ARCHITECTURES),build-$(arch)) \
	$(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),build-$(type)-$(arch)))

#######################
# Main targets
#######################

# Default target - runs the full build process from source preparation to image compression
all: full-build

# Build all image variants without repeating source preparation steps
all-images: $(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),build-$(type)-$(arch))) post-build

# Clean all build directories to start fresh
clean:
	rm -rfv out/ src/ tmp/

# Build the container image used for all build operations
build-container:
	$(CONTAINER_RUNTIME) build -t voltage-gsi-builder -f Containerfile .

# Create necessary directories for the build process
create-folders:
	mkdir -p out/ src/ tmp/
	rm -rf tmp/*

# Convenience targets for building all variants of a specific type
define build_type_target
build-$(1): $(foreach arch,$(ARCHITECTURES),build-$(1)-$(arch))
endef

$(foreach type,$(BUILD_TYPES),$(eval $(call build_type_target,$(type))))

# Define a function to generate build targets - Creates build targets for each variant/architecture combination
define generate_build_target
build-$(1)-$(2): build-prerequisites
	$$(call print_section,Build $(shell echo $(1) | sed 's/.*/\u&/') $(shell echo $(2) | tr 'a-z' 'A-Z'))
	$$(call build_gsi_variant,$(1),$(2),$(word $(shell expr $(shell echo $(BUILD_TYPES) | tr ' ' '\n' | grep -n "^$(1)$$" | cut -d: -f1) + 0),$(BUILD_TYPE_CODES)),$(VERIFY_SEPOLICY),$(ANDROID_VERSION_TAG))
endef

# Generate all build targets - Creates all variant/architecture combinations dynamically
$(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),$(eval $(call generate_build_target,$(type),$(arch)))))

# Build all variants of a specific architecture
build-arm64: $(foreach type,$(BUILD_TYPES),build-$(type)-arm64)
build-a64: $(foreach type,$(BUILD_TYPES),build-$(type)-a64)

# Full build process
full-build: clone-rom-manifest copy-manifest-config sync-sources \
	apply-patches stash-gapps-variants generate-signing-keys \
	build-treble-app all-images

# Common build prerequisites
build-prerequisites: build-container create-folders clone-rom-manifest copy-manifest-config sync-sources apply-patches stash-gapps-variants generate-signing-keys build-treble-app

# Post-build steps
post-build: rename-images compress-images
	@if [ "$(UPLOAD_TO_GITHUB)" = "true" ]; then \
		$(MAKE) upload-to-github; \
	fi

#######################
# Build steps
#######################

# Step 1: Clone ROM manifest - Initialize the repo with VoltageOS manifest at the specified tag
clone-rom-manifest: build-container create-folders
	$(call print_section,Clone ROM Manifest)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				repo init -u https://github.com/VoltageOS/manifest.git -b $(ROM_TAG) --depth=1 --git-lfs && \
			popd'

# Step 2: Copy manifest config - Add local manifest files to customize the source tree
copy-manifest-config: build-container create-folders
	$(call print_section,Copy Manifest Config)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /repo/src/.repo/local_manifests && \
			cp -v /repo/configs/*.xml /repo/src/.repo/local_manifests/'

# Step 3: Perform full sources sync - Download all source code with automatic retry on failure
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

# Step 4: Apply patches - Apply trebledroid, personal, and optional debug patches to the source
apply-patches: build-container create-folders
	$(call print_section,Apply Patches)
	$(CONTAINER_RUN) \
		voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				/repo/patches/apply.sh . pre && \
				/repo/patches/apply.sh . trebledroid && \
				/repo/patches/apply.sh . personal && \
				if [ "$$APPLY_DEBUG_PATCHES" = "true" ]; then \
					/repo/patches/apply.sh . debug; \
				fi && \
			popd'

# Step 5: Setup tmp directory and stash gapps variants - Move GApps files to tmp for selective inclusion later
stash-gapps-variants: build-container create-folders
	$(call print_section,Stash GApps Variants)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src && \
				mv -v vendor/gapps /repo/tmp/ && \
				mv -v vendor/partner_gms /repo/tmp/ && \
			popd'

# Step 6: Generate signing keys - Create keys for signing the build (continues even if key generation fails)
generate-signing-keys: build-container create-folders
	$(call print_section,Generate Signing Keys)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/vendor/voltage-priv/keys && \
				./keys.sh || true && \
			popd'

# Step 7: Build treble app - Compile the Treble App and copy it to the overlay directory
build-treble-app: build-container create-folders
	$(call print_section,Build Treble App)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/treble_app/ && \
				bash build.sh release && \
			popd'

# Step 8: Helper function to build a specific GSI variant - Core function that builds each ROM variant
define build_gsi_variant
	$(CONTAINER_RUN) \
	-e BUILD_TYPE="$(1)" \
	-e ARCH="$(2)" \
	voltage-gsi-builder \
	/bin/bash -e -c ' \
		pushd /repo/src && \
			pushd device/phh/treble && \
				cp -fv "/repo/configs/voltage-$(1).mk" voltage.mk && \
				bash generate.sh voltage && \
			popd && \
			if [ "$(1)" = "microg" ]; then \
				cp -Rfv /repo/tmp/partner_gms vendor/; \
			elif [ "$(1)" = "gapps" ]; then \
				cp -Rfv /repo/tmp/gapps vendor/; \
			fi && \
			rm -rfv out/target/product/tdgsi_$(2)_ab/ && \
			. build/envsetup.sh && \
			lunch treble_$(2)_b$(3)N-$(5)-userdebug && \
			make systemimage -j$(CPU_LIMIT) && \
			if [ "$(4)" = "true" ]; then \
				make vndk-test-sepolicy -j$(CPU_LIMIT); \
			fi && \
			if [ "$(1)" = "microg" ]; then \
				rm -Rfv vendor/partner_gms; \
			elif [ "$(1)" = "gapps" ]; then \
				rm -Rfv vendor/gapps; \
			fi && \
			mv -v out/target/product/tdgsi_$(2)_ab/system.img /repo/tmp/system_$(1)_$(2).img && \
		popd'
endef

# Step 9: Rename image files - Convert temporary image names to final release filenames
rename-images: build-container create-folders
	$(call print_section,Rename Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
			variants=("vanilla" "microg" "gapps"); \
			archs=("arm64" "a64"); \
			arch_names=("arm64" "arm32_binder64"); \
			BUILD_NUMBER_VAL=$$(cat /repo/$$BUILD_NUMBER_FILE); \
			for i in $${!variants[@]}; do \
				for j in $${!archs[@]}; do \
					src="system_$${variants[i]}_$${archs[j]}.img"; \
					if [ -f "$$src" ]; then \
						dest="VoltageOS-$${variants[i]}-$${arch_names[j]}-ab-$(ROM_VERSION)-$$BUILD_NUMBER_VAL-UNOFFICIAL.img"; \
						mv -v "$$src" "$$dest"; \
					fi; \
				done; \
			done && \
			popd'

# Step 10: Compress all images with xz - Reduce image size for distribution and copy to output directory
compress-images: build-container create-folders
	$(call print_section,Compress Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				find . -maxdepth 1 -name "*.img" -exec xz -9 -T0 -v -z "{}" \; && \
				cp -fv *.img.xz /repo/out/ && \
			popd'

# Step 11: Upload images to GitHub - Create a GitHub release and upload the compressed images (run on local machine)
upload-to-github: create-folders
	$(call print_section,Upload to GitHub)
	@if ! command -v gh &> /dev/null; then \
		echo "Error: GitHub CLI (gh) is not installed. Please install it first." >&2; \
		exit 1; \
	fi
	@cd $(PWD)/out/ && \
		git init && \
		git remote add origin "https://github.com/cawilliamson/treble_voltage.git" && \
		gh repo set-default "cawilliamson/treble_voltage" && \
		BUILD_NUMBER_VAL=$$(cat $(PWD)/$(BUILD_NUMBER_FILE)) && \
		gh release create -d -n "" -t "VoltageOS $(ROM_VERSION)-$$BUILD_NUMBER_VAL" "$(ROM_VERSION)-$$BUILD_NUMBER_VAL" && \
		gh release upload "$(ROM_VERSION)-$$BUILD_NUMBER_VAL" --clobber -- *.img.xz && \
		rm -rf .git/
