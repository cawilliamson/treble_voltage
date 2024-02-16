<p align="center">
  <img src="https://avatars.githubusercontent.com/u/81792437?s=200&v=4">
</p>

### Building
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [How to build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F).

## Glone base repo
Firstly we need to clone the base repo (this one) which we can do by runnng the following:

```shell
git clone --depth=1 https://github.com/kelexine/treble_voltage.git
cd treble_voltage/
```

## Initalise the Treble VoltageOS repo
Now we want to fetch the VoltageOS manifest files:
```shell
repo init --depth=1 -u https://github.com/VoltageOS/manifest.git -b 14
```

## Clone the Manifest
Copy our own manifest which is needed for the GSI portion of the build:
```shell
mkdir -p .repo/local_manifests
cp manifest.xml .repo/local_manifests/
```

## Sync the repository
Sync ALL necessary sources to build the ROM:
```shell
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
```

### Apply the patches
Copy the patches folder to the ROM folder and copy the apply-patches.sh to the rom folder. and run this in the ROM folder:
```shell
./patches/apply.sh . trebledroid
./patches/apply.sh . personal
```

## Adapting for VoltageOS
Clone this repository and then copy Voltage.mk to device/phh/treble in the ROM folder. Then run the following commands:
```shell
pushd  device/phh/treble
cp -v ../../../voltage.mk .
bash generate.sh voltage
popd
```

### Turn On Caching
You can speed up subsequent builds by adding these lines to your `~/.bashrc` OR `~/.zshrc` file:
```shell
sudo apt update && sudo apt install ccache
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
```

## Compilation 
In the ROM folder, run this for building a non-gapps build:

```shell
. build/envsetup.sh
ccache -M 50G -F 0
```
### Lunch For Different Build Types
```shell
# For a64 builds
lunch treble_a64_bvN-userdebug
# For arm64 builds
lunch treble_arm64_bvN-userdebug
```
## Start GSI Build
```shell
# Start Build
make systemimage -j$(nproc --all)
```

## Compression
After compiling the GSI, you can run this to reduce the `system.img` file size:
> Warning<br>
> You will need to decompress the output file to flash the `system.img`. In other words, you cannot flash this file directly.

```bash
cd out/target/product/tdgsi_arm64_ab
xz -9 -T0 -v -z system.img 
```

## Troubleshooting
If you face any conflicts while applying patches, apply the patch manually.
For any other issues, report them via the [Issues](https://github.com/kelexine/treble_voltage/issues) tab.

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
