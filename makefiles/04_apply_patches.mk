# Step 4: Apply patches
apply-patches: build-container
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src/ && \
		# apply trebledroid patches \
		/work/repo/patches/apply.sh . trebledroid && \
		# apply personal patches \
		/work/repo/patches/apply.sh . personal && \
		popd'
