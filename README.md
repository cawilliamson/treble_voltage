# VoltageOS GSI Build System

This repository contains a containerized build system for VoltageOS GSI (Generic System Image) images using container technology. It automates the entire build process from source preparation to final image compression.

## Prerequisites

- [Podman](https://podman.io/) or [Docker](https://www.docker.com/)
- At least 200GB of free disk space
- At least 16GB of RAM (32GB recommended)
- A fast internet connection

## Usage

The build system uses a single comprehensive Makefile to orchestrate the build process. The Makefile contains all configuration, variables, and build targets in one file for simplicity.

### Makefile Structure

The build system is organized in a clear, sequential manner:

1. Configuration variables and resource limits at the top
2. Common container parameters and phony target definitions
3. Convenience targets for different build combinations
4. Individual build steps in sequential order with clear headers

This consolidated structure makes it easier to:
- Understand the entire build process at a glance
- Follow the build flow from start to finish
- See all dependencies and relationships between targets

## Makefile Targets

<!-- BEGIN_MAKE_TARGETS -->
The build system supports running individual steps independently, similar to GitHub Actions workflow:

### Container Management
- `build-container`: Build the container image
- `clean`: Clean build directories
- `create-folders`: Create necessary build directories

### Individual Build Steps
- `clone-rom-manifest`: Clone the ROM manifest repository
- `copy-manifest-config`: Copy manifest configuration files
- `sync-sources`: Sync all source code (with auto-retry)
- `apply-patches`: Apply trebledroid and personal patches (includes debug patches if APPLY_DEBUG_PATCHES=true)
- `stash-gapps-variants`: Setup temporary directory and stash GApps variants
- `generate-signing-keys`: Generate signing keys for the build
- `build-treble-app`: Build the Treble app
- `vndk-test-sepolicy`: Run VNDK sepolicy tests

### Build Targets for Different Variants
- `build-vanilla-arm64`: Build vanilla arm64 image
- `build-microg-arm64`: Build microG arm64 image
- `build-gapps-arm64`: Build GApps arm64 image
- `build-vanilla-a64`: Build vanilla arm32_binder64 image
- `build-microg-a64`: Build microG arm32_binder64 image
- `build-gapps-a64`: Build GApps arm32_binder64 image

### Post-Processing
- `rename-images`: Rename all image files to final names
- `compress-images`: Compress all images with xz

### Convenience Targets
- `build-vanilla`: Build all vanilla variants
- `build-microg`: Build all microG variants
- `build-gapps`: Build all GApps variants
- `build-arm64`: Build all arm64 variants
- `build-a64`: Build all arm32_binder64 variants
- `all-images`: Build all images without source preparation
- `build-prerequisites`: Run all build prerequisites (container, folders, clone, sync, patches, etc.)
- `post-build`: Run all post-build steps (testing, renaming, compression)
- `full-build`: Run the complete build process (default target)
<!-- END_MAKE_TARGETS -->

## Configuration

You can customize the build process with the following variables:

```bash
# Example of using multiple configuration variables
make ROM_VERSION=4.3 ROM_TAG=16-qpr1 ANDROID_VERSION_TAG=ap4b APPLY_DEBUG_PATCHES=true VERIFY_SEPOLICY=true MAX_CPU_PERCENT=50 CONTAINER_RUNTIME=docker
```

Available variables:

- `ROM_VERSION`: Version of the ROM (default: 4.2)
- `ROM_TAG`: Git tag/branch to use for ROM source (default: 15-qpr1)
- `ANDROID_VERSION_TAG`: Android version tag for the build (default: ap4a)
- `APPLY_DEBUG_PATCHES`: Whether to apply debug patches (default: false)
- `VERIFY_SEPOLICY`: Whether to verify SELinux policy during build (default: true)
- `MAX_CPU_PERCENT`: Maximum CPU usage in percent (default: 100)
- `MAX_MEM_PERCENT`: Maximum memory usage in percent (default: 100)
- `CONTAINER_RUNTIME`: Container runtime to use (default: podman, can be set to docker)
## Android Version Tag

The `ANDROID_VERSION_TAG` variable specifies the Android version tag used for the build. This affects how the ROM is built and which Android version features are included.

```bash
make ANDROID_VERSION_TAG=ap4b
```

The default value is `ap4a` which corresponds to Android 15.

## Resource Limits

You can limit CPU and memory usage with:

```bash
make MAX_CPU_PERCENT=50 MAX_MEM_PERCENT=75
```

This will use 50% of available CPU cores and 75% of available memory.

## Container Runtime

By default, the build system uses Podman. To use Docker instead:

```bash
make CONTAINER_RUNTIME=docker
```

You can also set this for specific targets:

```bash
make CONTAINER_RUNTIME=docker build-vanilla-arm64
```

## Running Independent Build Steps

One of the key features of this build system is the ability to run individual build steps independently, similar to GitHub Actions workflow. This allows you to:

1. Run specific parts of the build process
2. Resume a build from a specific step if it fails
3. Test individual components without running the entire build

### Examples

#### Running a Complete Build

To run the complete build process:

```bash
make full-build
```

#### Building Only Specific Variants

To build only the vanilla arm64 variant:

```bash
make build-vanilla-arm64
```

To build all microG variants:

```bash
make build-microg
```

#### Running Specific Steps

To run the VNDK sepolicy tests (which can be controlled with the VERIFY_SEPOLICY variable):

```bash
make VERIFY_SEPOLICY=true vndk-test-sepolicy
```

To apply patches and then build the Treble app:

```bash
make apply-patches apply-debug-patches build-treble-app
```

#### Resuming a Failed Build

If a build fails at a specific step, you can resume from that step. For example, if the build fails during the source sync:

```bash
# First, ensure the container and folders are ready
make build-container create-folders

# Then resume from the sync step
make sync-sources apply-patches stash-gapps-variants generate-signing-keys build-treble-app
# ... continue with the remaining steps
```

Alternatively, you can use the convenience targets:

```bash
# If you need to resume after the prerequisites
make build-prerequisites all-images post-build

# Or if you just need to rebuild the images
make all-images post-build
```
### Build Process Flow

The typical build process follows these steps:

1. Container preparation
   - `build-container`
   - `create-folders`

2. Source code preparation
   - `clone-rom-manifest`
   - `copy-manifest-config`
   - `sync-sources`
   - `apply-patches` (includes debug patches if APPLY_DEBUG_PATCHES=true)

3. Build preparation
   - `stash-gapps-variants`
   - `generate-signing-keys`
   - `build-treble-app`

4. Building images
   - `build-vanilla-arm64` (and other variants)
   - Or use `all-images` to build all variants

5. Post-build processing
   - `vndk-test-sepolicy`
   - `rename-images`
   - `compress-images`
   - Or use `post-build` to run all post-build steps

For convenience, you can use:
- `build-prerequisites`: Run all steps from container preparation through build preparation
- `full-build`: Run the complete build process (default target)
   - `compress-images`

The built images are initially created in the `tmp` directory and then copied to the `out` directory after compression.

## Output

The built images are initially created in the `tmp` directory during the build process. After compression with xz, the final image files (with .img.xz extension) are copied to the `out` directory.

The final image filenames follow this format:
`VoltageOS-[variant]-[architecture]-ab-[version]-[build_date]-UNOFFICIAL.img.xz`

Where:
- `[variant]` is one of: vanilla, microg, or gapps
- `[architecture]` is one of: arm64 or arm32_binder64
- `[version]` is the ROM version (e.g., 4.2)
- `[build_date]` is the date of the build in YYYYMMDD format

For example:
`VoltageOS-vanilla-arm64-ab-4.2-20250603-UNOFFICIAL.img.xz`

## Patches

The build system applies several sets of patches to the VoltageOS source code:

### Trebledroid Patches
These patches come from the TrebleDroid project and provide essential fixes and improvements for GSI compatibility across various devices. They address issues with hardware support, SELinux policies, and vendor compatibility.

### Personal Patches
These are custom patches that enhance the ROM with additional features and fixes specific to this build system. They include:
- UI/UX improvements
- Performance optimizations
- Additional device support
- Feature enhancements

### Debug Patches (Optional)
When enabled with `APPLY_DEBUG_PATCHES=true`, these patches add debugging capabilities that can help troubleshoot issues on specific devices.

## Credits

- [VoltageOS Team](https://github.com/VoltageOS)
- [Phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [Ponces](https://github.com/ponces)
- [TrebleDroid Project](https://github.com/TrebleDroid)
- And all other contributors to the project
