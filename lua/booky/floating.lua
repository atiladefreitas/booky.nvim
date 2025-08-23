local M = {}

local state = require("booky.state")
local utils = require("booky.utils")
local config = require("booky.config")

local buf = nil
local win = nil
local bookmarks_data = {}

-- Create floating window
local function create_float()
	-- Get dimensions
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	-- Calculate floating window size (80% width, 70% height)
	local win_width = math.floor(width * 0.8)
	local win_height = math.floor(height * 0.7)

	-- Calculate position (centered)
	local row = math.floor((height - win_height) / 2)
	local col = math.floor((width - win_width) / 2)

	-- Create buffer
	buf = vim.api.nvim_create_buf(false, true)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "filetype", "booky")

	-- Window options
	local win_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "   Global Bookmarks ",
		title_pos = "center",
	}

	-- Create window
	win = vim.api.nvim_open_win(buf, true, win_opts)

	-- Set window options
	vim.api.nvim_win_set_option(win, "cursorline", true)
	vim.api.nvim_win_set_option(win, "number", false)
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
	vim.api.nvim_win_set_option(win, "wrap", false)
end

-- Render bookmarks content
local function render_content()
	local lines = {}
	local highlights = {}
	bookmarks_data = {}

	-- Get current project for highlighting
	local current_project = utils.get_current_project_root()

	-- Get bookmarks grouped by project
	local projects = state.get_bookmarks_by_project()

	if #projects == 0 then
		table.insert(lines, "")
		table.insert(lines, "  No bookmarks found")
		table.insert(lines, "")
		table.insert(lines, "  Press 'q' or <Esc> to close")
	else
		-- Add header
		table.insert(lines, "")
		local header = string.format(
			"  %d project%s, %d bookmark%s total",
			#projects,
			#projects == 1 and "" or "s",
			#state.get_bookmarks(),
			#state.get_bookmarks() == 1 and "" or "s"
		)
		table.insert(lines, header)
		table.insert(lines, "  " .. string.rep("─", #header - 2))
		table.insert(lines, "")

		-- Render each project
		for _, project in ipairs(projects) do
			local is_current = project.root == current_project

			-- Project header
			local project_header = string.format("  %s %s", is_current and "▶" or "▷", project.name)

			if is_current then
				project_header = project_header .. " (current)"
			end

			table.insert(lines, project_header)
			table.insert(highlights, {
				line = #lines - 1,
				col_start = 0,
				col_end = -1,
				hl_group = is_current and "BookyCurrentProject" or "BookyProjectHeader",
			})

			-- Project path
			local project_path = "  " .. vim.fn.fnamemodify(project.root, ":~")
			table.insert(lines, project_path)
			table.insert(highlights, {
				line = #lines - 1,
				col_start = 0,
				col_end = -1,
				hl_group = "BookyProjectPath",
			})

			-- Bookmarks for this project
			for _, bookmark in ipairs(project.bookmarks) do
				local relative_path = utils.get_relative_path(bookmark.path, project.root)
				local icon = bookmark.line_num and " " or config.options.neotree.icon -- Different icons for line vs file bookmarks
				local display_name = bookmark.line_num and bookmark.name or vim.fn.fnamemodify(relative_path, ":t")

				local bookmark_line
				if bookmark.line_num then
					bookmark_line = string.format("    %s %s (%s)", icon, display_name, relative_path)
				else
					bookmark_line = string.format("    %s %s", icon, relative_path)
				end

				table.insert(lines, bookmark_line)

				-- Store bookmark data for navigation
				table.insert(bookmarks_data, {
					line = #lines - 1,
					path = bookmark.path,
					name = bookmark.name,
					project = project.name,
					line_num = bookmark.line_num,
				})

				-- Highlight bookmark icon
				local icon_hl = bookmark.line_num and "BookyLineBookmarkIcon" or "BookyBookmarkIcon"
				table.insert(highlights, {
					line = #lines - 1,
					col_start = 4,
					col_end = 6,
					hl_group = icon_hl,
				})
			end

			table.insert(lines, "")
		end

		-- Add help footer
		table.insert(lines, "  " .. string.rep("─", 50))
		table.insert(lines, "  [Enter] Open  [d] Delete  [q/Esc] Close  [?] Help")
		table.insert(highlights, {
			line = #lines - 1,
			col_start = 0,
			col_end = -1,
			hl_group = "BookyHelp",
		})
	end

	-- Set buffer content
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)

	-- Apply highlights
	local ns_id = vim.api.nvim_create_namespace("booky_floating")
	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(buf, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
	end
end

-- Get bookmark at current line
local function get_bookmark_at_line()
	local line = vim.api.nvim_win_get_cursor(win)[1] - 1

	for _, bookmark in ipairs(bookmarks_data) do
		if bookmark.line == line then
			return bookmark
		end
	end

	return nil
end

-- Open selected bookmark
local function open_bookmark()
	local bookmark = get_bookmark_at_line()
	if bookmark then
		-- Close floating window
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end

		-- Open file
		vim.cmd("edit " .. vim.fn.fnameescape(bookmark.path))

		-- If it's a line bookmark, jump to the specific line
		if bookmark.line_num then
			vim.api.nvim_win_set_cursor(0, { bookmark.line_num, 0 })
			-- Center the line in the window
			vim.cmd("normal! zz")
		end
	end
end

-- Delete selected bookmark
local function delete_bookmark()
	local bookmark = get_bookmark_at_line()
	if bookmark then
		state.remove_bookmark(bookmark.path)
		vim.notify("Removed bookmark: " .. bookmark.name .. " from " .. bookmark.project, vim.log.levels.INFO)

		-- Re-render content
		render_content()
	end
end

-- Setup keymaps for floating window
local function setup_keymaps()
	local opts = { noremap = true, silent = true, buffer = buf }

	-- Close window
	vim.keymap.set("n", "q", function()
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, opts)

	vim.keymap.set("n", "<Esc>", function()
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, opts)

	-- Open bookmark
	vim.keymap.set("n", "<CR>", open_bookmark, opts)
	vim.keymap.set("n", "o", open_bookmark, opts)

	-- Delete bookmark
	vim.keymap.set("n", "d", delete_bookmark, opts)
	vim.keymap.set("n", "x", delete_bookmark, opts)

	-- Refresh
	vim.keymap.set("n", "r", render_content, opts)

	-- Navigation (additional)
	vim.keymap.set("n", "<C-d>", "<C-d>", opts)
	vim.keymap.set("n", "<C-u>", "<C-u>", opts)

	-- Help
	vim.keymap.set("n", "?", function()
		M.show_help()
	end, opts)
end

-- Setup highlight groups
local function setup_highlights()
	vim.api.nvim_set_hl(0, "BookyProjectHeader", { fg = "#7aa2f7", bold = true, default = true })
	vim.api.nvim_set_hl(0, "BookyCurrentProject", { fg = "#9ece6a", bold = true, default = true })
	vim.api.nvim_set_hl(0, "BookyProjectPath", { fg = "#565f89", italic = true, default = true })
	vim.api.nvim_set_hl(0, "BookyHelp", { fg = "#565f89", default = true })
	vim.api.nvim_set_hl(0, "BookyLineBookmarkIcon", { fg = "#e0af68", default = true }) -- Yellow for line bookmarks
end

-- Show help in separate floating window
function M.show_help()
	local config = require("booky.config")

	-- Get dimensions for help window
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")

	local help_width = math.min(60, math.floor(width * 0.6))
	local help_height = math.min(25, math.floor(height * 0.6))

	local help_row = math.floor((height - help_height) / 2)
	local help_col = math.floor((width - help_width) / 2)

	-- Create help buffer
	local help_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(help_buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(help_buf, "filetype", "booky-help")

	-- Help window options
	local help_opts = {
		relative = "editor",
		width = help_width,
		height = help_height,
		row = help_row,
		col = help_col,
		style = "minimal",
		border = "rounded",
		title = " 📖 Booky Help ",
		title_pos = "center",
	}

	-- Create help window
	local help_win = vim.api.nvim_open_win(help_buf, true, help_opts)

	-- Help content
	local help_lines = {
		"",
		" Navigation:",
		"   j/k, ↓/↑   Move up/down",
		"   gg/G       Go to top/bottom",
		"   Ctrl-d/u   Page down/up",
		"",
		" Actions:",
		"   Enter, o   Open bookmark",
		"   d, x       Delete bookmark",
		"   r          Refresh list",
		"   ?          Show this help",
		"   q, Esc     Close window",
		"",
		" Keymaps (Global):",
		"   " .. config.options.keymaps.add_bookmark .. "        Add/toggle file bookmark",
		"   " .. config.options.keymaps.add_line_bookmark .. "        Add line bookmark",
		"   " .. config.options.keymaps.toggle_telescope .. "        Project bookmarks",
		"   " .. config.options.keymaps.global_bookmarks .. "        Global bookmarks",
		"",
		" Legend:",
		"   ▶ Current project",
		"   ▷ Other projects",
		"   " .. config.options.neotree.icon .. " File bookmark",
		"    Line bookmark",
		"",
		" Press any key to close help...",
	}

	-- Set help content
	vim.api.nvim_buf_set_option(help_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
	vim.api.nvim_buf_set_option(help_buf, "modifiable", false)

	-- Add highlights
	local help_ns = vim.api.nvim_create_namespace("booky_help")

	-- Title highlight
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyProjectHeader", 1, 0, -1)
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyProjectHeader", 3, 0, -1)

	-- Section headers
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyCurrentProject", 6, 0, -1) -- Navigation
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyCurrentProject", 11, 0, -1) -- Actions
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyCurrentProject", 18, 0, -1) -- Keymaps
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyCurrentProject", 23, 0, -1) -- Legend

	-- Keymaps highlight
	for i = 19, 22 do
		vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyBookmarkIcon", i, 3, 8)
	end

	-- Icons highlight
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyCurrentProject", 25, 3, 4) -- ▶
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyProjectHeader", 26, 3, 4) -- ▷
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyBookmarkIcon", 27, 3, 5) -- file bookmark
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyLineBookmarkIcon", 28, 3, 5) -- line bookmark

	-- Footer
	vim.api.nvim_buf_add_highlight(help_buf, help_ns, "BookyHelp", #help_lines - 1, 0, -1)

	-- Set window options
	vim.api.nvim_win_set_option(help_win, "cursorline", false)
	vim.api.nvim_win_set_option(help_win, "number", false)
	vim.api.nvim_win_set_option(help_win, "relativenumber", false)
	vim.api.nvim_win_set_option(help_win, "signcolumn", "no")
	vim.api.nvim_win_set_option(help_win, "wrap", false)

	-- Close help on any key
	local help_opts_local = { noremap = true, silent = true, buffer = help_buf }

	-- Close on common keys
	local close_keys = { "q", "<Esc>", "<CR>", " ", "?", "h" }
	for _, key in ipairs(close_keys) do
		vim.keymap.set("n", key, function()
			if help_win and vim.api.nvim_win_is_valid(help_win) then
				vim.api.nvim_win_close(help_win, true)
			end
		end, help_opts_local)
	end

	-- Also close on any other key press
	vim.keymap.set("n", "<buffer>", function()
		if help_win and vim.api.nvim_win_is_valid(help_win) then
			vim.api.nvim_win_close(help_win, true)
		end
	end, help_opts_local)
end

-- Open global bookmarks floating window
function M.open_global_bookmarks()
	setup_highlights()
	create_float()
	render_content()
	setup_keymaps()
end

return M
