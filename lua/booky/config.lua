local M = {}

M.options = {
	-- File to store bookmarks
	save_path = vim.fn.stdpath("data") .. "/booky_bookmarks.json",

	-- Keymaps
	keymaps = {
		add_bookmark = "<leader>ba", -- Add current file to bookmarks
		add_line_bookmark = "<leader>bl", -- Add current line to bookmarks
		toggle_telescope = "<leader>bb", -- Open telescope bookmark picker (project)
		global_bookmarks = "<leader>bg", -- Open global bookmarks in floating window
	},

	-- NeoTree integration
	neotree = {
		enabled = true,
		icon = "", -- Orange bookmark nerd font icon
		line_icon = "󰘦", -- Line bookmark icon
		highlight = "BookyBookmarkIcon",
	},

	-- Telescope integration
	telescope = {
		enabled = true,
		theme = nil, -- nil (default), "dropdown", "ivy", "cursor"
		prompt_title = "  Bookmarks ",
		results_title = "Files",
	},
}

function M.setup(opts)
	if opts then
		M.options = vim.tbl_deep_extend("force", M.options, opts)
	end

	-- Create highlight group for bookmark icon
	vim.api.nvim_set_hl(0, "BookyBookmarkIcon", { fg = "#FFA500", default = true })
end

return M
