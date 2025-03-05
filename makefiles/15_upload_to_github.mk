# Step 15: Upload to GitHub
upload-to-github: build-container
	$(CONTAINER_RUN) voltage-gsi-builder \
		/bin/bash -e -c 'pushd /work/tmp && \
		buildDate=$$(cat cachedBuildDate.txt) && \
		rm -f cachedBuildDate.txt && \
		pushd "/var/www/html/VoltageOS-$${ROM_VERSION}-$${buildDate}" && \
		# create fake git repo \
		git init && \
		# set git remote \
		git remote add origin "https://github.com/$${MAINTAINER}/$${REPO_NAME}.git" && \
		# set default repo \
		gh repo set-default "$${MAINTAINER}/$${REPO_NAME}" && \
		# create release \
		gh release create -d -n "" -t "VoltageOS $${ROM_VERSION}-$${buildDate}" "$${ROM_VERSION}-$${buildDate}" && \
		# upload files \
		gh release upload "$${ROM_VERSION}"-"$${buildDate}" --clobber -- *.img.xz && \
		# remove git dir \
		rm -rf .git/ && \
		popd && \
		popd'
