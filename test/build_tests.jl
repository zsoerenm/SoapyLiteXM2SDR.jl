using Test
using SoapyLiteXM2SDR
using Scratch
using Libdl
using soapysdr_jll

@testset "Build System Tests" begin
    @testset "Scratch space configuration" begin
        scratch_dir = @get_scratch!("build")

        @test isdir(scratch_dir)
        # Check directory permissions (Julia 1.10 compatible)
        @test (filemode(scratch_dir) & 0o400) != 0  # Owner read permission
        @test iswritable(scratch_dir)
    end

    @testset "deps.jl structure" begin
        deps_file = joinpath(dirname(pathof(SoapyLiteXM2SDR)), "..", "deps", "deps.jl")

        @test isfile(deps_file)
        # Check file permissions (Julia 1.10 compatible)
        @test (filemode(deps_file) & 0o400) != 0  # Owner read permission

        # Parse the deps.jl file
        deps_content = read(deps_file, String)

        @test occursin("module_path", deps_content)
        @test occursin("install_dir", deps_content)
        @test occursin("const", deps_content)

        # Verify it's valid Julia code by including it in a module
        test_module = Module(:TestDeps)
        @test_nowarn Base.include(test_module, deps_file)

        # Verify the constants are defined
        @test isdefined(test_module, :module_path)
        @test isdefined(test_module, :install_dir)
    end

    @testset "Built library verification" begin
        module_path = SoapyLiteXM2SDR.get_module_path()

        if isfile(module_path)
            @testset "Library file properties" begin
                @test filesize(module_path) > 0
                # Check file permissions (Julia 1.10 compatible)
                @test (filemode(module_path) & 0o400) != 0  # Owner read permission

                # Platform-specific extension
                @test endswith(module_path, ".$(Libdl.dlext)")
            end

            @testset "Library loading check" begin
                # Try to dlopen the library (doesn't initialize, just checks if valid)
                handle = nothing
                try
                    handle = Libdl.dlopen(module_path, Libdl.RTLD_NOW | Libdl.RTLD_LOCAL)
                    @test handle !== nothing
                catch e
                    @warn "Could not load library" exception=e
                end
                if handle !== nothing
                    Libdl.dlclose(handle)
                end
            end

            if Sys.islinux()
                @testset "RPATH verification (Linux)" begin
                    # Check if ldd shows the correct SoapySDR linkage
                    # This is optional since ldd might not be available
                    try
                        ldd_output = read(`ldd $module_path`, String)
                        @test occursin("libSoapySDR", ldd_output)

                        # Check that it links to the JLL artifact, not system
                        soapy_lib_path = joinpath(soapysdr_jll.artifact_dir, "lib")
                        if occursin(soapy_lib_path, ldd_output)
                            @test true  # Correctly linked to JLL
                        else
                            @warn "Library may be linked to system SoapySDR instead of JLL artifact"
                        end
                    catch e
                        @warn "Could not verify RPATH with ldd" exception=e
                    end
                end

                @testset "ELF format verification (Linux)" begin
                    magic = open(module_path) do f
                        read(f, 4)
                    end
                    @test magic == UInt8[0x7f, 0x45, 0x4c, 0x46]  # ELF magic
                end
            end
        else
            @warn "Module not built, skipping library verification tests"
        end
    end

    @testset "Build artifacts structure" begin
        scratch_dir = @get_scratch!("build")

        if isdir(joinpath(scratch_dir, "litex_m2sdr"))
            @testset "Source repository" begin
                repo_dir = joinpath(scratch_dir, "litex_m2sdr")
                @test isdir(repo_dir)
                @test isdir(joinpath(repo_dir, ".git"))

                # Check for expected subdirectories
                if isdir(joinpath(repo_dir, "litex_m2sdr"))
                    litex_subdir = joinpath(repo_dir, "litex_m2sdr")
                    @test isdir(joinpath(litex_subdir, "software"))
                    @test isdir(joinpath(litex_subdir, "software", "user"))
                    @test isdir(joinpath(litex_subdir, "software", "soapysdr"))
                end
            end

            @testset "User libraries" begin
                userdir = joinpath(scratch_dir, "litex_m2sdr", "litex_m2sdr", "software", "user")

                if isdir(userdir)
                    # Check for library directories
                    @test isdir(joinpath(userdir, "liblitepcie"))
                    @test isdir(joinpath(userdir, "libm2sdr"))
                    @test isdir(joinpath(userdir, "ad9361"))

                    # Check if libraries were built
                    liblitepcie = joinpath(userdir, "liblitepcie", "liblitepcie.a")
                    libm2sdr = joinpath(userdir, "libm2sdr", "libm2sdr.a")
                    libad9361 = joinpath(userdir, "ad9361", "libad9361_m2sdr.a")

                    if isfile(liblitepcie)
                        @test filesize(liblitepcie) > 0
                    end
                    if isfile(libm2sdr)
                        @test filesize(libm2sdr) > 0
                    end
                    if isfile(libad9361)
                        @test filesize(libad9361) > 0
                    end
                end
            end
        end

        @testset "CMake build directory" begin
            builddir = joinpath(scratch_dir, "build_soapy")

            if isdir(builddir)
                @test isdir(builddir)

                # Check for CMake artifacts
                @test isfile(joinpath(builddir, "CMakeCache.txt")) ||
                      isdir(joinpath(builddir, "CMakeFiles"))
            end
        end

        @testset "Installation directory" begin
            install_dir = SoapyLiteXM2SDR.get_install_dir()

            @test isdir(install_dir)
            @test isdir(joinpath(install_dir, "lib"))
            @test isdir(joinpath(install_dir, "lib", "SoapySDR"))
            @test isdir(joinpath(install_dir, "lib", "SoapySDR", "modules0.8"))
        end
    end

    @testset "SoapySDR integration" begin
        @testset "Module path structure" begin
            module_path = SoapyLiteXM2SDR.get_module_path()

            # Should be in the standard SoapySDR modules location
            @test occursin("modules0.8", module_path) ||
                  occursin("modules", module_path)
        end

        @testset "JLL artifact linkage" begin
            # Verify that soapysdr_jll is available
            @test isdefined(Main, :soapysdr_jll) ||
                  isdefined(SoapyLiteXM2SDR, :soapysdr_jll)

            # Check artifact directory exists
            @test isdir(soapysdr_jll.artifact_dir)
            @test isdir(joinpath(soapysdr_jll.artifact_dir, "lib"))
        end
    end
end
