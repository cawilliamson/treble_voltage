# Step 3: Perform full sources sync (with auto retry)
sync-sources: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src/ && \
		for i in 1 2 3; do \
			echo "Sync attempt $$i of 3" && \
			if repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags; then \
				echo "Sync successful!" && exit 0; \
			fi; \
			echo "Sync failed, retrying in 30 seconds..." && sleep 30; \
		done; \
		echo "All sync attempts failed" && exit 1'
