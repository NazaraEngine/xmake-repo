-- Compile shaders to includables headers
rule("compile.shaders")
	set_extensions(".nzsl", ".nzslb")

	on_config(function(target)
		if not target:extraconf("rules", "@nzsl/compile.shaders", "inplace") then
			-- add outputdir to include path
			local outputdir = target:extraconf("rules", "@nzsl/compile.shaders", "outputdir") or path.join(target:autogendir(), "rules", "nzsl.shaders")
			if not os.isdir(outputdir) then
				os.mkdir(outputdir)
			end
			target:add("includedirs", outputdir)
		end
	end)

	before_buildcmd_file(function (target, batchcmds, shaderfile, opt)
		import("core.tool.toolchain")
		import("lib.detect.find_tool")
		import("core.project.project")

		local outputdir
		if not target:extraconf("rules", "@nzsl/compile.shaders", "inplace") then
			outputdir = target:extraconf("rules", "@nzsl/compile.shaders", "outputdir") or path.join(target:autogendir(), "rules", "nzsl.shaders")
			local fileconfig = target:fileconfig(shaderfile)
			if fileconfig and fileconfig.prefixdir then
				outputdir = path.join(outputdir, fileconfig.prefixdir)
			end
		end

		-- on windows+asan/mingw we need run envs because of .dll dependencies which may be not part of the PATH
		local envs
		if package:is_plat("windows") then
			import("core.tool.toolchain")
			local msvc = toolchain.load("msvc")
			if msvc and msvc:check() then
				envs = msvc:runenvs()
			end
		elseif package:is_plat("mingw") then
			import("core.tool.toolchain")
			local mingw = toolchain.load("mingw")
			if mingw and mingw:check() then
				envs = mingw:runenvs()
			end
		end

		-- find nzslc
		local nzsl = project.required_package("nzsl~host") or project.required_package("nzsl")
		local nzsldir
		if nzsl then
			nzsldir = path.join(nzsl:installdir(), "bin")
		end

		local nzslc = find_tool("nzslc", { paths = nzsldir, envs = envs })
		assert(nzslc, "nzslc not found! please install nzsl package")

		-- add commands
		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.shader %s", shaderfile)
		local argv = { "--compile=nzslb-header", "--partial", "--optimize" }
		if outputdir then
			batchcmds:mkdir(outputdir)
			table.insert(argv, "--output=" .. outputdir)
		end

		-- handle --log-format
		local kind = target:data("plugin.project.kind") or ""
		if kind:match("vs") then
			table.insert(argv, "--log-format=vs")
		end

		table.insert(argv, shaderfile)

		batchcmds:vrunv(nzslc.program, argv, { curdir = ".", envs = envs })

		local outputfile = path.join(outputdir or path.directory(shaderfile), path.basename(shaderfile) .. ".nzslb.h")

		-- add deps
		batchcmds:add_depfiles(shaderfile)
		batchcmds:add_depvalues(nzsl:version())
		batchcmds:set_depmtime(os.mtime(outputfile))
		batchcmds:set_depcache(target:dependfile(outputfile))
	end)
