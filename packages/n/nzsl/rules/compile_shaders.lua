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
		import("core.project.project")
		import("core.tool.toolchain")

		local outputdir	= target:extraconf("rules", "compile.shaders", "outputdir") or path.join(target:autogendir(), "rules", "compile.shaders")
		local fileconfig = target:fileconfig(shaderfile)
		if fileconfig and fileconfig.prefixdir then
			outputdir = path.join(outputdir, fileconfig.prefixdir)
		end

		-- warning: project.required_package is not a stable interface, this may break in the future
		local nzsl = path.join(project.required_package("nzsl"):installdir(), "bin", "nzslc")

		-- add commands
		batchcmds:show_progress(opt.progress, "${color.build.object}compiling.shader %s", shaderfile)
		local argv = { "--compile=nzslb-header", "--partial", "--optimize", "--output="	.. outputdir }

		-- handle --log-format
		local kind = target:data("plugin.project.kind") or ""
		if kind:match("vs") then
			table.insert(argv, "--log-format=vs")
		end

		table.insert(argv, shaderfile)

		-- on mingw we need run envs because of .dll dependencies which may be not part of the PATH
		local envs
		if is_plat("mingw") then
			local mingw = toolchain.load("mingw")
			if mingw and mingw:check() then
				envs = mingw:runenvs()
			end
		end

		batchcmds:vrunv(nzsl, argv, { curdir = ".", envs = envs })

		local outputFile = path.join(path.directory(shaderfile), path.basename(shaderfile) .. ".nzslb.h")

		-- add deps
		batchcmds:add_depfiles(shaderfile)
		batchcmds:set_depmtime(os.mtime(outputFile))
		batchcmds:set_depcache(target:dependfile(outputFile))
	end)
