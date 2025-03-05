# Step 5: Apply debug patches (conditional)
apply-debug-patches: build-container create-folders
	$(CONTAINER_RUN) \
		-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)" \
		voltage-gsi-builder \
		/bin/bash -e -c 'if [ "$$APPLY_DEBUG_PATCHES" = "true" ]; then \
			pushd /work/repo/src/ && \
			/work/repo/patches/apply.sh . debug && \
			popd; \
		else \
			echo "Debug patches not applied (APPLY_DEBUG_PATCHES=false)"; \
		fi'
