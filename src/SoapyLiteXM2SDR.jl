module SoapyLiteXM2SDR

using soapysdr_jll

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
        error("""
        Kernel module was not built. Please rebuild the package with:
            using Pkg
            Pkg.build("SoapyLiteXM2SDR")
        Ensure Linux kernel headers are installed on your system.
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
    println("=" ^ 50)

    if kmod_path === nothing
        println("✗ Kernel module: Not built")
        println("\nTo build the kernel module, ensure kernel headers are")
        println("installed and run: Pkg.build(\"SoapyLiteXM2SDR\")")
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
            if hasproperty(SoapySDR_mod, :Modules) && hasproperty(SoapySDR_mod.Modules, :load_module)
                SoapySDR_mod.Modules.load_module(module_path)
                @info "SoapyLiteXM2SDR driver automatically loaded into SoapySDR"
            end
        end
    catch e
        @debug "Could not auto-load module into SoapySDR" exception=e
    end

    @info "SoapyLiteXM2SDR driver available at: $module_path"
    @info "Use with: using SoapySDR, SoapyLiteXM2SDR"
end

end # module SoapyLiteXM2SDR
