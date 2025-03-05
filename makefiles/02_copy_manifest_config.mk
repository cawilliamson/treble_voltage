# Step 2: Copy manifest config
copy-manifest-config: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'mkdir -p /work/repo/src/.repo/local_manifests && \
		cp -v /work/repo/configs/*.xml /work/repo/src/.repo/local_manifests/'
