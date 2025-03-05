# Step 8: Build treble app
build-treble-app: build-container create-folders
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/repo/src && \
		# copy vanilla config for treble app build \
		pushd device/phh/treble && \
		cp -fv /work/repo/configs/voltage-vanilla.mk voltage.mk && \
		bash generate.sh voltage && \
		popd && \
		. build/envsetup.sh && \
		pushd treble_app/ && \
		bash build.sh release && \
		cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk && \
		popd && \
		popd'
