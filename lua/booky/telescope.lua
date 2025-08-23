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
		local display
		if show_all then
			-- Show project name for global view
			local relative_path = utils.get_relative_path(bookmark.path, bookmark.project_root)
			display = string.format("[%s] %s (%s)", bookmark.project_name or "Unknown", bookmark.name, relative_path)
		else
			-- Show relative path for project view
			local relative_path = utils.get_relative_path(bookmark.path, current_project_root)
			display = bookmark.name .. " (" .. relative_path .. ")"
		end

		table.insert(entries, {
			path = bookmark.path,
			name = bookmark.name,
			display = display,
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
						display = entry.display,
						path = entry.path,
						ordinal = entry.name .. " " .. entry.path,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			previewer = conf.file_previewer(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)

					if selection then
						-- Open the selected file
						vim.cmd("edit " .. vim.fn.fnameescape(selection.path))
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
