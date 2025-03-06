# Step 2: Copy manifest config
copy-manifest-config: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /repo/src/.repo/local_manifests && \
			cp -v /repo/configs/*.xml /repo/src/.repo/local_manifests/'
