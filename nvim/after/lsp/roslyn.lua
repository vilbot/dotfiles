local rzls_path = vim.fn.expand("$MASON/packages/roslyn/libexec/.razorExtension")

return {
	cmd = {
		"roslyn",
		"--stdio",
		"--logLevel=Information",
		"--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.log.get_filename()),
		"--razorSourceGenerator=" .. vim.fs.joinpath(rzls_path, "Microsoft.CodeAnalysis.Razor.Compiler.dll"),
		"--razorDesignTimePath=" .. vim.fs.joinpath(rzls_path, "Targets", "Microsoft.NET.Sdk.Razor.DesignTime.targets"),
		"--extension",
		vim.fs.joinpath(rzls_path, "Microsoft.VisualStudioCode.RazorExtension.dll"),
	},
	handlers = require("roslyn.razor.handlers"),
	filetypes = { "cs", "razor" },
	root_markers = { { ".sln", ".csproj", "project.json" }, ".git" },
}
