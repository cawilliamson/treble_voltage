# Step 5: Setup tmp directory and stash gapps variants
setup-tmp-dir: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /repo/tmp/ && \
			mv -v /repo/src/vendor/gapps /repo/tmp/ && \
			mv -v /repo/src/vendor/partner_gms /repo/tmp/'
