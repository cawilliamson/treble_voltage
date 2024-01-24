<p align="center">
  <img src="https://avatars.githubusercontent.com/u/81792437?s=200&v=4">
</p>

### Building
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [How to build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F).

## Create Directories
As a first step, you'll have to create and enter a folder with the appropriate name.
To do that, run these commands:

```bash
git clone --depth=1 https://github.com/cawilliamson/treble_voltage.git
cd treble_voltage/
```

## Initalise the Treble VoltageOS repo
```bash
repo init -u https://github.com/VoltageOS/manifest.git -b 14
```

## Clone the Manifest
This adds necessary dependencies for the VoltageOS GSI.
```bash
mkdir -p .repo/local_manifests
cp manifest.xml .repo/local_manifests/
```

## Sync the repository
```bash
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

### Apply the patches
Copy the patches folder to the ROM folder and copy the apply-patches.sh to the rom folder. and run this in the ROM folder:
```bash
./patches/apply.sh . trebledroid
./patches/apply.sh . personal
```

## Adapting for VoltageOS
Clone this repository and then copy Voltage.mk to device/phh/treble in the ROM folder. Then run the following commands:
```bash
pushd  device/phh/treble
cp -v ../../../Voltage.mk .
bash generate.sh Voltage
popd
```

### Turn On Caching
You can speed up subsequent builds by adding these lines to your `~/.bashrc` OR `~/.zshrc` file:

```bash
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
```

## Compilation 
In the ROM folder, run this for building a non-gapps build:

```bash
. build/envsetup.sh
ccache -M 50G -F 0
lunch treble_arm64_bvN-userdebug 
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
