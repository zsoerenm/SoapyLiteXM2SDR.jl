# SoapyLiteXM2SDR.jl

Julia package providing SoapySDR driver for the [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) PCIe-based Software Defined Radio hardware.

## Overview

This package automatically builds the SoapySDR driver for LiteX M2SDR hardware using Julia's JLL artifact system. The driver links against Julia's `soapysdr_jll` artifact, ensuring full compatibility with Julia's SoapySDR ecosystem.
Unfortunately, it cannot be built with Yggdrasil, because the source code depends on Linux kernel headers.

### Key Features

- ✅ **Zero Configuration**: Automatically downloads source from GitHub during build
- ✅ **Pure Julia Build System**: All build tools can come from JLL packages (no system dependencies required!)
- ✅ **Proper Artifact Integration**: Links against `soapysdr_jll`, not system libraries
- ✅ **Reproducible Builds**: Pins to specific commit hash
- ✅ **Best Practices**: Uses Scratch spaces for build artifacts

## Quick Start

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/SoapyLiteXM2SDR.jl")
```

The package will automatically:
1. Clone the LiteX M2SDR repository from GitHub
2. Build user libraries (liblitepcie, libm2sdr, libad9361)
3. Build the SoapySDR driver module
4. Install to a scratch directory

## Installation

### Requirements

- **Operating System**: Linux (LiteX M2SDR requires LitePCIe kernel driver)
- **Hardware**: LiteX M2SDR PCIe card (for actual usage)

### Build Dependencies

The package uses JLL packages for all build tools:
- `soapysdr_jll` - SoapySDR library
- `CMake_jll` - CMake build system
- `GNUMake_jll` - GNU Make
- `GCCBootstrap_jll` - GCC compiler toolchain

### Installation Steps

#### 1. Add the Package

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/SoapyLiteXM2SDR.jl")
```

The build process will take a few minutes to download source code (~20 MB) and compile everything.

#### 2. Verify Installation

```julia
using SoapyLiteXM2SDR

# Get module path
module_path = SoapyLiteXM2SDR.get_module_path()
println("Driver installed at: $module_path")

# Verify it exists
@assert isfile(module_path) "Build failed - module not found"
```

#### 3. Using with SoapySDR.jl

The driver integrates seamlessly with [SoapySDR.jl](https://github.com/JuliaTelecom/SoapySDR.jl):

**Automatic Loading (Recommended):**
```julia
using SoapySDR, SoapyLiteXM2SDR
# The driver is automatically loaded! No environment variables needed.
```

**Manual Loading (Alternative):**
```julia
using SoapySDR, SoapyLiteXM2SDR
SoapySDR.Modules.load_module(SoapyLiteXM2SDR.libSoapyLiteXM2SDR)
```

## Usage

### Basic API

```julia
using SoapyLiteXM2SDR

# Get the path to the built driver module
module_path = SoapyLiteXM2SDR.get_module_path()
# => "/home/user/.julia/scratchspaces/.../libSoapyLiteXM2SDR.so"

# Get the installation directory
install_dir = SoapyLiteXM2SDR.get_install_dir()
# => "/home/user/.julia/scratchspaces/.../install"
```

### Using with SoapySDR Tools

If you have SoapySDR utilities installed:

```bash
# Set plugin path
export SOAPY_SDR_PLUGIN_PATH=$(julia -e 'using SoapyLiteXM2SDR; println(dirname(SoapyLiteXM2SDR.get_module_path()))')

# List all available drivers
SoapySDRUtil --find

# Probe the LiteX M2SDR driver (requires hardware)
SoapySDRUtil --probe="driver=litexm2sdr"
```

### Hardware Setup

For actual usage with LiteX M2SDR hardware:

**Install LitePCIe kernel driver and load the kernel** - See [litex_m2sdr documentation](https://github.com/enjoy-digital/litex_m2sdr)

## Technical Details

### Build Process

The build process uses Julia's `deps/build.jl` mechanism:

1. **Source Acquisition**: Clones [litex_m2sdr](https://github.com/enjoy-digital/litex_m2sdr) to a Scratch space and checks out commit `f2bc24fdb1228c3d86387959a93a5c2e75ba97bf`

2. **User Library Build**: Compiles three static libraries using GNUMake_jll:
   - `liblitepcie.a` - PCIe communication library
   - `libm2sdr.a` - M2SDR hardware control library
   - `libad9361_m2sdr.a` - AD9361 RF transceiver library

3. **SoapySDR Module Build**: Uses CMake_jll and GCCBootstrap_jll to build `libSoapyLiteXM2SDR.so` with:
   - Source: `litex_m2sdr/software/soapysdr`
   - Linked against: `soapysdr_jll` artifact
   - RPATH: Set to soapysdr_jll library directory
   - Backend: USE_LITEPCIE

4. **Installation**: Installs to scratch directory and generates `deps/deps.jl` with paths

### CMake Configuration

```cmake
CMAKE_BUILD_TYPE=Release
CMAKE_INSTALL_PREFIX=<scratch_dir>/install
CMAKE_PREFIX_PATH=<soapysdr_jll_artifact_dir>
CMAKE_INSTALL_RPATH=<soapysdr_jll_lib_dir>
CMAKE_BUILD_WITH_INSTALL_RPATH=ON
USE_LITEETH=OFF
```

### Why RPATH Matters

The `CMAKE_INSTALL_RPATH` ensures the driver links to Julia's `soapysdr_jll` artifact rather than any system-wide SoapySDR. Verify with:

```bash
ldd <module_path> | grep SoapySDR
# Should show: libSoapySDR.so.0.8 => /home/user/.julia/artifacts/.../lib/libSoapySDR.so.0.8
```

### Scratch Spaces

The package uses [Scratch.jl](https://github.com/JuliaPackaging/Scratch.jl) to store build artifacts outside the package directory (Julia best practice):

```
<scratch_space>/build/
├── litex_m2sdr/          # Cloned git repository
├── build_soapy/          # CMake build directory
└── install/              # Installation directory
    └── lib/SoapySDR/modules0.8/
        └── libSoapyLiteXM2SDR.so
```

## Troubleshooting

### Rebuilding

To rebuild the driver:
```julia
using Pkg
Pkg.build("SoapyLiteXM2SDR")
```

### Complete Rebuild from Scratch

```julia
using Scratch
scratch_dir = @get_scratch!("build")
rm(scratch_dir, recursive=true, force=true)

using Pkg
Pkg.build("SoapyLiteXM2SDR")
```

### Build Failures

Check the build log:
```julia
using Pkg
Pkg.build("SoapyLiteXM2SDR"; verbose=true)
```

Common issues:
- **Module not found after build**: The build may have failed silently - check verbose output
- **Compilation errors**: Ensure all JLL dependencies are properly installed

### Verification

Verify the module links to JLL artifacts correctly:
```bash
ldd $(julia -e 'using SoapyLiteXM2SDR; println(SoapyLiteXM2SDR.get_module_path())') | grep -i soapy
```

## Package Structure

```
SoapyLiteXM2SDR/
├── Project.toml              # Package metadata and dependencies
├── Manifest.toml             # Locked dependency versions
├── README.md                 # This file
├── src/
│   └── SoapyLiteXM2SDR.jl   # Main module with API functions
├── deps/
│   ├── build.jl             # Build script (runs during Pkg.build)
│   └── deps.jl              # Generated file with paths
```

## Limitations

1. **Native Build Only**: Does not cross-compile for other platforms
2. **Linux-Specific**: LiteX M2SDR hardware requires Linux kernel drivers (LitePCIe)

## Future Enhancements

Potential improvements:
1. Support for USE_LITEETH backend option
2. Platform-specific builds (if M2SDR supports other platforms)
3. High-level Julia wrapper for SDR operations
4. Binary artifact caching to speed up rebuilds
5. Support for multiple upstream versions/commits

## Getting Help

- **LiteX M2SDR Issues**: https://github.com/enjoy-digital/litex_m2sdr/issues
- **SoapySDR Issues**: https://github.com/pothosware/SoapySDR/issues
- **This Package Issues**: File issues in the package repository

## License

This package is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Note: This package builds and links against the [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) project, which has its own license. Users should comply with the licenses of all dependencies.

## Acknowledgments

- [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) - Hardware and driver by enjoy-digital
- [SoapySDR](https://github.com/pothosware/SoapySDR) - SDR abstraction layer
- Julia JLL packages for providing hermetic build tools
