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
