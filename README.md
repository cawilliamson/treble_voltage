<p align="center">
  <img src="https://avatars.githubusercontent.com/u/81792437?s=200&v=4">
</p>

### Building
You'll need to get familiar with [Git and Repo](https://source.android.com/source/using-repo.html) as well as [How to build a GSI](https://github.com/phhusson/treble_experimentations/wiki/How-to-build-a-GSI%3F).

## Create Directories
As a first step, you'll have to create and enter a folder with the appropriate name.
To do that, run these commands:

```bash
mkdir VoltageOS
cd VoltageOS
```

## Initalise the Treble VoltageOS repo
```bash
repo init -u https://github.com/VoltageOS/manifest.git -b 14
```

## Clone the Manifest
This adds necessary dependencies for the VoltageOS GSI.
```bash
git clone https://github.com/ahnet-69/treble_manifest.git -b voltage-14 .repo/local_manifests
```

## Sync the repository
```bash
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

### Apply the patches
Copy the patches folder to the ROM folder and copy the apply-patches.sh to the rom folder. and run this in the ROM folder:
```bash
apply-patches.sh . trebledroid
```

Run the above command replacing trebledroid for each folder in the patches directory

#### NOTE: It is recommended to apply patches manually by going to the respective directory of the patches, and applying them by using `git am`, as the script often skips applying critical patches for some reason.

## Adapting for VoltageOS
Clone this repository and then copy Voltage.mk to device/phh/treble in the ROM folder. Then run the following commands:
```bash
 cd device/phh/treble
 bash generate.sh Voltage
```

### Turn On Caching
You can speed up subsequent builds by adding these lines to your `~/.bashrc` OR `~/.zshrc` file:

```bash
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
```

### Reduce File Sizes
```Makefile
BOARD_EXT4_SHARE_DUP_BLOCKS := true
```
This flag makes the blocks shared, and makes the build read-only. It ensures it fits on to all possible Treble-supported devices, since many devices have a small system partitions.

## Compilation 
In the ROM folder, run this for building GAPPS:

```bash
. build/envsetup.sh
ccache -M 50G -F 0
lunch treble_arm64_bgN-userdebug 
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
For any other issues, report them via the [Issues](https://github.com/ahnet-69/treble_voltage/issues) tab.

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
