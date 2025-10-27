# SoapyLiteXM2SDR.jl

Julia package providing a SoapySDR driver for the [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) PCIe-based Software Defined Radio hardware.

## Overview

This package automatically builds the SoapySDR driver and kernel module for LiteX M2SDR hardware. It uses Julia's build system and JLL artifacts to provide a seamless installation experience.

### Key Features

- ✅ **Automatic Build**: Downloads source and builds both kernel driver and SoapySDR module
- ✅ **Pure Julia Build System**: All build tools from JLL packages (no manual dependencies!)
- ✅ **Kernel Module Management**: Helper functions to load/unload the kernel driver
- ✅ **Proper Integration**: Links against Julia's `soapysdr_jll` artifact
- ✅ **Reproducible**: Pins to specific upstream commit hash

## Prerequisites

### Hardware
- LiteX M2SDR PCIe card installed in an M.2 slot
- RF antennas connected to the board

### IOMMU Configuration (Critical!)

Some systems require specific IOMMU settings for proper PCIe communication. Add these kernel boot parameters:

Please refer to [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr)

## Installation

### Step 1: Install the Julia Package

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/SoapyLiteXM2SDR.jl")
```

The package will automatically:
1. Clone the LiteX M2SDR repository from GitHub
2. Build user libraries (`liblitepcie`, `libm2sdr`, `libad9361`)
3. Build the kernel module (`m2sdr.ko`) if kernel headers are available
4. Build the SoapySDR driver module (`libSoapyLiteXM2SDR.so`)
5. Install everything to a Julia scratch directory

**Note**: The build process takes a few minutes and requires ~20 MB download.

### Step 2: Verify Installation

```julia
using SoapyLiteXM2SDR

# Get module paths
module_path = SoapyLiteXM2SDR.get_module_path()
println("SoapySDR driver: $module_path")

kernel_path = SoapyLiteXM2SDR.get_kernel_module_path()
println("Kernel module: $kernel_path")
```

### Step 3: Load the Kernel Module

**Option A: Using Julia (Recommended)**
```julia
using SoapyLiteXM2SDR

# Check kernel module status
SoapyLiteXM2SDR.kernel_module_info()

# Load the kernel module (will prompt for sudo password)
SoapyLiteXM2SDR.install_kernel_module()
```

**Option B: Manual Loading**
```bash
# Get the kernel module path
julia -e 'using SoapyLiteXM2SDR; println(SoapyLiteXM2SDR.get_kernel_module_path())'

# Load it manually
sudo insmod /path/to/m2sdr.ko

# Verify it loaded
lsmod | grep m2sdr
dmesg | tail -20  # Check for hardware detection messages
```

### Step 4: Use with SoapySDR

**In Julia:**
```julia
using SoapySDR, SoapyLiteXM2SDR
# The driver is automatically loaded!

# List available devices
devices = SoapySDR.Devices()
println("Available SDR devices: ", devices)
```

**With command-line tools:**
```bash
# Set plugin path (if needed)
export SOAPY_SDR_PLUGIN_PATH=$(julia -e 'using SoapyLiteXM2SDR; println(dirname(SoapyLiteXM2SDR.get_module_path()))')

# List all drivers
SoapySDRUtil --find

# Probe the LiteX M2SDR
SoapySDRUtil --probe="driver=litexm2sdr"
```

## Usage

### Basic API

```julia
using SoapyLiteXM2SDR

# SoapySDR module path
module_path = SoapyLiteXM2SDR.get_module_path()
# => "/home/user/.julia/scratchspaces/.../libSoapyLiteXM2SDR.so"

# Installation directory
install_dir = SoapyLiteXM2SDR.get_install_dir()
# => "/home/user/.julia/scratchspaces/.../install"

# Kernel module path
kernel_path = SoapyLiteXM2SDR.get_kernel_module_path()
# => "/home/user/.julia/scratchspaces/.../m2sdr.ko"

# Check kernel module status
SoapyLiteXM2SDR.kernel_module_info()

# Load kernel module (requires sudo and hardware)
SoapyLiteXM2SDR.install_kernel_module()

# Unload kernel module
SoapyLiteXM2SDR.uninstall_kernel_module()
```

### Kernel Module Management

**Check if module is loaded:**
```julia
using SoapyLiteXM2SDR
SoapyLiteXM2SDR.is_kernel_module_loaded()  # Returns true/false
```

**Detailed status information:**
```julia
SoapyLiteXM2SDR.kernel_module_info()
# Displays:
# - Kernel module path
# - Whether module exists
# - Whether module is loaded
# - Module information (if loaded)
```

**Unload the module:**
```julia
# Using Julia
SoapyLiteXM2SDR.uninstall_kernel_module()

# Or manually
run(`sudo rmmod m2sdr`)
```

## Troubleshooting

### Kernel Module Build Failed

If the kernel module didn't build:

1. **Check kernel headers are installed:**
   ```bash
   ls /usr/lib/modules/$(uname -r)/build
   # Should show kernel source files
   ```

2. **Verify running kernel matches installed headers:**
   ```bash
   uname -r  # Shows running kernel version
   ls /usr/lib/modules/  # Shows available kernel header versions
   ```

   **Important**: The kernel module must be built against headers matching the *running* kernel version. If you've recently updated your system but haven't rebooted, the headers might be for a newer kernel version than what's currently running.

3. **Install matching headers:**
   ```bash
   # Arch
   sudo pacman -S linux-headers

   # Ubuntu/Debian
   sudo apt install linux-headers-$(uname -r)
   ```

4. **Reboot if kernel was updated:**
   If headers were just installed/updated and don't match your running kernel:
   ```bash
   sudo reboot
   ```

   After reboot, rebuild the package:
   ```julia
   using Pkg
   Pkg.build("SoapyLiteXM2SDR")
   ```

### Hardware Not Detected

If `dmesg` doesn't show the hardware after loading the module:

1. **Verify IOMMU settings:**
   ```bash
   dmesg | grep -i iommu
   # Should show passthrough mode
   ```

2. **Check PCIe connection:**
   ```bash
   lspci | grep -i xilinx
   # Should show Xilinx device
   ```

3. **Check kernel messages:**
   ```bash
   sudo dmesg | tail -50
   # Look for m2sdr or litex messages
   ```

### Complete Rebuild

To completely rebuild from scratch:

```julia
using Scratch
scratch_dir = @get_scratch!("SoapyLiteXM2SDR-build")
rm(scratch_dir, recursive=true, force=true)

using Pkg
Pkg.build("SoapyLiteXM2SDR")
```

### Build Log

Check the detailed build log:
```julia
using Pkg
Pkg.build("SoapyLiteXM2SDR"; verbose=true)
```

Or read the log file:
```julia
log_path = joinpath(dirname(pathof(SoapyLiteXM2SDR)), "..", "deps", "build.log")
println(read(log_path, String))
```

## Technical Details

### Build Process

The package uses Julia's `deps/build.jl` mechanism:

1. **Source Acquisition**: Clones [litex_m2sdr](https://github.com/enjoy-digital/litex_m2sdr) and checks out commit `086cf3c0922fc954ca578218678c4f7928ea5b84`

2. **User Library Build**: Compiles three static libraries using GNUMake_jll:
   - `liblitepcie.a` - PCIe communication library
   - `libm2sdr.a` - M2SDR hardware control library
   - `libad9361_m2sdr.a` - AD9361 RF transceiver library

3. **Kernel Driver Build**: Builds the LiteX M2SDR kernel module (`m2sdr.ko`):
   - Source: `litex_m2sdr/software/kernel`
   - Requires Linux kernel headers
   - Non-critical: Build continues if kernel headers are unavailable

4. **SoapySDR Module Build**: Uses CMake_jll and GCCBootstrap_jll to build `libSoapyLiteXM2SDR.so`:
   - Source: `litex_m2sdr/software/soapysdr`
   - Linked against: `soapysdr_jll` artifact
   - RPATH: Set to soapysdr_jll library directory
   - Backend: USE_LITEPCIE

5. **Installation**: Installs to scratch directory and generates `deps/deps.jl` with paths

### CMake Configuration

```cmake
CMAKE_BUILD_TYPE=Release
CMAKE_INSTALL_PREFIX=<scratch_dir>/install
CMAKE_PREFIX_PATH=<soapysdr_jll_artifact_dir>
CMAKE_INSTALL_RPATH=<soapysdr_jll_lib_dir>
CMAKE_BUILD_WITH_INSTALL_RPATH=ON
USE_LITEETH=OFF
```

### RPATH Configuration

The `CMAKE_INSTALL_RPATH` ensures the driver links to Julia's `soapysdr_jll` artifact rather than system-wide SoapySDR. Verify with:

```bash
ldd $(julia -e 'using SoapyLiteXM2SDR; println(SoapyLiteXM2SDR.get_module_path())') | grep SoapySDR
# Should show: libSoapySDR.so.0.8 => /home/user/.julia/artifacts/.../lib/libSoapySDR.so.0.8
```

### Scratch Spaces

The package uses [Scratch.jl](https://github.com/JuliaPackaging/Scratch.jl) to store build artifacts:

```
<scratch_space>/SoapyLiteXM2SDR-build/
├── litex_m2sdr/                          # Cloned git repository
│   └── litex_m2sdr/software/kernel/
│       └── m2sdr.ko                      # Kernel module (built in place)
├── build_soapy/                          # CMake build directory
└── install/                              # Installation directory
    └── lib/SoapySDR/modules0.8/
        └── libSoapyLiteXM2SDR.so
```

### Kernel Module Details

The `m2sdr.ko` module includes:
- **LitePCIe** driver - PCIe interface (vendor 0x10EE)
- **LiteUART** driver - Serial communication
- **LiteSATA** driver - Block device support

Module parameters:
- `force_polling` - Force polling mode (ignore MSI)
- `msi_timeout_ms` - MSI timeout in milliseconds
- `irq_arm_delay_us` - IRQ arming delay in microseconds
- `early_poll_us` - Early polling window in microseconds
- `strict_32bit` - Require 32-bit DMA addressing
- `force_bounce` / `no_bounce` - DMA buffer handling

## Package Structure

```
SoapyLiteXM2SDR.jl/
├── Project.toml              # Package metadata and dependencies
├── LICENSE                   # MIT License
├── README.md                 # This file
├── src/
│   └── SoapyLiteXM2SDR.jl   # Main module with API functions
├── deps/
│   ├── build.jl             # Build script (runs during Pkg.build)
│   └── deps.jl              # Generated file with paths (gitignored)
└── test/
    ├── runtests.jl          # Main test runner
    ├── module_tests.jl      # Module API tests
    └── build_tests.jl       # Build system tests
```

## Limitations

1. **Linux Only**: LiteX M2SDR hardware requires Linux kernel drivers
2. **No Cross-compilation**: Builds for the host system only
3. **Requires Kernel Headers**: Kernel module build needs matching headers
4. **IOMMU Required**: Hardware needs IOMMU passthrough mode

## Related Projects

- [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) - Hardware design and drivers
- [SoapySDR](https://github.com/pothosware/SoapySDR) - SDR abstraction layer
- [SoapySDR.jl](https://github.com/JuliaTelecom/SoapySDR.jl) - Julia SoapySDR bindings

## Getting Help

- **LiteX M2SDR Hardware**: https://github.com/enjoy-digital/litex_m2sdr/issues
- **SoapySDR Issues**: https://github.com/pothosware/SoapySDR/issues
- **This Package**: File issues on GitHub

## License

This package is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Note: This package builds and links against [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr), which has its own license. Users should comply with the licenses of all dependencies.

## Acknowledgments

- [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) - Hardware and drivers by enjoy-digital
- [SoapySDR](https://github.com/pothosware/SoapySDR) - SDR abstraction layer
- Julia JLL packages for providing hermetic build tools
