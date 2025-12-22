module SoapyLiteXM2SDR

using soapysdr_jll

"""
    detect_linux_distro()

Detect the Linux distribution. Returns a tuple (distro_id, distro_name).
The distro_id is a lowercase identifier like "ubuntu", "arch", "fedora", etc.
Returns ("unknown", "Unknown") if detection fails.
"""
function detect_linux_distro()
    # Try /etc/os-release first (most modern distros)
    if isfile("/etc/os-release")
        try
            content = read("/etc/os-release", String)
            id_match = match(r"^ID=(.*)$"m, content)
            name_match = match(r"^PRETTY_NAME=\"?([^\"\n]*)\"?"m, content)

            distro_id = id_match !== nothing ? lowercase(strip(id_match.captures[1], ['"', '\''])) : "unknown"
            distro_name = name_match !== nothing ? strip(name_match.captures[1]) : "Unknown"

            return (distro_id, distro_name)
        catch
        end
    end

    # Fallback detection methods
    if isfile("/etc/debian_version")
        return ("debian", "Debian-based")
    elseif isfile("/etc/redhat-release")
        return ("rhel", "Red Hat-based")
    elseif isfile("/etc/arch-release")
        return ("arch", "Arch Linux")
    end

    return ("unknown", "Unknown")
end

"""
    check_kernel_headers()

Check if kernel headers are available for the current kernel.
Returns (available::Bool, kernel_version::String, headers_path::String).
"""
function check_kernel_headers()
    kernel_version = try
        strip(read(`uname -r`, String))
    catch
        "unknown"
    end

    headers_path = "/lib/modules/$kernel_version/build"
    available = isdir(headers_path)

    return (available, kernel_version, headers_path)
end

"""
    kernel_headers_install_instructions()

Return instructions for installing kernel headers based on the detected distribution.
"""
function kernel_headers_install_instructions()
    distro_id, distro_name = detect_linux_distro()
    headers_available, kernel_version, _ = check_kernel_headers()

    if headers_available
        return "Kernel headers are already installed for kernel $kernel_version."
    end

    base_msg = "Kernel headers not found for kernel $kernel_version.\n\nTo install kernel headers"

    instructions = if distro_id in ("arch", "artix", "manjaro", "endeavouros")
        """
        $base_msg on $distro_name, run:
            sudo pacman -S linux-headers

        Note: If you're using a different kernel (e.g., linux-lts, linux-zen),
        install the corresponding headers package (e.g., linux-lts-headers, linux-zen-headers).
        """
    elseif distro_id in ("ubuntu", "debian", "linuxmint", "pop")
        """
        $base_msg on $distro_name, run:
            sudo apt install linux-headers-\$(uname -r)

        Or for all installed kernels:
            sudo apt install linux-headers-generic
        """
    elseif distro_id in ("fedora",)
        """
        $base_msg on $distro_name, run:
            sudo dnf install kernel-devel kernel-headers
        """
    elseif distro_id in ("rhel", "centos", "rocky", "almalinux", "oracle")
        """
        $base_msg on $distro_name, run:
            sudo yum install kernel-devel kernel-headers

        Or with dnf:
            sudo dnf install kernel-devel kernel-headers
        """
    elseif distro_id in ("opensuse", "opensuse-leap", "opensuse-tumbleweed", "sles")
        """
        $base_msg on $distro_name, run:
            sudo zypper install kernel-devel
        """
    elseif distro_id in ("gentoo",)
        """
        $base_msg on $distro_name:
        Ensure your kernel sources are installed and configured:
            sudo emerge sys-kernel/linux-headers

        Or if using a distribution kernel:
            sudo emerge sys-kernel/gentoo-kernel
        """
    elseif distro_id in ("nixos",)
        """
        $base_msg on $distro_name:
        Add the following to your configuration.nix:
            boot.kernelPackages = pkgs.linuxPackages;

        Then rebuild: sudo nixos-rebuild switch
        """
    elseif distro_id in ("alpine",)
        """
        $base_msg on $distro_name, run:
            sudo apk add linux-headers
        """
    else
        """
        $base_msg:
        Please install the kernel headers package for your distribution.
        Common package names include:
            - linux-headers (Arch-based)
            - linux-headers-\$(uname -r) (Debian/Ubuntu)
            - kernel-devel (Fedora/RHEL)

        Detected distribution: $distro_name (ID: $distro_id)
        """
    end

    return strip(instructions)
end

# Load the deps.jl file generated during build
const depsjl_path = joinpath(@__DIR__, "..", "deps", "deps.jl")
if !isfile(depsjl_path)
    error("""
    SoapyLiteXM2SDR not properly built. Please run:
        using Pkg
        Pkg.build("SoapyLiteXM2SDR")
    """)
end
include(depsjl_path)

# Expose the module path similar to JLL packages
# This allows SoapySDR.jl and other packages to discover the driver
const libSoapyLiteXM2SDR = module_path

"""
    get_module_path()

Return the path to the built SoapySDR module.
"""
get_module_path() = module_path

"""
    get_install_dir()

Return the installation directory of the SoapySDR driver.
"""
get_install_dir() = install_dir

"""
    get_kernel_module_path()

Return the path to the LiteX M2SDR kernel module (m2sdr.ko).
Returns `nothing` if the kernel module was not built.
"""
function get_kernel_module_path()
    if @isdefined(kernel_module_built) && kernel_module_built
        return kernel_module_path
    else
        return nothing
    end
end

"""
    is_kernel_module_loaded()

Check if the LitePCIe kernel module is currently loaded.
"""
function is_kernel_module_loaded()
    try
        lsmod_output = read(`lsmod`, String)
        return occursin("m2sdr", lsmod_output)
    catch
        return false
    end
end

"""
    install_kernel_module()

Install the LitePCIe kernel module. Requires sudo privileges.

# Example
```julia
using SoapyLiteXM2SDR

# This will prompt for sudo password
SoapyLiteXM2SDR.install_kernel_module()
```
"""
function install_kernel_module()
    kmod_path = get_kernel_module_path()

    if kmod_path === nothing
        instructions = kernel_headers_install_instructions()
        error("""
        Kernel module was not built.

        $instructions

        After installing kernel headers, rebuild the package with:
            using Pkg
            Pkg.build("SoapyLiteXM2SDR")
        """)
    end

    if !isfile(kmod_path)
        error("Kernel module not found at: $kmod_path")
    end

    println("Installing LitePCIe kernel module...")
    println("This requires sudo privileges and will prompt for your password.")

    try
        run(`sudo insmod $kmod_path`)
        println("✓ Kernel module installed successfully")

        # Verify it loaded
        if is_kernel_module_loaded()
            println("✓ Kernel module is loaded")
        else
            @warn "Kernel module installation succeeded but module not found in lsmod"
        end
    catch e
        error("Failed to install kernel module: $e")
    end
end

"""
    uninstall_kernel_module()

Uninstall the LitePCIe kernel module. Requires sudo privileges.
"""
function uninstall_kernel_module()
    if !is_kernel_module_loaded()
        println("Kernel module is not currently loaded")
        return
    end

    println("Uninstalling LitePCIe kernel module...")
    println("This requires sudo privileges and will prompt for your password.")

    try
        run(`sudo rmmod m2sdr`)
        println("✓ Kernel module uninstalled successfully")
    catch e
        error("Failed to uninstall kernel module: $e")
    end
end

"""
    kernel_module_info()

Display information about the LitePCIe kernel module.
"""
function kernel_module_info()
    kmod_path = get_kernel_module_path()
    loaded = is_kernel_module_loaded()

    println("LitePCIe Kernel Module Status")
    println("="^50)

    if kmod_path === nothing
        println("✗ Kernel module: Not built")
        println()
        println(kernel_headers_install_instructions())
        println()
        println("After installing kernel headers, rebuild with: Pkg.build(\"SoapyLiteXM2SDR\")")
    else
        println("✓ Kernel module path: $kmod_path")
        println("✓ Kernel module exists: $(isfile(kmod_path))")
    end

    println("Kernel module loaded: $(loaded ? "✓ Yes" : "✗ No")")

    if loaded
        println("\nModule information:")
        try
            modinfo = read(`modinfo m2sdr`, String)
            println(modinfo)
        catch
            println("(Could not retrieve module info)")
        end
    else
        println("\nTo load the kernel module, run:")
        println("  SoapyLiteXM2SDR.install_kernel_module()")
    end
end

# Export the module path constant for JLL-style discovery
export libSoapyLiteXM2SDR

function __init__()
    # Verify the module file exists
    if !isfile(module_path)
        @warn """
        SoapyLiteXM2SDR module not found at: $module_path
        Please rebuild the package:
            using Pkg
            Pkg.build("SoapyLiteXM2SDR")
        """
        return
    end

    # Automatically load the module into SoapySDR if it's available
    # This mimics the behavior of JLL driver packages
    try
        if isdefined(Main, :SoapySDR)
            SoapySDR_mod = Main.SoapySDR
            SoapySDR_mod.Modules.load_module(module_path)
            @info "SoapyLiteXM2SDR driver automatically loaded into SoapySDR"
        end
    catch e
        @debug "Could not auto-load module into SoapySDR" exception = e
    end

    @info "SoapyLiteXM2SDR driver available at: $module_path"
    @info "Use with: using SoapySDR, SoapyLiteXM2SDR"
end

end # module SoapyLiteXM2SDR
