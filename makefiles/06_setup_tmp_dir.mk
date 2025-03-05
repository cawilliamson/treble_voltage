# Step 6: Setup tmp directory and stash gapps variants
setup-tmp-dir: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'mkdir -p /work/tmp/ && \
		echo "$(BUILD_DATE)" > /work/tmp/cachedBuildDate.txt && \
		if [ -d "/work/repo/src/vendor/gapps" ]; then \
			mv -v /work/repo/src/vendor/gapps /work/tmp/; \
		else \
			echo "vendor/gapps not found, skipping"; \
		fi && \
		if [ -d "/work/repo/src/vendor/partner_gms" ]; then \
			mv -v /work/repo/src/vendor/partner_gms /work/tmp/; \
		else \
			echo "vendor/partner_gms not found, skipping"; \
		fi'
