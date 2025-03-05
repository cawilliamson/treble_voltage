# Step 9: Run vndk sepolicy tests
vndk-test-sepolicy: build-container
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src && \
		. build/envsetup.sh && \
		lunch treble_arm64_bvN-ap1a-userdebug && \
		make vndk-test-sepolicy -j$(CPU_LIMIT) && \
		popd'
