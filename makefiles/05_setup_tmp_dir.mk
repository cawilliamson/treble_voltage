# Step 5: Setup tmp directory and stash gapps variants
setup-tmp-dir: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			mkdir -p /work/tmp/ && \
			mv -v /work/repo/src/vendor/gapps /work/tmp/ && \
			mv -v /work/repo/src/vendor/partner_gms /work/tmp/'
