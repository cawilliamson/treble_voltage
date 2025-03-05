# Step 13: Compress all images with xz
compress-images: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
		pushd /work/tmp && \
			find . -maxdepth 1 -name "*.img" -exec xz -9 -T0 -v -z "{}" \; && \
			cp -fv *.img.xz /out/ && \
		popd'
