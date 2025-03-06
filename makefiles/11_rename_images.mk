# Step 11: Rename image files
rename-images: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				mv -v system_vanilla_arm64.img "VoltageOS"-vanilla-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v system_microg_arm64.img "VoltageOS"-microg-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v system_gapps_arm64.img "VoltageOS"-gapps-arm64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v system_vanilla_a64.img "VoltageOS"-vanilla-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v system_microg_a64.img "VoltageOS"-microg-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v system_gapps_a64.img "VoltageOS"-gapps-arm32_binder64-ab-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_vanilla_arm64_vndklite.img "VoltageOS"-vanilla-arm64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_microg_arm64_vndklite.img "VoltageOS"-microg-arm64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_gapps_arm64_vndklite.img "VoltageOS"-gapps-arm64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_vanilla_a64_vndklite.img "VoltageOS"-vanilla-arm32_binder64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_microg_a64_vndklite.img "VoltageOS"-microg-arm32_binder64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
				mv -v s_gapps_a64_vndklite.img "VoltageOS"-gapps-arm32_binder64-ab-vndklite-"$${ROM_VERSION}"-"$${BUILD_DATE}"-UNOFFICIAL.img && \
			popd'
