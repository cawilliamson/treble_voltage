# Step 1: Clone ROM manifest
clone-rom-manifest: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				repo init -u https://github.com/VoltageOS/manifest.git -b ${ROM_TAG} --depth=1 --git-lfs && \
			popd'
