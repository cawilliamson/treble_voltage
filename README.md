# VoltageOS GSI Build System

This repository contains a containerized build system for VoltageOS GSI images using Podman.

## Prerequisites

- [Podman](https://podman.io/)
- At least 200GB of free disk space
- At least 16GB of RAM (32GB recommended)
- A fast internet connection

## Usage

The build system uses a Makefile to orchestrate the build process. Here are the available targets:

### Build Everything

```bash
make
```

This will build the container image and all GSI variants (vanilla, microG, GApps, and vndklite).

### Build Container Image Only

```bash
make build-container
```

### Build Specific GSI Variants

```bash
make build-vanilla    # Build vanilla GSI
make build-microg     # Build microG GSI
make build-gapps      # Build GApps GSI
make build-vndklite   # Build vndklite variants
```

### Clean Build Directories

```bash
make clean
```

## Configuration

You can customize the build process with the following variables:

```bash
make ROM_NAME=VoltageOS ROM_VERSION=4.3 MAINTAINER=yourusername REPO_NAME=your-repo
```

Available variables:

- `ROM_NAME`: Name of the ROM (default: VoltageOS)
- `ROM_VERSION`: Version of the ROM (default: 4.2)
- `MAINTAINER`: GitHub username of the maintainer (default: cawilliamson)
- `REPO_NAME`: Repository name (default: treble_voltage)
- `APPLY_DEBUG_PATCHES`: Whether to apply debug patches (default: true)
- `OUTPUT_DIR`: Directory for output files (default: ./output)
- `MAX_CPU_PERCENT`: Maximum CPU usage in percent (default: 100)
- `MAX_MEM_PERCENT`: Maximum memory usage in percent (default: 100)

## Resource Limits

You can limit CPU and memory usage with:

```bash
make MAX_CPU_PERCENT=50 MAX_MEM_PERCENT=75
```

This will use 50% of available CPU cores and 75% of available memory.

## Output

The built images will be available in the `output` directory (or the directory specified by `OUTPUT_DIR`).

## Credits

- [VoltageOS Team](https://github.com/VoltageOS)
- [Phhusson](https://github.com/phhusson)
- [AndyYan](https://github.com/AndyCGYan)
- [Ponces](https://github.com/ponces)
- And all other contributors to the project
