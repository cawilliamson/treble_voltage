#!/bin/bash

echo
echo "--------------------------------------"
echo "      VoltageOS 14.0 Buildbot       "
echo "                  by                  "
echo "               kelexine               "
echo "--------------------------------------"
echo

set -e

BL=$PWD/treble_voltage
BD=$BL/builds

initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing workspace"
        repo init -u https://github.com/Evolution-X/manifest -b udc
        echo

        echo "--> Preparing local manifest"
        mkdir -p .repo/local_manifests
        cp $BL/manifest.xml .repo/local_manifests/
        echo
    fi
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
    echo
}

applyPatches() {
    echo "--> Applying trebledroid patches"
    bash $BL/apply-patches.sh $BL trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BL/apply-patches.sh $BL personal
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    cp $BL/voltage.mk .
    bash generate.sh evo
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building treble_a64_bvN"
    lunch treble_a64_bvN-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_a64_bvN.img
    echo
}

buildMiniVariant() {
    echo "--> Building treble_a64_bvN-mini"
    (cd vendor/voltage && git am $BL/patches/mini.patch)
    make -j$(nproc --all) systemimage
    (cd vendor/voltage && git reset --hard HEAD~1)
    mv $OUT/system.img $BD/system-treble_a64_bvN-mini.img
    echo
}

buildPicoVariant() {
    echo "--> Building treble_a64_bvN-pico"
    (cd vendor/voltage && git am $BL/patches/pico.patch)
    make -j$(nproc --all) systemimage
    (cd vendor/voltage && git reset --hard HEAD~1)
    mv $OUT/system.img $BD/system-treble_a64_bvN-pico.img
    echo
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    xz -cv $BD/system-treble_a64_bvN.img -T0 > $BD/voltage_a64-ab-3.2-unofficial-$buildDate.img.xz
    xz -cv $BD/system-treble_a64_bvN-mini.img -T0 > $BD/voltage_a64-ab-mini-3.2-unofficial-$buildDate.img.xz
    xz -cv $BD/system-treble_a64_bvN-pico.img -T0 > $BD/voltage_a64-ab-pico-3.2-unofficial-$buildDate.img.xz
    rm -rf $BD/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $BD/ -name "voltage_*" | sort | {
        while read file; do
            filename="$(basename $file)"
            if [[ $filename == *"mini"* ]]; then
                name="treble_a64_bvN-mini"
            elif [[ $filename == *"pico"* ]]; then
                name="treble_a64_bvN-pico"
            else
                name="treble_a64_bvN"
            fi
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/kelexine/treble_evo/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BL/ota.json
    }
    echo
}

START=$(date +%s)

initRepos
syncRepos
applyPatches
setupEnv
buildTrebleApp
buildVariant
buildMiniVariant
buildPicoVariant
generatePackages
generateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
