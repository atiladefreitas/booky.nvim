local M = {}

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
	return M
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local themes = require("telescope.themes")
local previewers = require("telescope.previewers")

-- Optional dependencies for enhanced UI
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local has_lsp_util, lsp_util = pcall(require, "telescope.utils")

-- Helper function to get file icon with highlight support
local function get_file_icon(path, extension)
	if not has_devicons then
		return " ", nil
	end

	local icon, hl_group = devicons.get_icon(vim.fn.fnamemodify(path, ":t"), extension, { default = true })
	return icon or " ", hl_group
end

-- Helper function to create display with highlight groups
local function make_display(entry)
	local displayer = require("telescope.pickers.entry_display").create({
		separator = " ",
		items = {
			{ width = 2 }, -- file icon
			{ width = 1 }, -- bookmark icon
			{ remaining = true }, -- bookmark name and path
		},
	})

	return displayer({
		{ entry.file_icon, entry.icon_hl_group },
		{ entry.bookmark_icon, "TelescopeResultsComment" },
		{ entry.text, "TelescopeResultsNormal" },
	})
end

-- Open bookmark picker (project-specific by default)
function M.open_bookmark_picker(show_all)
	local state = require("booky.state")
	local config = require("booky.config")
	local utils = require("booky.utils")

	local bookmarks
	local current_project_root

	if show_all then
		bookmarks = state.get_bookmarks()
	else
		current_project_root = utils.get_current_project_root()
		bookmarks = state.get_project_bookmarks(current_project_root)
	end

	if #bookmarks == 0 then
		if show_all then
			vim.notify("No bookmarks found", vim.log.levels.INFO)
		else
			local project_name = utils.get_project_name(current_project_root)
			vim.notify("No bookmarks found in project: " .. project_name, vim.log.levels.INFO)
		end
		return
	end

	-- Prepare entries for telescope
	local entries = {}
	for _, bookmark in ipairs(bookmarks) do
		local file_icon, icon_hl_group = get_file_icon(bookmark.path, vim.fn.fnamemodify(bookmark.path, ":e"))
		local bookmark_icon = bookmark.line_num and " " or " " -- Different icons for line vs file bookmarks

		local text
		if show_all then
			-- Show project name for global view
			local relative_path = utils.get_relative_path(bookmark.path, bookmark.project_root)
			text = string.format("[%s] %s (%s)", bookmark.project_name or "Unknown", bookmark.name, relative_path)
		else
			-- Show relative path for project view
			local relative_path = utils.get_relative_path(bookmark.path, current_project_root)
			text = bookmark.name .. " (" .. relative_path .. ")"
		end

		table.insert(entries, {
			path = bookmark.path,
			name = bookmark.name,
			line_num = bookmark.line_num,
			file_icon = file_icon,
			bookmark_icon = bookmark_icon,
			icon_hl_group = icon_hl_group,
			text = text,
		})
	end

	local opts = {}

	-- Apply theme if specified, otherwise use default telescope config
	if config.options.telescope.theme == "dropdown" then
		opts = themes.get_dropdown({})
	elseif config.options.telescope.theme == "ivy" then
		opts = themes.get_ivy({})
	elseif config.options.telescope.theme == "cursor" then
		opts = themes.get_cursor({})
	end
	-- If theme is nil, opts remains empty, inheriting user's default telescope config

	if show_all then
		opts.prompt_title = " Global Bookmarks"
		opts.results_title = "All Projects"
	else
		local project_name = utils.get_project_name(current_project_root)
		opts.prompt_title = " 󰐃 " .. project_name .. " Bookmarks"
		opts.results_title = "Project Files"
	end

	pickers
		.new(opts, {
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return {
						value = entry,
						display = make_display,
						path = entry.path,
						ordinal = entry.name .. " " .. entry.path,
						lnum = entry.line_num, -- LSP-compatible line number
						file_icon = entry.file_icon,
						bookmark_icon = entry.bookmark_icon,
						icon_hl_group = entry.icon_hl_group,
						text = entry.text,
					}
				end,
			}),
			sorter = conf.file_sorter(opts), -- Use file sorter for better file handling
			previewer = previewers.new_buffer_previewer({
				title = "Bookmark Preview",
				get_buffer_by_name = function(_, entry)
					return entry.path
				end,
				define_preview = function(self, entry, status)
					local file_path = entry.path
					local line_num = entry.lnum or 1

					-- Use telescope's built-in file preview
					conf.buffer_previewer_maker(file_path, self.state.bufnr, {
						bufname = self.state.bufname,
						winid = self.state.winid,
						callback = function(bufnr)
							-- Schedule the centering and highlighting after buffer is loaded
							vim.schedule(function()
								if line_num and line_num > 0 and vim.api.nvim_win_is_valid(self.state.winid) then
									-- Set cursor to the bookmarked line
									pcall(vim.api.nvim_win_set_cursor, self.state.winid, { line_num, 0 })

									-- Center the line in the preview window
									vim.api.nvim_win_call(self.state.winid, function()
										-- Use multiple centering commands for better effect
										vim.cmd("normal! zz")
										vim.cmd("redraw")
									end)

									-- Add highlighting to the bookmarked line
									local ns_id = vim.api.nvim_create_namespace("booky_telescope_highlight")
									vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
									pcall(
										vim.api.nvim_buf_add_highlight,
										bufnr,
										ns_id,
										"CursorLine",
										line_num - 1,
										0,
										-1
									)
								end
							end)
						end,
					})
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						-- Open the selected file
						vim.cmd("edit " .. vim.fn.fnameescape(selection.path))

						-- If it's a line bookmark, jump to the specific line
						if selection.value.line_num then
							vim.api.nvim_win_set_cursor(0, { selection.value.line_num, 0 })
							-- Center the line in the window
							vim.cmd("normal! zz")
						end
					end
				end)

				-- Add custom mapping to remove bookmark
				map("i", "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						state.remove_bookmark(selection.path)
						vim.notify("Removed bookmark: " .. selection.value.name, vim.log.levels.INFO)
						-- Close and reopen picker to refresh
						actions.close(prompt_bufnr)
						vim.defer_fn(function()
							M.open_bookmark_picker()
						end, 10)
					end
				end)

				map("n", "<C-d>", function()
					local selection = action_state.get_selected_entry()
					if selection then
						state.remove_bookmark(selection.path)
						vim.notify("Removed bookmark: " .. selection.value.name, vim.log.levels.INFO)
						-- Close and reopen picker to refresh
						actions.close(prompt_bufnr)
						vim.defer_fn(function()
							M.open_bookmark_picker()
						end, 10)
					end
				end)

				return true
			end,
		})
		:find()
end

return M
