package("nzsl")
	set_homepage("https://github.com/NazaraEngine")
	set_description("NZSL is a shader language inspired by Rust and C++ which compiles to GLSL or SPIRV")
	set_license("MIT")

	add_urls("https://github.com/NazaraEngine/ShaderLang.git")

	add_versions("2022.05.22", "793ac9f02332171c1d050f5f5d8163da61336ec3")

	add_deps("nazarautils")
	add_deps("fmt", "efsw", "frozen", "ordered_map", { private = true })

	on_load(function (package)
        package:addenv("PATH", "bin")
		if not package:config("shared") then
			package:add("defines", "NZSL_STATIC")
		end
	end)

	on_install("windows", "linux", "mingw", "macosx", function (package)
		import("package.tools.xmake").install(package)
	end)

	on_test(function (package)
        os.vrun("nzslc --help")
		assert(package:check_cxxsnippets({test = [[
			void test() {
				nzsl::ShaderAst::ModulePtr shaderModule = nzsl::ShaderLang::Parse(R"(
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
		]]}, {configs = {languages = "c++17"}, includes = "NZSL/ShaderLangParser.hpp"}))
	end)
