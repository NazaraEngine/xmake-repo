package("nazarautils")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/NazaraEngine/NazaraUtils")
    set_description("Header-only utility library for Nazara projects")
    set_license("MIT")

    add_urls("https://github.com/NazaraEngine/NazaraUtils.git")

    add_versions("2024.08.01", "f148b835f540e6c21db4f8ffd5a92fc42df1c73f")

    set_policy("package.strict_compatibility", true)

    on_install(function (package)
        import("package.tools.xmake").install(package)
    end)

    on_test(function (package)
        assert(package:check_cxxsnippets({test = [[
            void test() {
                Nz::Bitset<> bitset;
                bitset.UnboundedSet(42);
                bitset.Reverse();
            }
        ]]}, {configs = {languages = "c++17"}, includes = "NazaraUtils/Bitset.hpp"}))
    end)
