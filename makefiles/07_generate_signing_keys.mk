# Step 7: Generate signing keys
generate-signing-keys: build-container
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src && \
		. build/envsetup.sh && \
		pushd vendor/voltage-priv/keys && \
		./gen_keys || true && \
		popd && \
		popd'
