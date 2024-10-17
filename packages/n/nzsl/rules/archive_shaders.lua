-- Merge binary shaders to archivess
rule("archive.shaders")
	add_deps("@nzsl/find_nzsl")
	add_deps("@nzsl/compile.shaders", { order = true })

	before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
		local nzsla = target:data("nzsla")
		local runenvs = target:data("nzsl_runenv")
		assert(nzsla, "nzsla not found! please install nzsl package with nzsla enabled")

		local fileconfig = target:fileconfig(sourcefile)

		batchcmds:show_progress(opt.progress, "${color.build.object}archiving.shaders %s", sourcefile)
		local argv = { "--archive", "--output=" .. sourcefile }

		if fileconfig.compress then
			if type(fileconfig.compress) == "string" then
				table.insert(argv, "--compress=" .. fileconfig.compress)
			else
				table.insert(argv, "--compress")
			end
		end

		if fileconfig.header then
			table.insert(argv, "--header")
		end

		for _, shaderfile in ipairs(fileconfig.files) do
			table.insert(argv, shaderfile)
			batchcmds:add_depfiles(shaderfile)
		end

		batchcmds:vrunv(nzsla.program, argv, { curdir = ".", envs = runenvs })

		-- add deps
		batchcmds:add_depvalues(nzsla.version)
		batchcmds:set_depmtime(os.mtime(sourcefile))
		batchcmds:set_depcache(target:dependfile(sourcefile))
end)
