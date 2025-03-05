# Step 4: Apply patches (including optional debug patches)
apply-patches: build-container create-folders
	$(CONTAINER_RUN) \
		-e APPLY_DEBUG_PATCHES="$(APPLY_DEBUG_PATCHES)" \
		voltage-gsi-builder \
		/bin/bash -e -c ' \
		pushd /work/repo/src/ && \
			/work/repo/patches/apply.sh . trebledroid && \
			/work/repo/patches/apply.sh . personal && \
			if [ "$$APPLY_DEBUG_PATCHES" = "true" ]; then \
				/work/repo/patches/apply.sh . debug; \
			fi && \
		popd'
