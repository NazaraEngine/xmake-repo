package("nazaraengine")
    set_homepage("https://github.com/NazaraEngine/NazaraEngine")
    set_description("Nazara Engine is a cross-platform framework aimed at (but not limited to) real-time applications requiring audio, 2D and 3D rendering, network and more (such as video games).")
    set_license("MIT")
    set_policy("package.librarydeps.strict_compatibility", true)

    set_urls("https://github.com/NazaraEngine/NazaraEngine.git")

    add_versions("2023.04.11", "71891b9788850587a93501fc88fe6f9b1bc0fd90")

    add_deps("nazarautils")

    -- static compilation is not supported for now
    add_configs("shared", {description = "Build shared library.", default = not is_plat("wasm"), type = "boolean", readonly = true})

    -- all modules and plugins have their own config
    add_configs("plugin_assimp",          {description = "Includes the assimp plugin", default = true, type = "boolean"})
    add_configs("plugin_ffmpeg",          {description = "Includes the ffmpeg plugin", default = false, type = "boolean"})
    add_configs("entt",                   {description = "Includes EnTT to use components and systems", default = true, type = "boolean"})
    add_configs("with_symbols",           {description = "Enable debug symbols in release", default = false, type = "boolean"})
    if not is_plat("wasm") then
        add_configs("embed_rendererbackends", {description = "Embed renderer backend code into NazaraRenderer instead of loading them dynamically", default = false, type = "boolean"})
        add_configs("embed_plugins",          {description = "Embed enabled plugins code as static libraries", default = false, type = "boolean"})
        add_configs("link_openal",            {description = "Link OpenAL in the executable instead of dynamically loading it", default = false, type = "boolean"})
    end

    local components = {
        audio = {
            option = "audio",
            name = "Audio",
            deps = { "core" },
            custom = function (package, component)
                if package:is_plat("wasm") then
                    component:add("syslinks", "openal")
                end
            end
        },
        bulletphysics3d = {
            option = "bulletphysics",
            name = "BulletPhysics3D",
            deps = { "core" }
        },
        chipmunkphysics2d = {
            option = "chipmunkphysics",
            name = "ChipmunkPhysics2D",
            deps = { "core" }
        },
        core = {
            name = "Core",
            custom = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "ole32")
                elseif package:is_plat("linux") then
                    component:add("syslinks", "pthread", "dl")
                elseif package:is_plat("android") then
                    component:add("syslinks", "log")
                end
            end
        },
        graphics = { 
            option = "graphics",
            name = "Graphics",
            deps = { "renderer" }
        },
        joltphysics3d = {
            option = "joltphysics",
            name = "JoltPhysics3D",
            deps = { "core" }
        },
        network = {
            option = "network",
            name = "Network",
            deps = { "core" },
            custom = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "ws2_32")
                end
            end
        },
        platform = {
            option = "platform",
            name = "Platform",
            deps = { "utility" }
        },
        renderer = {
            option = "renderer",
            name = "Renderer",
            deps = { "platform", "utility" },
            custom = function (package, component)
                if package:is_plat("windows", "mingw") then
                    component:add("syslinks", "gdi32", "user32", "advapi32")
                end
            end
        },
        utility = {
            option = "utility",
            name = "Utility",
            deps = { "core" }
        },
        widgets = {
            option = "widgets",
            name = "Widgets",
            deps = { "graphics" }
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
            if compdata.custom then
                compdata.custom(package, component)
            end
        end)
    end

    on_load(function (package)
        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                package:add("components", name)
            end
        end

        if not package:config("shared") then
            package:add("defines", "NAZARA_STATIC")
        end

        package:add("deps", "nzsl", { debug = package:debug(), configs = { with_symbols = package:config("with_symbols") or package:debug(), shared = true } })
        if package:config("entt") then
            package:add("defines", "NAZARA_ENTT")
            package:add("deps", "entt 3.11.1")
        end
    end)

    on_install("windows", "mingw", "linux", "macosx", "wasm", function (package)
        local configs = {}
        configs.examples = false
        configs.tests = false
        configs.override_runtime = false
        configs.unitybuild = not package:is_plat("mingw")

        configs.assimp = package:config("plugin_assimp")
        configs.ffmpeg = package:config("plugin_ffmpeg")

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
        elseif package:config("with_symbols") then
            configs.mode = "releasedbg"
        else
            configs.mode = "release"
        end
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                assert(package:check_cxxsnippets({test = [[
                    void test() {
                        Nz::Modules<Nz::]] .. compdata.name .. [[> nazara;
                    }
                ]]}, {configs = {languages = "c++17"}, includes = "Nazara/" .. compdata.name .. ".hpp"}))
            end
        end
    end)
