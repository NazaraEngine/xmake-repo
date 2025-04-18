package("wgsl-validator")
    set_homepage("https://github.com/NazaraEngine/wgsl-validator")
    set_description("WGSL validator in Rust with C bindings.")
    set_license("MIT")

    add_urls("https://github.com/NazaraEngine/wgsl-validator.git")

    add_urls("https://github.com/NazaraEngine/wgsl-validator/archive/refs/tags/$(version).tar.gz",
             "https://github.com/NazaraEngine/wgsl-validator.git")

    on_install("linux", "macosx", "windows", function (package)
        local rust_dir = path.join(os.projectdir(), ".rust")
        local outdata, _ = os.iorun("curl https://sh.rustup.rs -sSf")
        io.writefile(path.join(rust_dir, "rustup-init.sh"), outdata)
        os.execv("/usr/bin/sh", { path.join(rust_dir, "rustup-init.sh"), "--no-modify-path", "-q", "-y" }, { envs = { RUSTUP_HOME = path.join(rust_dir, ".rustup"), CARGO_HOME= path.join(rust_dir, ".cargo") } })
        os.addenv("PATH", path.join(rust_dir, "bin"))
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
