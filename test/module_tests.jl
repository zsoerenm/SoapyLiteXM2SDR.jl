using Test
using SoapyLiteXM2SDR

@testset "Module API Tests" begin
    @testset "Exported symbols" begin
        @test :libSoapyLiteXM2SDR in names(SoapyLiteXM2SDR)
    end

    @testset "Function signatures" begin
        @test hasmethod(SoapyLiteXM2SDR.get_module_path, Tuple{})
        @test hasmethod(SoapyLiteXM2SDR.get_install_dir, Tuple{})
    end

    @testset "Return types" begin
        @test SoapyLiteXM2SDR.get_module_path() isa String
        @test SoapyLiteXM2SDR.get_install_dir() isa String
    end

    @testset "Path consistency" begin
        # module_path should be within install_dir
        module_path = SoapyLiteXM2SDR.get_module_path()
        install_dir = SoapyLiteXM2SDR.get_install_dir()

        @test startswith(module_path, install_dir)
    end

    @testset "Path naming conventions" begin
        module_path = SoapyLiteXM2SDR.get_module_path()

        # Should contain the library name
        @test occursin("SoapyLiteXM2SDR", module_path)

        # Should be in SoapySDR modules directory
        @test occursin(joinpath("lib", "SoapySDR", "modules"), module_path)
    end

    @testset "Constant consistency" begin
        # libSoapyLiteXM2SDR should equal get_module_path()
        @test SoapyLiteXM2SDR.libSoapyLiteXM2SDR == SoapyLiteXM2SDR.get_module_path()

        # Should be a constant, not mutable
        @test typeof(SoapyLiteXM2SDR.libSoapyLiteXM2SDR) == String
    end
end
