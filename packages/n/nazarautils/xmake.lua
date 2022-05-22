package("nazarautils")
	set_homepage("https://github.com/NazaraEngine")
	set_description("Header-only utility library for Nazara projects")
	set_license("MIT")

	add_urls("https://github.com/NazaraEngine/NazaraUtils.git")

	add_versions("2022.05.22", "d568fbfec7283c935599cdc85456d340a85edf0b")

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
