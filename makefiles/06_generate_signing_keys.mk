# Step 6: Generate signing keys
generate-signing-keys: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /work/repo/src/pushd vendor/voltage-priv/keys && \
				./keys || true && \
			popd'
