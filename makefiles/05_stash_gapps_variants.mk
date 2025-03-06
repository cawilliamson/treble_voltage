# Step 5: Setup tmp directory and stash gapps variants
stash-gapps-variants: build-container create-folders
	@echo ""
	@echo "#######################"
	@echo "# Stash GApps Variants"
	@echo "#######################"
	@echo ""
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /repo/tmp/ && \
			mv -v /repo/src/vendor/gapps /repo/tmp/ && \
			mv -v /repo/src/vendor/partner_gms /repo/tmp/'
