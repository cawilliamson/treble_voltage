# Step 11: Helper function to adapt a vndklite image
define adapt_vndklite_image
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src/treble_adapter && \
		cp -v /work/tmp/system_$(1)_$(2).img standard_system_$(1)_$(2).img && \
		sudo bash lite-adapter.sh $(if $(filter $(2),a64),32,64) standard_system_$(1)_$(2).img && \
		sudo mv s.img /work/tmp/s_$(1)_$(2)_vndklite.img && \
		sudo chown $$(whoami):$$(id | awk -F"[()]" "{ print \$$2 }") /work/tmp/s_$(1)_$(2)_vndklite.img && \
		popd'
endef

# Adapt vndklite vanilla arm64 image
adapt-vndklite-vanilla-arm64: build-container create-folders
	$(call adapt_vndklite_image,vanilla,arm64)

# Adapt vndklite microg arm64 image
adapt-vndklite-microg-arm64: build-container create-folders
	$(call adapt_vndklite_image,microg,arm64)

# Adapt vndklite gapps arm64 image
adapt-vndklite-gapps-arm64: build-container create-folders
	$(call adapt_vndklite_image,gapps,arm64)

# Adapt vndklite vanilla arm32_binder64 image
adapt-vndklite-vanilla-a64: build-container create-folders
	$(call adapt_vndklite_image,vanilla,a64)

# Adapt vndklite microg arm32_binder64 image
adapt-vndklite-microg-a64: build-container create-folders
	$(call adapt_vndklite_image,microg,a64)

# Adapt vndklite gapps arm32_binder64 image
adapt-vndklite-gapps-a64: build-container create-folders
	$(call adapt_vndklite_image,gapps,a64)
