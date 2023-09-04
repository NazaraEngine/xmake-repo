-- Compile shaders to includables headers
rule("compile.shaders")
	set_extensions(".nzsl",	".nzslb")

	on_config(function(target)
		-- add outputdir to include	path
		local outputdir	= target:extraconf("rules", "compile.shaders", "outputdir") or path.join(target:autogendir(), "rules", "compile.shaders")
		if not os.isdir(outputdir) then
			os.mkdir(outputdir)
		end
		target:add("includedirs", outputdir)
	end)

	before_buildcmd_file(function (target, batchcmds, shaderfile, opt)
		import("core.tool.toolchain")
        import("lib.detect.find_tool")

		local outputdir	= target:extraconf("rules", "compile.shaders", "outputdir") or path.join(target:autogendir(), "rules", "compile.shaders")
		local fileconfig = target:fileconfig(shaderfile)
		if fileconfig and fileconfig.prefixdir then
			outputdir = path.join(outputdir, fileconfig.prefixdir)
		end

		-- on mingw we need run envs because of .dll dependencies which may be not part of the PATH
		local envs
		if is_plat("mingw") then
			local mingw = toolchain.load("mingw")
			if mingw and mingw:check() then
				envs = mingw:runenvs()
			end
		end

		-- find nzslc
		local pkgdir = target:pkg("nzsl") and target:pkg("nzsl"):installdir()
		local nzslc = find_tool("nzslc", { paths = pkgdir and {path.join(pkgdir, "bin")} or nil, envs = envs })
		assert(nzslc, "nzslc not found! please install nzsl package")

		-- add commands
		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.shader %s", shaderfile)
		local argv = { "--compile=nzslb-header", "--partial", "--optimize", "--output="	.. outputdir }
		batchcmds:mkdir(outputdir)

		-- handle --log-format
		local kind = target:data("plugin.project.kind") or ""
		if kind:match("vs") then
			table.insert(argv, "--log-format=vs")
		end

		table.insert(argv, shaderfile)

		batchcmds:vrunv(nzslc.program, argv, { curdir = ".", envs = envs })

		local outputFile = path.join(path.directory(shaderfile), path.basename(shaderfile) .. ".nzslb.h")

		-- add deps
		batchcmds:add_depfiles(shaderfile)
		batchcmds:set_depmtime(os.mtime(outputFile))
		batchcmds:set_depcache(target:dependfile(outputFile))
	end)
