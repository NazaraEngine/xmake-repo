package("nzsl")
    set_homepage("https://github.com/NazaraEngine/ShaderLang")
    set_description("NZSL is a shader language inspired by Rust and C++ which compiles to GLSL or SPIRV")
    set_license("MIT")

    add_urls("https://github.com/NazaraEngine/ShaderLang.git")

    add_versions("2024.01.02", "c124b2f3e094482b833606fad66808fa2e123128")

    set_policy("package.strict_compatibility", true)

    add_deps("nazarautils")

    add_configs("nzslc", {description = "Includes standalone compiler", default = true, type = "boolean"})
    add_configs("symbols", {description = "Enable debug symbols in release", default = false, type = "boolean"})

    if is_plat("windows", "linux", "mingw", "macosx", "bsd") then
        add_configs("fs_watcher", {description = "Includes filesystem watcher", default = true, type = "boolean"})
    elseif is_plat("wasm") then
        -- shared build for wasm is currently unsupported due to a fmt link error
        add_configs("shared", {description = "Build shared library.", default = false, type = "boolean", readonly = true})
    end

    on_load(function (package)
        package:addenv("PATH", "bin")
        if not package:config("shared") then
            package:add("defines", "NZSL_STATIC")
        end
        if package:config("fs_watcher") then
            package:add("deps", "efsw")
        end
    end)

    on_install(function (package)
        local configs = {}
        configs.fs_watcher = package:config("fs_watcher") or false
        configs.erronwarn = false
        configs.examples = false
        configs.with_nzslc = package:config("nzslc") or false

        -- enable unitybuild for faster compilation except on MinGW (doesn't like big object even with /bigobj)
        configs.unitybuild = not package:is_plat("mingw")

        if package:is_debug() then
            configs.mode = "debug"
        elseif package:config("symbols") then
            configs.mode = "releasedbg"
        else
            configs.mode = "release"
        end
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        if package:config("nzslc") and not package:is_cross() then
            local envs
            if package:is_plat("windows") then
                import("core.tool.toolchain")
                local msvc = toolchain.load("msvc")
                if msvc and msvc:check() then
                    envs = msvc:runenvs()
                end
            elseif package:is_plat("mingw") then
                import("core.tool.toolchain")
                local mingw = toolchain.load("mingw")
                if mingw and mingw:check() then
                    envs = mingw:runenvs()
                end
            end
            os.vrunv("nzslc", {"--version"}, {envs = envs})
        end
        if not package:is_binary() then
            assert(package:check_cxxsnippets({test = [[
                void test() {
                    nzsl::Ast::ModulePtr shaderModule = nzsl::Parse(R"(
                        [nzsl_version("1.0")]
                        module;

                        struct FragOut
                        {
                            value: vec4[f32]
                        }

                        [entry(frag)]
                        fn fragShader() -> FragOut
                        {
                            let output: FragOut;
                            output.value = vec4[f32](0.0, 0.0, 1.0, 1.0);
                            return output;
                        }
                    )");
                }
            ]]}, {configs = {languages = "c++17"}, includes = "NZSL/Parser.hpp"}))
        end
    end)
