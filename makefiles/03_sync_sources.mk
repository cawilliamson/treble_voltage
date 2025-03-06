# Step 3: Perform full sources sync (with auto retry)
sync-sources: build-container create-folders
	@echo ""
	@echo "#######################"
	@echo "# Sync Sources"
	@echo "#######################"
	@echo ""
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/ && \
				until repo sync -c -j$(CPU_LIMIT) --force-sync --no-clone-bundle --no-tags; do \
					echo "Sync failed, retrying in 30 seconds..."; \
					sleep 30; \
				done && \
			popd'
