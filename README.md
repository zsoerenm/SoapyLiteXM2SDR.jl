# SoapyLiteXM2SDR.jl

Julia package providing a SoapySDR driver for the [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) PCIe-based Software Defined Radio hardware.

## Prerequisites

- **Hardware**: LiteX M2SDR PCIe card installed in an M.2 slot
- **Linux kernel headers**: Required for building the kernel module
- **IOMMU configuration**: See [LiteX M2SDR docs](https://github.com/enjoy-digital/litex_m2sdr) for kernel boot parameters

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/zsoerenm/SoapyLiteXM2SDR.jl")
```

The package automatically builds:
- User libraries (`liblitepcie`, `libm2sdr`, `libad9361`)
- Kernel module (`m2sdr.ko`) if kernel headers are available
- SoapySDR driver module (`libSoapyLiteXM2SDR.so`)

## Usage

### Load the Kernel Module

```julia
using SoapyLiteXM2SDR

# Check status (shows distro-specific install instructions if headers are missing)
SoapyLiteXM2SDR.kernel_module_info()

# Load the kernel module and install udev rule (prompts for sudo password)
SoapyLiteXM2SDR.install_kernel_module()
```

This automatically:
- Loads the `ptp` dependency module
- Inserts the `m2sdr` kernel module
- Installs udev rule (`/etc/udev/rules.d/99-m2sdr.rules`) for non-root device access

### Use with SoapySDR

```julia
using SoapySDR, SoapyLiteXM2SDR

# List available devices
devices = SoapySDR.Devices()
```

### API Reference

```julia
SoapyLiteXM2SDR.get_module_path()         # Path to SoapySDR driver
SoapyLiteXM2SDR.get_kernel_module_path()  # Path to kernel module
SoapyLiteXM2SDR.is_kernel_module_loaded() # Check if loaded
SoapyLiteXM2SDR.install_kernel_module()   # Load module + udev rule (requires sudo)
SoapyLiteXM2SDR.uninstall_kernel_module() # Unload module (requires sudo)
SoapyLiteXM2SDR.install_udev_rule()       # Install udev rule only (requires sudo)
SoapyLiteXM2SDR.uninstall_udev_rule()     # Remove udev rule (requires sudo)
SoapyLiteXM2SDR.kernel_module_info()      # Display detailed status
```

## Troubleshooting

### Kernel Module Build Failed

The package automatically detects your Linux distribution and provides specific installation instructions. Run:

```julia
using SoapyLiteXM2SDR
SoapyLiteXM2SDR.kernel_module_info()
```

This will show instructions like:
- **Arch/Manjaro**: `sudo pacman -S linux-headers`
- **Ubuntu/Debian**: `sudo apt install linux-headers-$(uname -r)`
- **Fedora**: `sudo dnf install kernel-devel kernel-headers`
- **openSUSE**: `sudo zypper install kernel-devel`

After installing headers, rebuild:

```julia
using Pkg
Pkg.build("SoapyLiteXM2SDR")
```

**Note**: If you recently updated your kernel, reboot first so the running kernel matches the installed headers.

### Hardware Not Detected

1. Verify IOMMU: `dmesg | grep -i iommu`
2. Check PCIe: `lspci | grep -i xilinx`
3. Check kernel messages: `sudo dmesg | tail -50`

### Complete Rebuild

```julia
using Scratch
rm(@get_scratch!("SoapyLiteXM2SDR-build"), recursive=true, force=true)

using Pkg
Pkg.build("SoapyLiteXM2SDR")
```

## Related Projects

- [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr) - Hardware design and drivers
- [SoapySDR.jl](https://github.com/JuliaTelecom/SoapySDR.jl) - Julia SoapySDR bindings

## License

MIT License. See [LICENSE](LICENSE) for details.

This package builds against [LiteX M2SDR](https://github.com/enjoy-digital/litex_m2sdr), which has its own license.
