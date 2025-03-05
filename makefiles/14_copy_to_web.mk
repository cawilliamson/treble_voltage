# Step 14: Copy all files to web directory
copy-to-web: build-container
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/tmp && \
		buildDate=$$(cat cachedBuildDate.txt) && \
		webDir="/var/www/html/VoltageOS-$${ROM_VERSION}-$${buildDate}" && \
		mkdir -p "$${webDir}" && \
		cp -fv *.img.xz "$${webDir}/" && \
		cp -v cachedBuildDate.txt /var/www/html/ && \
		popd'
