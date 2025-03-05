# Step 4: Apply patches
apply-patches: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
		pushd /work/repo/src/ && \
			/work/repo/patches/apply.sh . trebledroid && \
			/work/repo/patches/apply.sh . personal && \
		popd'
