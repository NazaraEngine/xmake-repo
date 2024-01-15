package("nazaraengine")
    set_homepage("https://github.com/NazaraEngine/NazaraEngine")
    set_description("Nazara Engine is a cross-platform framework aimed at (but not limited to) real-time applications requiring audio, 2D and 3D rendering, network and more (such as video games).")
    set_license("MIT")
    set_policy("package.librarydeps.strict_compatibility", true)

    set_urls("https://github.com/NazaraEngine/NazaraEngine.git")

    add_versions("2024.01.15", "ea4b8eaaea7af19cba7fd597f449055792185ffb")

    add_deps("nazarautils")

    -- default to shared build
    add_configs("shared", {description = "Build shared library.", default = not is_plat("wasm"), type = "boolean"})

    -- all modules and plugins have their own config
    add_configs("plugin_assimp",          {description = "Includes the assimp plugin", default = true, type = "boolean"})
    add_configs("plugin_ffmpeg",          {description = "Includes the ffmpeg plugin", default = false, type = "boolean"})
    add_configs("entt",                   {description = "Includes EnTT to use components and systems", default = true, type = "boolean"})
    add_configs("symbols",                {description = "Enable debug symbols in release", default = false, type = "boolean"})
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
        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                package:add("components", name)
            end
        end

        if not package:config("shared") then
            package:add("defines", "NAZARA_STATIC")
        end

        if package:config("renderer") or package:config("graphics") then
            package:add("deps", "nzsl >=2023.12.31", { debug = package:debug(), configs = { symbols = package:config("symbols") or package:debug(), shared = true } })
        end

        if package:config("entt") then
            package:add("defines", "NAZARA_ENTT")
            package:add("deps", "entt 3.12.2")
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
    end)

    on_test(function (package)
        for name, compdata in table.orderpairs(components) do
            if not compdata.option or package:config(compdata.option) then
                assert(package:check_cxxsnippets({test = [[
                    void test() {
                        Nz::Modules<Nz::]] .. compdata.name .. [[> nazara;
                    }
                ]]}, {configs = {languages = "c++20"}, includes = "Nazara/" .. compdata.name .. ".hpp"}))
            end
        end
    end)
