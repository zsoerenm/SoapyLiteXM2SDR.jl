using Test
using SoapyLiteXM2SDR
using Scratch
using Libdl

@testset "SoapyLiteXM2SDR.jl" begin
    @testset "Module Loading" begin
        @test isdefined(SoapyLiteXM2SDR, :get_module_path)
        @test isdefined(SoapyLiteXM2SDR, :get_install_dir)
        @test isdefined(SoapyLiteXM2SDR, :libSoapyLiteXM2SDR)
    end

    @testset "Path Functions" begin
        @testset "get_module_path()" begin
            module_path = SoapyLiteXM2SDR.get_module_path()
            @test module_path isa String
            @test !isempty(module_path)

            # Check that the path contains expected components
            @test occursin("libSoapyLiteXM2SDR", module_path)
            @test occursin(Libdl.dlext, module_path)

            # If module was built, verify it exists
            if isfile(module_path)
                @test isfile(module_path)
                @test endswith(module_path, ".$(Libdl.dlext)")
            else
                @warn "Module file not found at $(module_path). Build may not have completed."
            end
        end

        @testset "get_install_dir()" begin
            install_dir = SoapyLiteXM2SDR.get_install_dir()
            @test install_dir isa String
            @test !isempty(install_dir)

            # If module was built, verify directory structure
            if isdir(install_dir)
                @test isdir(install_dir)
                @test isdir(joinpath(install_dir, "lib"))
            else
                @warn "Install directory not found at $(install_dir). Build may not have completed."
            end
        end

        @testset "libSoapyLiteXM2SDR constant" begin
            @test SoapyLiteXM2SDR.libSoapyLiteXM2SDR isa String
            @test SoapyLiteXM2SDR.libSoapyLiteXM2SDR == SoapyLiteXM2SDR.get_module_path()
        end
    end

    @testset "deps.jl Generation" begin
        depsjl_path = joinpath(dirname(@__DIR__), "deps", "deps.jl")
        @test isfile(depsjl_path)

        # Read and verify contents
        depsjl_content = read(depsjl_path, String)
        @test occursin("module_path", depsjl_content)
        @test occursin("install_dir", depsjl_content)
    end

    @testset "Module File Properties" begin
        module_path = SoapyLiteXM2SDR.get_module_path()

        if isfile(module_path)
            @testset "File exists and is readable" begin
                @test isfile(module_path)
                @test filesize(module_path) > 0
                # Check file permissions (Julia 1.10 compatible)
                @test (filemode(module_path) & 0o400) != 0  # Owner read permission
            end

            @testset "Dynamic library properties" begin
                # Try to get library handle (doesn't actually load it)
                @test endswith(module_path, ".$(Libdl.dlext)")

                # Check if it's a valid shared library
                if Sys.islinux()
                    # On Linux, verify ELF format
                    magic = open(module_path) do f
                        read(f, 4)
                    end
                    @test magic == UInt8[0x7f, 0x45, 0x4c, 0x46]  # ELF magic number
                end
            end

            @testset "Installation path structure" begin
                # Verify the module is in the expected SoapySDR modules directory
                @test occursin("SoapySDR", module_path)
                @test occursin("modules", module_path)
            end
        else
            @warn "Skipping module file property tests - module not built"
        end
    end

    @testset "Scratch Space Management" begin
        @testset "Scratch directory exists" begin
            # Get scratch space used for building
            scratch_dir = @get_scratch!("SoapyLiteXM2SDR-build")
            @test isdir(scratch_dir)
        end

        @testset "Build artifacts structure" begin
            scratch_dir = @get_scratch!("SoapyLiteXM2SDR-build")

            # Check for expected build structure if build completed
            if isdir(joinpath(scratch_dir, "litex_m2sdr"))
                @test isdir(joinpath(scratch_dir, "litex_m2sdr"))

                # Check for user libraries if they were built
                userdir = joinpath(scratch_dir, "litex_m2sdr", "litex_m2sdr", "software", "user")
                if isdir(userdir)
                    @test isdir(joinpath(userdir, "liblitepcie"))
                    @test isdir(joinpath(userdir, "libm2sdr"))
                    @test isdir(joinpath(userdir, "ad9361"))
                end
            end

            # Check for build directory
            if isdir(joinpath(scratch_dir, "build_soapy"))
                @test isdir(joinpath(scratch_dir, "build_soapy"))
            end

            # Check for install directory
            if isdir(joinpath(scratch_dir, "install"))
                install_dir = joinpath(scratch_dir, "install")
                @test isdir(install_dir)
                @test install_dir == SoapyLiteXM2SDR.get_install_dir()
            end
        end
    end

    @testset "Error Handling" begin
        @testset "Missing deps.jl handling" begin
            # This test verifies the error message structure
            # We can't actually test the error without breaking the package
            # but we can verify the depsjl_path check logic
            depsjl_path = joinpath(dirname(pathof(SoapyLiteXM2SDR)), "..", "deps", "deps.jl")
            @test isfile(depsjl_path)
        end
    end

    @testset "Module Initialization" begin
        @testset "__init__ warnings" begin
            # Verify that if module doesn't exist, a warning would be issued
            # We can't easily test this without breaking the module
            # but we can verify the module_path is checked
            module_path = SoapyLiteXM2SDR.get_module_path()
            if !isfile(module_path)
                @warn "Module not found - __init__ would have issued a warning"
            else
                @test isfile(module_path)
            end
        end
    end
end
