# Step 4: Apply patches (including optional debug patches)
apply-patches: build-container create-folders
	@echo ""
	@echo "#######################"
	@echo "# Apply Patches"
	@echo "#######################"
	@echo ""
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
