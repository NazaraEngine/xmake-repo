package("nazaraengine")
    set_homepage("https://github.com/NazaraEngine/NazaraEngine")
    set_description("Nazara Engine is a cross-platform framework aimed at (but not limited to) real-time applications requiring audio, 2D and 3D rendering, network and more (such as video games).")
    set_license("MIT")
    set_policy("package.librarydeps.strict_compatibility", true)

    set_urls("https://github.com/NazaraEngine/NazaraEngine.git")

    add_versions("2025.04.05", "6d151c78d204bd613fd901ae4de18d9803200d2a")

    add_deps("nazarautils")

    -- default to shared build
    add_configs("shared", {description = "Build shared library.", default = not is_plat("wasm"), type = "boolean"})

    -- all modules and plugins have their own config
    add_configs("plugin_assimp",          {description = "Includes Assimp plugin", default = true, type = "boolean"})
    add_configs("plugin_ffmpeg",          {description = "Includes FFMpeg plugin", default = false, type = "boolean"})
    add_configs("plugin_imgui",           {description = "Includes ImGui plugin", default = false, type = "boolean"})
    add_configs("entt",                   {description = "Includes EnTT to use components and systems", default = true, type = "boolean"})
    add_configs("symbols",                {description = "Enable debug symbols in release", default = false, type = "boolean"})
    if not is_plat("wasm") then
        add_configs("embed_rendererbackends", {description = "Embed renderer backend code into NazaraRenderer instead of loading them dynamically", default = false, type = "boolean"})
        add_configs("embed_plugins",          {description = "Embed enabled plugins code as static libraries", default = false, type = "boolean"})
        add_configs("link_openal",            {description = "Link OpenAL to the executable instead of dynamically loading it", default = false, type = "boolean"})
    end

    local components = {
        audio = {
            option = "audio",
            name = "Audio",
            deps = { "core" },
            custom = function (package)
                package:add("deps", "libvorbis", {private = true, configs = {with_vorbisenc = false}})
                if not package:is_plat("wasm") then
                    package:add("deps", "openal-soft", {private = true, configs = {shared = true}})
                end
            end,
            custom_comp = function (package, component)
                if package:is_plat("wasm") then
                    component:add("syslinks", "openal")
                end
            end,
            privatepkgs = {"dr_mp3", "dr_wav", "libflac"}
        },
        core = {
            name = "Core",
            custom = function (package)
                if package:is_plat("linux", "android") then
                    package:add("deps", "libuuid", {private = true})
                end
            end,
            custom_comp = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "ole32")
                elseif package:is_plat("linux") then
                    component:add("syslinks", "pthread", "dl")
                elseif package:is_plat("android") then
                    component:add("syslinks", "log")
                end
            end,
            privatepkgs = {"concurrentqueue", "fmt", "frozen", "ordered_map", "stb", "utfcpp"}
        },
        graphics = { 
            option = "graphics",
            name = "Graphics",
            deps = { "renderer", "textrenderer" }
        },
        network = {
            option = "network",
            name = "Network",
            deps = { "core" },
            custom = function (package)
                if not package:is_plat("wasm") then
                    if package:config("static") then
                        package:add("deps", "libcurl", {private = true, configs = {asan = false, openssl = package:is_plat("linux", "android", "cross")}})
                    else
                        package:add("deps", "libcurl", {private = true, configs = {asan = false, openssl = package:is_plat("linux", "android", "cross"), shared = true}})
                    end
                end
            end,
            custom_comp = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "ws2_32")
                end
            end
        },
        physics2d = {
            option = "physics2d",
            name = "Physics2D",
            deps = { "core" },
            privatepkgs = {"chipmunk2d"}
        },
        physics3d = {
            option = "physics3d",
            name = "Physics3D",
            deps = { "core" },
            custom = function (package)
                package:add("deps", "joltphysics v5.3.0", {private = true, configs = {debug = package:is_debug()}})
            end
        },
        platform = {
            option = "platform",
            name = "Platform",
            deps = { "core" },
            custom = function (package)
                if package:is_plat("linux") then
                    package:add("deps", "libxext", "wayland", {private = true, configs = {asan = false}})
                end
            end,
            privatepkgs = {"libsdl3"}
        },
        renderer = {
            option = "renderer",
            name = "Renderer",
            deps = { "platform" },
            custom = function (package)
                if not package:is_plat("wasm") then
                    package:add("deps", "vulkan-headers", "vulkan-memory-allocator", {private = true})
                end
            end,
            custom_comp = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "gdi32", "user32", "advapi32")
                end
            end,
            privatepkgs = {"opengl-headers"}
        },
        textrenderer = {
            option = "textrenderer",
            name = "TextRenderer",
            deps = { "core" },
            custom = function (package)
                package:add("deps", "freetype", {private = true, configs = {bzip2 = true, png = true, woff2 = true, zlib = true, debug = package:is_debug()}})
            end
        },
        widgets = {
            option = "widgets",
            name = "Widgets",
            deps = { "graphics" },
            privatepkgs = {"kiwisolver"}
        }
    }

    local function build_deps(component, deplist, inner)
        if component.deps then
            for _, depname in ipairs(component.deps) do
                table.insert(deplist, depname)
                build_deps(components[depname], deplist, true)
            end
        end
    end

    for name, compdata in table.orderpairs(components) do
        local deplist = {}
        build_deps(compdata, deplist)
        compdata.deplist = table.unique(deplist)

        if compdata.option then
            local depstring = #deplist > 0 and " (depends on " .. table.concat(compdata.deplist, ", ") .. ")" or ""
            add_configs(compdata.option, { description = "Compiles the " .. compdata.name .. " module" .. depstring, default = true, type = "boolean" })
        end

        on_component(name, function (package, component)
            local prefix = "Nazara"
            local suffix = package:config("shared") and "" or "-s"
            if package:debug() then
                suffix = suffix .. "-d"
            end

            component:add("deps", table.unwrap(compdata.deps))
            component:add("links", prefix .. compdata.name .. suffix)
            if compdata.custom_comp then
                compdata.custom_comp(package, component)
            end
        end)
    end

    on_fetch(function (package, opt)
        if not opt.system then
            return
        end

        local nazara = os.getenv("NAZARA_ENGINE_PATH")
        if not nazara or not os.isdir(nazara) then
            return
        end

        local mode
        if package:is_debug() then
            mode = "debug"
        elseif package:config("symbols") then
            mode = "releasedbg"
        else
            mode = "release"
        end

        local versions = package:versions()
        table.sort(versions, function (a, b) return a > b end)

        local binFolder = string.format("%s_%s_%s", package:plat(), package:arch(), mode)
        local fetchInfo = {
            version = versions[1] or os.date("%Y.%m.%d"),
            sysincludedirs = { path.join(nazara, "include") },
            linkdirs = path.join(nazara, "bin", binFolder),
            components = {}
        }
        local baseComponent = {}
        fetchInfo.components.__base = baseComponent

        if package:config("entt") then
            fetchInfo.defines = table.join(fetchInfo.defines or {}, "NAZARA_ENTT")
        end
        if package:is_debug() then
            fetchInfo.defines = table.join(fetchInfo.defines or {}, "NAZARA_DEBUG")
        end
        for name, component in pairs(package:components()) do
            fetchInfo.components[name] = {
                links = component:get("links"),
                syslinks = component:get("syslinks")
            }
        end
        for _, componentname in pairs(package:components_orderlist()) do
            local component = fetchInfo.components[componentname]
            for k,v in pairs(component) do
                fetchInfo[k] = table.join2(fetchInfo[k] or {}, v)
            end
        end

        baseComponent.defines = fetchInfo.defines
        baseComponent.linkdirs = fetchInfo.linkdirs
        baseComponent.sysincludedirs = fetchInfo.sysincludedirs

        package:set("policy", "package.librarydeps.strict_compatibility", false)

        return fetchInfo
    end)

    on_load(function (package)
        if package:config("plugin_imgui") then
            if not package:config("renderer") or not package:config("textrenderer") then
                raise("package(nazaraengine): ImGui plugin requires Renderer and TextRenderer modules")
            end
        end

        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                package:add("components", name)
                if compdata.privatepkgs then
                    package:add("deps", table.unpack(compdata.privatepkgs), {private = true})
                end
            end
        end

        if not package:config("shared") then
            package:add("defines", "NAZARA_STATIC")
            package:add("defines", "NAZARA_PLUGINS_STATIC")
        elseif package:config("embed_plugins") then
            package:add("defines", "NAZARA_PLUGINS_STATIC")
        end

        if package:config("renderer") or package:config("graphics") then
            package:add("deps", "nzsl >=2024.10.19", { debug = package:debug(), configs = { symbols = package:config("symbols") or package:debug(), shared = true } })
        end

        if package:config("entt") then
            package:add("defines", "NAZARA_ENTT")
            package:add("deps", "entt 3.14.0")
        end

        if package:config("plugin_assimp") then
            package:add("deps", "assimp >=5.2.5", {private = true})
        end

        if package:config("plugin_ffmpeg") then
            package:add("deps", "ffmpeg", {private = true, configs = {asan = false, gpl = false, vs_runtime = "MD"}})
        end

        if package:config("plugin_imgui") then
            package:add("deps", "imgui v1.91.1-docking", { debug = package:debug() })
        end

        if package:is_debug() then
            package:add("defines", "NAZARA_DEBUG")
        end
    end)

    on_install("windows", "mingw", "linux", "macosx", "wasm", function (package)
        local configs = {}
        configs.examples = false
        configs.tests = false
        configs.override_runtime = false

        -- enable unitybuild for faster compilation except on MinGW (doesn't like big object even with /bigobj)
        if not os.getenv("NAZARA_DISABLE_UNITYBUILD") then
            configs.unitybuild = not package:is_plat("mingw")
        end

        configs.assimp = package:config("plugin_assimp")
        configs.ffmpeg = package:config("plugin_ffmpeg")
        configs.imgui = package:config("plugin_imgui")

        for name, compdata in table.orderpairs(components) do
            if compdata.option then
                if package:config(compdata.option) then
                    for _, dep in ipairs(compdata.deplist) do
                        local depcomp = components[dep]
                        if depcomp.option and not package:config(depcomp.option) then
                            raise("module \"" .. name .. "\" depends on disabled module \"" .. dep .. "\"")
                        end
                    end

                    configs[compdata.option] = true
                else
                    configs[compdata.option] = false
                end
            end
        end

        if not package:is_plat("wasm") then
            configs.embed_rendererbackends = package:config("embed_rendererbackends")
            configs.embed_plugins = package:config("embed_plugins")
            configs.link_openal = package:config("link_openal")
        else
            configs.embed_rendererbackends = true
            configs.embed_plugins = true
            configs.link_openal = true
        end

        if package:is_debug() then
            configs.mode = "debug"
        elseif package:config("symbols") then
            configs.mode = "releasedbg"
        else
            configs.mode = "release"
        end
        import("package.tools.xmake").install(package, configs)

        if package:has_tool("cxx", "cl") then
            package:add("cxxflags", "/Zc:preprocessor") -- /Zc:preprocessor is required because Nazara uses __VA_OPT__ (C++20)
        end
    end)

    on_test(function (package)
        local includes = {}
        local classnames = {}
        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                table.insert(classnames, "Nz::" .. compdata.name)
                table.insert(includes, "Nazara/" .. compdata.name .. ".hpp")
            end
        end
        assert(package:check_cxxsnippets({test = [[
            void test() {
                Nz::Modules<]] .. table.concat(classnames, ", ") .. [[> nazara;
            }
        ]]}, {configs = {languages = "c++20"}, includes = includes}))
    end)
