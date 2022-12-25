package("nzsl")
    set_homepage("https://github.com/NazaraEngine/ShaderLang")
    set_description("NZSL is a shader language inspired by Rust and C++ which compiles to GLSL or SPIRV")
    set_license("MIT")
    set_policy("package.strict_compatibility", true)

    add_urls("https://github.com/NazaraEngine/ShaderLang.git")

    add_versions("2022.12.25", "a81198cc8c33974712e5efd7a03edbf3e94a31ef")

    add_deps("nazarautils", "fmt")
    add_deps("frozen", "ordered_map", { private = true })

    add_configs("with_nzslc", {description = "Includes standalone compiler", default = true, type = "boolean"})
    add_configs("with_symbols", {description = "Enable debug symbols in release", default = false, type = "boolean"})
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
        if package:config("with_nzslc") then
            package:add("deps", "nlohmann_json", { private = true })
        end
    end)

    on_install(function (package)
        local configs = {}
        configs.fs_watcher = package:config("fs_watcher") or false
        configs.erronwarn = false
        configs.examples = false
        configs.with_nzslc = package:config("with_nzslc") or false
        if package:is_debug() then
            configs.mode = "debug"
        elseif package:config("with_symbols") then
            configs.mode = "releasedbg"
        else
            configs.mode = "release"
        end
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        if package:config("with_nzslc") and not package:is_cross() then
            os.vrun("nzslc --version")
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
                        fn main() -> FragOut
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
