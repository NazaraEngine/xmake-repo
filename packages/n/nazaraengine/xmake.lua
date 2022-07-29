package("nazaraengine")
    set_homepage("https://github.com/NazaraEngine/NazaraEngine")
    set_description("Nazara Engine is a cross-platform framework aimed at (but not limited to) real-time applications requiring audio, 2D and 3D rendering, network and more (such as video games).")

    set_urls("https://github.com/NazaraEngine/NazaraEngine.git")

    add_versions("2022.07.28", "c6851d93c2f255801545d8cf707ade3b16c205db")

    add_deps("nazarautils")
    add_deps("chipmunk2d", "dr_wav", "efsw", "fmt", "frozen", "kiwisolver", "libflac", "libsdl", "minimp3", "ordered_map", "stb", { private = true })
    add_deps("libvorbis", { private = true, configs = { with_vorbisenc = false } })
    add_deps("openal-soft", { private = true, configs = { shared = true }})

    add_configs("audio",         {description = "Includes the audio module", default = true, type = "boolean"})
    add_configs("graphics",      {description = "Includes the graphics module", default = true, type = "boolean"})
    add_configs("network",       {description = "Includes the network module", default = true, type = "boolean"})
    add_configs("physics2d",     {description = "Includes the 2D physics module", default = true, type = "boolean"})
    add_configs("physics3d",     {description = "Includes the 3D physics module", default = true, type = "boolean"})
    add_configs("platform",      {description = "Includes the platform module", default = true, type = "boolean"})
    add_configs("renderer",      {description = "Includes the renderer module", default = true, type = "boolean"})
    add_configs("utility",       {description = "Includes the utility module", default = true, type = "boolean"})
    add_configs("widget",        {description = "Includes the widget module", default = true, type = "boolean"})
    add_configs("plugin-assimp", {description = "Includes the assimp plugin", default = false, type = "boolean"})
    add_configs("plugin-ffmpeg", {description = "Includes the ffmpeg plugin", default = false, type = "boolean"})
    add_configs("entt",          {description = "Includes EnTT to use components and systems", default = true, type = "boolean"})
    add_configs("with_symbols",  {description = "Enable debug symbols in release", default = false, type = "boolean"})

    if is_plat("linux") then
        add_syslinks("pthread")
    end

    local function has_audio(package)
        return not package:config("server") and (package:config("audio"))
    end

    local function has_graphics(package)
        return not package:config("server") and (package:config("graphics"))
    end

    local function has_network(package)
        return package:config("network")
    end

    local function has_renderer(package)
        return not package:config("server") and (package:config("renderer") or has_graphics(package))
    end

    local function has_platform(package)
        return not package:config("server") and (package:config("platform") or has_renderer(package))
    end

    local function has_physics2d(package)
        return package:config("physics2d")
    end

    local function has_physics3d(package)
        return package:config("physics3d")
    end

    local function has_utility(package)
        return package:config("utility") or has_platform(package)
    end

    local function has_widget(package)
        return package:config("widget")
    end

    local function has_assimp_plugin(package)
        return package:config("plugin-assimp")
    end

    local function has_ffmpeg_plugin(package)
        return package:config("plugin-ffmpeg")
    end

    on_load(function (package)
        package:add("deps", "nzsl", { debug = package:debug(), configs = { with_symbols = package:config("with_symbols"), shared = true } })
        package:add("deps", "freetype", { private = true, configs = { bzip2 = true, png = true, woff2 = true, zlib = true, debug = package:debug() } })
        package:add("deps", "newtondynamics", { private = true, debug = is_plat("windows") and package:debug() })
        if package:config("entt") then
            package:add("deps", "entt 3.10.1")
        end
    end)

    on_fetch(function (package)
        local nazaradir = os.getenv("NAZARA_ENGINE_PATH")
        if not nazaradir or not os.isdir(nazaradir) then 
            return
        end

        local defines = {}
        local includedirs = path.join(nazaradir, "include")
        local links = {}
        local libprefix = package:debug() and "debug" or "releasedbg"
        local linkdirs = path.join(nazaradir, "bin/" .. package:plat() .. "_" .. package:arch() .. "_" .. libprefix)
        local syslinks = {}

        local prefix = "Nazara"
        local suffix = package:config("shared") and "" or "-s"

        if package:debug() then
            suffix = suffix .. "-d"
        end

        if not package:config("shared") then
            table.insert(defines, "NAZARA_STATIC")
        end

        if has_audio(package) then
            table.insert(links, prefix .. "Audio" .. suffix)
        end

        if has_network(package) then
            table.insert(links, prefix .. "Network" .. suffix)
        end

        if has_physics2d(package) then
            table.insert(links, prefix .. "Physics2D" .. suffix)
        end

        if has_physics3d(package) then
            table.insert(links, prefix .. "Physics3D" .. suffix)
        end

        if has_widget(package) then
            table.insert(links, prefix .. "Widget" .. suffix)
        end

        if has_graphics(package) then
            table.insert(links, prefix .. "Graphics" .. suffix)
        end

        if has_renderer(package) then
            table.insert(links, prefix .. "Renderer" .. suffix)
            if package:is_plat("windows", "mingw") then
                table.insert(syslinks, "gdi32")
                table.insert(syslinks, "user32")
                table.insert(syslinks, "advapi32")
            end
        end

        if has_platform(package) then
            table.insert(links, prefix .. "Platform" .. suffix)
        end

        if has_utility(package) then
            table.insert(links, prefix .. "Utility" .. suffix)
        end

        table.insert(links, prefix .. "Core" .. suffix)

        return {
            defines = defines,
            includedirs = includedirs,
            links = links,
            linkdirs = linkdirs,
            syslinks = syslinks
        }
    end)

    on_install("windows", "mingw", "linux", "macosx", function (package)
        local configs = {}
        configs.assimp = package:config("plugin-assimp")
        configs.ffmpeg = package:config("plugin-ffmpeg")
        configs.examples = false
        configs.override_runtime = false

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
        assert(package:check_cxxsnippets({test = [[
            void test() {
                Nz::Modules<Nz::Core> nazara;
            }
        ]]}, {configs = {languages = "c++17"}, includes = "Nazara/Core.hpp"}))
    end)
