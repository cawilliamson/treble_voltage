# Step 12: Compress all images with xz
compress-images: build-container create-folders
	@echo ""
	@echo "#######################"
	@echo "# Compress Images"
	@echo "#######################"
	@echo ""
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c ' \
			pushd /repo/tmp && \
				find . -maxdepth 1 -name "*.img" -exec xz -9 -T0 -v -z "{}" \; && \
					cp -fv *.img.xz /repo/out/ && \
			popd'
