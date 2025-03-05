 # Step 8: Helper function to build a specific GSI variant
define build_gsi_variant
	$(CONTAINER_RUN) \
		-e BUILD_TYPE="$(1)" \
		-e ARCH="$(2)" \
		voltage-gsi-builder \
		/bin/bash -e -c ' \
		pushd /work/repo/src && \
			pushd device/phh/treble && \
				cp -fv /work/repo/configs/voltage-$(1).mk voltage.mk && \
				bash generate.sh voltage && \
			popd && \
			if [ "$(1)" = "microg" ]; then \
				if [ -d "/work/tmp/partner_gms" ]; then \
					cp -Rfv /work/tmp/partner_gms vendor/; \
				else \
					echo "partner_gms not found in tmp dir"; \
					exit 1; \
				fi; \
			elif [ "$(1)" = "gapps" ]; then \
				if [ -d "/work/tmp/gapps" ]; then \
					cp -Rfv /work/tmp/gapps vendor/; \
				else \
					echo "gapps not found in tmp dir"; \
					exit 1; \
				fi; \
			fi && \
			. build/envsetup.sh && \
			lunch treble_$(2)_b$(3)N-ap4a-userdebug && \
			make systemimage -j$(CPU_LIMIT) && \
			if [ "$(2)" = "arm64" ]; then \
				mv -v out/target/product/tdgsi_arm64_ab/system.img /work/tmp/system_$(1)_$(2).img; \
			else \
				mv -v out/target/product/tdgsi_a64_ab/system.img /work/tmp/system_$(1)_$(2).img; \
			fi && \
			if [ "$(1)" = "microg" ]; then \
				rm -Rfv vendor/partner_gms; \
			elif [ "$(1)" = "gapps" ]; then \
				rm -Rfv vendor/gapps; \
			fi && \
		popd'
endef

# Build standard vanilla arm64 image
build-vanilla-arm64: build-container create-folders
	$(call build_gsi_variant,vanilla,arm64,v)

# Build standard microg arm64 image
build-microg-arm64: build-container create-folders
	$(call build_gsi_variant,microg,arm64,m)

# Build standard gapps arm64 image
build-gapps-arm64: build-container create-folders
	$(call build_gsi_variant,gapps,arm64,g)

# Build standard vanilla arm32_binder64 image
build-vanilla-a64: build-container create-folders
	$(call build_gsi_variant,vanilla,a64,v)

# Build standard microg arm32_binder64 image
build-microg-a64: build-container create-folders
	$(call build_gsi_variant,microg,a64,m)

# Build standard gapps arm32_binder64 image
build-gapps-a64: build-container create-folders
	$(call build_gsi_variant,gapps,a64,g)
