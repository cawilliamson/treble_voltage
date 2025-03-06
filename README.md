# VoltageOS GSI Build System

This repository contains a containerized build system for VoltageOS GSI images using container technology.

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

Here are the available targets:

## Makefile targets

<!-- BEGIN_MAKE_TARGETS -->
The build system now supports running individual steps independently, similar to GitHub Actions workflow:

### Container Management
- `build-container`: Build the container image
- `clean`: Clean build directories

### Individual Build Steps
- `clone-rom-manifest`: Clone the ROM manifest repository
- `copy-manifest-config`: Copy manifest configuration files
- `sync-sources`: Sync all source code (with auto-retry)
- `apply-patches`: Apply trebledroid and personal patches
- `apply-debug-patches`: Apply debug patches (if APPLY_DEBUG_PATCHES=true)
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
- `full-build`: Run the complete build process
- `all`: Default target, builds all standard variants
<!-- END_MAKE_TARGETS -->

## Configuration

You can customize the build process with the following variables:

```bash
make APPLY_DEBUG_PATCHES=true
```

Available variables:

- `ROM_NAME`: Name of the ROM (default: VoltageOS)
- `ROM_VERSION`: Version of the ROM (default: 4.2)
- `APPLY_DEBUG_PATCHES`: Whether to apply debug patches (default: false)
- `MAX_CPU_PERCENT`: Maximum CPU usage in percent (default: 100)
- `MAX_MEM_PERCENT`: Maximum memory usage in percent (default: 100)
- `CONTAINER_RUNTIME`: Container runtime to use (default: podman, can be set to docker)
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
This will use 50% of available CPU cores and 75% of available memory.

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

To run the VNDK sepolicy tests:

```bash
make vndk-test-sepolicy
```

To apply patches and then build the Treble app:

```bash
make apply-patches apply-debug-patches build-treble-app
```

#### Resuming a Failed Build

If a build fails at a specific step, you can resume from that step. For example, if the build fails during the source sync:

```bash
# First, ensure the container is built
make build-container

# Then resume from the sync step
make sync-sources apply-patches stash-gapps-variants generate-signing-keys build-treble-app
# ... continue with the remaining steps
```

### Build Process Flow

The typical build process follows these steps:

1. Container preparation
   - `build-container`

2. Source code preparation
   - `clone-rom-manifest`
   - `copy-manifest-config`
   - `sync-sources`
   - `apply-patches`
   - `apply-debug-patches`

3. Build preparation
   - `stash-gapps-variants`
   - `generate-signing-keys`
   - `build-treble-app`

4. Building images
   - `build-vanilla-arm64` (and other variants)
   - `vndk-test-sepolicy`

5. Post-processing
   - `rename-images`
   - `compress-images`

## Output

The built images will be available in the `out` directory.

## Credits

- [VoltageOS Team](https://github.com/VoltageOS)
- [Phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [Ponces](https://github.com/ponces)
- And all other contributors to the project
