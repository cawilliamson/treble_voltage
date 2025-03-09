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

# Build configuration
BUILD_DATE := $(shell date "+%Y%m%d")
APPLY_DEBUG_PATCHES ?= false
ROM_TAG ?= 15-qpr1
ROM_VERSION ?= 4.2

# Resource configuration
MAX_CPU_PERCENT ?= 100
MAX_MEM_PERCENT ?= 100
CPU_LIMIT := $(shell echo $$(( $(shell nproc --all) * $(MAX_CPU_PERCENT) / 100 )))
MEM_LIMIT := $(shell echo "$$(( $(shell free -m | awk '/^Mem:/{print $$2}') * $(MAX_MEM_PERCENT) / 100 ))m")

# Container configuration
CONTAINER_RUNTIME ?= podman

# Build variants configuration
BUILD_TYPES := vanilla microg gapps
ARCHITECTURES := arm64 a64
ARCH_DISPLAY_NAMES := arm64 arm32_binder64
BUILD_TYPE_CODES := v m g

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

#######################
# Define all phony targets
#######################
.PHONY: all all-images clean build-container create-folders \
	clone-rom-manifest copy-manifest-config sync-sources \
	apply-patches stash-gapps-variants generate-signing-keys \
	build-treble-app \
	build-prerequisites post-build \
	$(foreach type,$(BUILD_TYPES),build-$(type)) \
	$(foreach arch,$(ARCHITECTURES),build-$(arch)) \
	$(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),build-$(type)-$(arch))) \
	rename-images compress-images full-build

#######################
# Main targets
#######################

# Default target is now full-build
all: full-build

# Target for building all images without source preparation
all-images: $(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),build-$(type)-$(arch))) post-build

# Clean build directories
clean:
	rm -rfv out/ src/ tmp/

# Build container image
build-container:
	$(CONTAINER_RUNTIME) build -t voltage-gsi-builder -f Containerfile .

create-folders:
	mkdir -p out/ src/ tmp/

# Convenience targets for building all variants of a specific type
define build_type_target
build-$(1): $(foreach arch,$(ARCHITECTURES),build-$(1)-$(arch))
endef

$(foreach type,$(BUILD_TYPES),$(eval $(call build_type_target,$(type))))

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

#######################
# Build steps
#######################

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
			pushd /repo/src && \
				mv -v vendor/gapps /repo/tmp/ && \
				mv -v vendor/partner_gms /repo/tmp/ && \
			popd'

# Step 6: Generate signing keys
generate-signing-keys: build-container create-folders
	$(call print_section,Generate Signing Keys)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/vendor/voltage-priv/keys && \
				./keys.sh || true && \
			popd'

# Step 7: Build treble app
build-treble-app: build-container create-folders
	$(call print_section,Build Treble App)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/treble_app/ && \
				bash build.sh release && \
				cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk && \
			popd'

# Step 8: Helper function to build a specific GSI variant
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
			lunch treble_$(2)_b$(3)N-ap4a-userdebug && \
			make systemimage -j$(CPU_LIMIT) && \
			make vndk-test-sepolicy -j$(CPU_LIMIT) && \
			if [ "$(1)" = "microg" ]; then \
				rm -Rfv vendor/partner_gms; \
			elif [ "$(1)" = "gapps" ]; then \
				rm -Rfv vendor/gapps; \
			fi && \
			mv -v out/target/product/tdgsi_$(2)_ab/system.img /repo/tmp/system_$(1)_$(2).img && \
		popd'
endef

# Define a function to generate build targets
define generate_build_target
build-$(1)-$(2): build-prerequisites
	$$(call print_section,Build $(shell echo $(1) | sed 's/.*/\u&/') $(shell echo $(2) | tr 'a-z' 'A-Z'))
	$$(call build_gsi_variant,$(1),$(2),$(word $(shell expr $(shell echo $(BUILD_TYPES) | tr ' ' '\n' | grep -n "^$(1)$$" | cut -d: -f1) + 0),$(BUILD_TYPE_CODES)))
endef

# Generate all build targets
$(foreach type,$(BUILD_TYPES),$(foreach arch,$(ARCHITECTURES),$(eval $(call generate_build_target,$(type),$(arch)))))

# Step 9: Rename image files
rename-images: build-container create-folders
	$(call print_section,Rename Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
			variants=("vanilla" "microg" "gapps"); \
			archs=("arm64" "a64"); \
			arch_names=("arm64" "arm32_binder64"); \
			for i in $${!variants[@]}; do \
				for j in $${!archs[@]}; do \
					src="system_$${variants[i]}_$${archs[j]}.img"; \
					if [ -f "$$src" ]; then \
						dest="VoltageOS-$${variants[i]}-$${arch_names[j]}-ab-$${ROM_VERSION}-$${BUILD_DATE}-UNOFFICIAL.img"; \
						mv -v "$$src" "$$dest"; \
					fi; \
				done; \
			done && \
			popd'

# Step 10: Compress all images with xz
compress-images: build-container create-folders
	$(call print_section,Compress Images)
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				find . -maxdepth 1 -name "*.img" -exec xz -9 -T0 -v -z "{}" \; && \
				cp -fv *.img.xz /repo/out/ && \
			popd'
