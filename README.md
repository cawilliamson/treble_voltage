<p align="center">
  <img src="https://avatars.githubusercontent.com/u/81792437?s=200&v=4">
  <img src="https://github.com/cawilliamson/treble_voltage/actions/workflows/build-gsi.yml/badge.svg">
</p>

### Building
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [How to build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F).

## Glone base repo
Firstly we need to clone the base repo (this one) which we can do by runnng the following:

```bash
git clone --depth=1 https://github.com/cawilliamson/treble_voltage.git
cd treble_voltage/
```

## Initalise the Treble VoltageOS repo
Now we want to fetch the VoltageOS manifest files:
```bash
repo init -u https://github.com/VoltageOS/manifest.git -b 14
```

## Copy our manifest
Copy our own manifest which is needed for the GSI portion of the build:
```bash
mkdir -p .repo/local_manifests
cp manifest.xml .repo/local_manifests/
```

## Setup the git-lfs hook
In order to setup git-lfs to sync you need to run the following:
```bash
git lfs install
```

## Sync the repository
Sync ALL necessary sources to build the ROM:
```bash
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

## Sync all git-lfs objects
In order to sync the git-lfs objects as swiftly as possible run the following:
```bash
grep -l 'merge=lfs' $( find $PWD -name .gitattributes ) /dev/null | while IFS= read -r line; do
  dir=$(dirname $line)
  echo $dir
  ( cd $dir ; git lfs pull )
done
```

## Apply the patches
Copy the patches folder to the ROM folder and copy the apply-patches.sh to the rom folder. and run this in the ROM folder:
```bash
./patches/apply.sh . pre
./patches/apply.sh . trebledroid
./patches/apply.sh . personal
```

## Build the TrebleApp
In order to build our patched TrebleApp you need to run the following:
```bash
. build/envsetup.sh
pushd treble_app/
bash build.sh release
cp -v TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
popd
```

## Generate base ROM config
In order to generate the base ROM config run the following commands:
```bash
pushd  device/phh/treble
cp -v ../../../voltage.mk .
bash generate.sh voltage
popd
```

## Compilation
In the ROM folder, run this for building an arm64 standard build (needed even if you want a vndklite build):
```bash
. build/envsetup.sh
lunch treble_arm64_bvN-userdebug
make systemimage -j$(nproc --all)
```

## Convert standard build to vndklite build (optional)
Run the following commands if you require a vndklite build:
```bash
pushd treble_adapter/
cp -v ../out/target/product/tdgsi_arm64_ab/system.img standard_system_arm64.img
sudo bash-adapter.sh 64 standard_system_arm64.img
sudo mv s.img s_arm64.img
sudo chown $(whoami):$(id | awk -F'[()]' '{ print $2 }') s_arm64.img
popd
```

## Troubleshooting
If you face any conflicts while applying patches, apply the patch manually.
For any other issues, report them via the [Issues](https://github.com/cawilliamson/treble_voltage/issues) tab.

## Credits
These people have helped this project in some way or another, so they should be the ones who receive all the credit:
- [VoltageOS Team](https://github.com/VoltageOS)
- [Phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [Ponces](https://github.com/ponces)
- [Peter Cai](https://github.com/PeterCxy)
- [Iceows](https://github.com/Iceows)
- [ChonDoit](https://github.com/ChonDoit)
- [Nazim](https://github.com/naz664)
- [UniversalX](https://github.com/orgs/UniversalX-devs/)
- [TQMatvey](https://github.com/TQMatvey)
