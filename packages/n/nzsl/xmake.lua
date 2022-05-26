package("nzsl")
	set_homepage("https://github.com/NazaraEngine")
	set_description("NZSL is a shader language inspired by Rust and C++ which compiles to GLSL or SPIRV")
	set_license("MIT")

	add_urls("https://github.com/NazaraEngine/ShaderLang.git")

	add_versions("2022.05.26", "4864bd4ccb0859a7fe9c3aca333146eb4127305b")

	add_deps("nazarautils")
	add_deps("frozen", "ordered_map", { private = true })

	add_configs("with_nzslc", {description = "Includes standalone compiler", default = true, type = "boolean"})
	if is_plat("windows", "linux", "mingw", "macosx", "bsd") then
		add_configs("fs_watcher", {description = "Includes filesystem watcher", default = true, type = "boolean"})
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

	on_install("windows", "linux", "mingw", "macosx", "bsd", "iphoneos", "android", function (package)
        local configs = {}
		configs.fs_watcher = package:config("fs_watcher") or false
		configs.with_nzslc = package:config("with_nzslc") or false
		import("package.tools.xmake").install(package, configs)
	end)

	on_test(function (package)
		if package:config("with_nzslc") then
        	os.vrun("nzslc --version")
		end
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
		]]}, {configs = {languages = "c++17"}, includes = "NZSL/ShaderLangParser.hpp"}))
	end)
