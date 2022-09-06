package("nazarautils")
    set_kind("library", {headeronly = true})
    set_homepage("https://github.com/NazaraEngine/NazaraUtils")
    set_description("Header-only utility library for Nazara projects")
    set_license("MIT")
    set_policy("package.librarydeps.strict_compatibility", true)

    add_urls("https://github.com/NazaraEngine/NazaraUtils.git")

    add_versions("2022.09.06+1", "766043402da9bb19d7771411774096ff9f5dc003")

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
        ]]}, {configs = {languages = "c++17"}, includes = "Nazara/Utils/Bitset.hpp"}))
    end)
