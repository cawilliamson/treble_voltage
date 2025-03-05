# Step 3: Perform full sources sync (with auto retry)
sync-sources: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
		pushd /work/repo/src/ && \
			repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags && \
		popd'
