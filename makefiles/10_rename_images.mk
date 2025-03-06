# Step 11: Rename image files
rename-images: build-container create-folders
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
