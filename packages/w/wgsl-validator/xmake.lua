package("wgsl-validator")
    set_homepage("https://github.com/NazaraEngine/wgsl-validator")
    set_description("NZSL is a shader language inspired by Rust and C++ which compiles to GLSL or SPIRV")
    set_license("MIT")

    add_urls("https://github.com/NazaraEngine/wgsl-validator.git")

    add_urls("https://github.com/NazaraEngine/wgsl-validator/archive/refs/tags/$(version).tar.gz",
             "https://github.com/NazaraEngine/wgsl-validator.git")

    set_kind("library")
    set_homepage("https://example.com")
    set_description("Rust library with FFI")

    on_install("linux", "macosx", "windows", function (package)
        import("lib.detect.find_tool")
        local cargo = find_tool("cargo")
        if not cargo then
            if is_host("windows") then
                os.vrun("powershell -Command \"iwr https://win.rustup.rs -UseBasicParsing -OutFile rustup-init.exe; ./rustup-init.exe -y\"")
            else
                os.vrun("curl https://sh.rustup.rs -sSf | sh -s -- -y")
            end
            local home = os.getenv("USERPROFILE") or os.getenv("HOME")
            local cargo_bin = path.join(home, ".cargo", "bin")
            os.addenv("PATH", cargo_bin)
        end

        os.vrun("cargo build --release")

        os.cp("target/release/*.a", package:installdir("lib"))
        os.cp("target/release/*.so", package:installdir("lib"))
        os.cp("target/release/*.dll", package:installdir("lib"))
        os.cp("target/release/*.dylib", package:installdir("lib"))
        os.cp("ffi/*", package:installdir("include"))
    end)

    on_test(function (package)
        assert(package:check_csnippets({test = [[
            #include "wgsl_validator.h"
            #define WGSL_SOURCE(...) #__VA_ARGS__
            const char* wgsl_source = WGSL_SOURCE(
                @fragment
                fn main_fs() -> @location(0) vec4<f32> {
                    return vec4<f32>(1.0, 1.0, 1.0, 1.0);
                }
            );

            void test() {
                char* error;
                wgsl_validator_t* validator = wgsl_validator_create();
                if(wgsl_validator_validate(validator, wgsl_source, &error))
                    wgsl_validator_free_error(error);
                wgsl_validator_destroy(validator);
            }
        ]]}, {configs = {languages = "c17"}, includes = "wgsl_validator.h"}))
    end)
