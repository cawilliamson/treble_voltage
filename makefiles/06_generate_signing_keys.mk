# Step 6: Generate signing keys
generate-signing-keys: build-container create-folders
	@echo ""
	@echo "#######################"
	@echo "# Generate Signing Keys"
	@echo "#######################"
	@echo ""
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/src/vendor/voltage-priv/keys && \
				./keys.sh || true && \
			popd'
