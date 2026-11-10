return {
	{
		"basola21/PDFview",
		lazy = false,
		dependencies = { "nvim-telescope/telescope.nvim" },
		init = function()
			vim.api.nvim_create_autocmd("BufReadPost", {
				pattern = "*.pdf",
				callback = function()
					local file_path = vim.api.nvim_buf_get_name(0)
					require("pdfview").open(file_path)
				end,
			})
		end,
		keys = {
			-- Navigate to the next page in the PDF (supports counts, e.g., 5<leader>jj)
			{
				"<leader>jj",
				function()
					local count = vim.v.count1
					for _ = 1, count do
						require('pdfview.renderer').next_page()
					end
				end,
				desc = "PDFview: Next page(s)",
			},
			-- Navigate to the previous page in the PDF (supports counts, e.g., 5<leader>kk)
			{
				"<leader>kk",
				function()
					local count = vim.v.count1
					for _ = 1, count do
						require('pdfview.renderer').previous_page()
					end
				end,
				desc = "PDFview: Previous page(s)",
			},
			-- Navigate to the next page in the PDF
			-- map("n", "<leader>jj", "<cmd>:lua require('pdfview.renderer').next_page()<CR>", { desc = "PDFview: Next page" })

			-- Navigate to the previous page in the PDF
			-- map("n", "<leader>kk", "<cmd>:lua require('pdfview.renderer').previous_page()<CR>", { desc = "PDFview: Previous page" })
		},
	},
}
