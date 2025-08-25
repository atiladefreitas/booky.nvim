local M = {}

-- Cache for decorated buffers and their state
local decoration_cache = {}
local debounce_timers = {}

-- Setup function to register with NeoTree
function M.setup()
	local has_neotree = pcall(require, "neo-tree")
	if not has_neotree then
		return
	end

	local config = require("booky.config")
	if not config.options.neotree.enabled then
		return
	end

	-- Register immediately and also setup manual decorations as fallback
	M.register_decorator()
	M.setup_manual_decorations()

	-- Also try after a short delay for safety
	vim.defer_fn(function()
		M.register_decorator()
		M.decorate_neotree_buffers()
	end, 100) -- Shorter delay
end

-- Register the decorator using NeoTree's proper API
function M.register_decorator()
	local ok, renderers = pcall(require, "neo-tree.ui.renderers")
	if not ok then
		-- Fallback to manual decoration approach
		M.setup_manual_decorations()
		return
	end

	-- Try to access the renderer system
	if renderers and renderers.add_decorator then
		local config = require("booky.config")
		local state = require("booky.state")

		renderers.add_decorator({
			name = "booky_bookmarks",
			render = function(node)
				if node.type == "file" and state.is_bookmarked(node:get_id()) then
					return {
						text = " " .. config.options.neotree.icon,
						highlight = config.options.neotree.highlight,
					}
				end
				return {}
			end,
		})
	else
		-- Fallback approach
		M.setup_manual_decorations()
	end
end

-- Manual decoration approach using autocmds
function M.setup_manual_decorations()
	-- Hook into NeoTree events if available
	vim.api.nvim_create_autocmd({
		"BufEnter",
		"BufWritePost",
		"BufWinEnter",
		"WinEnter",
		"FocusGained",
		"VimResized",
		"CursorMoved",
		"CursorMovedI",
		"TextChanged",
		"TextChangedI",
	}, {
		pattern = "*",
		callback = function(args)
			local buf_name = vim.api.nvim_buf_get_name(args.buf)
			if buf_name:match("neo%-tree") then
				M.debounced_decorate(args.buf)
			end
		end,
	})

	-- More specific NeoTree events
	vim.api.nvim_create_autocmd("User", {
		pattern = { "neo-tree*", "NeotreePopulated", "NeotreeBufferEnter" },
		callback = function()
			vim.defer_fn(function()
				M.decorate_neotree_buffers()
			end, 10)
		end,
	})

	-- Handle focus events more precisely
	vim.api.nvim_create_autocmd({ "WinEnter", "FocusGained" }, {
		pattern = "*",
		callback = function()
			-- Only refresh if we're entering a NeoTree window or gaining focus
			vim.defer_fn(function()
				local current_win = vim.api.nvim_get_current_win()
				local bufnr = vim.api.nvim_win_get_buf(current_win)
				local buf_name = vim.api.nvim_buf_get_name(bufnr)
				if buf_name:match("neo%-tree") then
					M.add_decorations_to_buffer(bufnr)
				end
			end, 50)
		end,
	})

	-- Clean up cache when buffers are deleted
	vim.api.nvim_create_autocmd("BufDelete", {
		pattern = "*",
		callback = function(args)
			M.clear_cache(args.buf)
		end,
	})
end

-- Debounced decoration to prevent excessive calls
function M.debounced_decorate(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Clear existing timer for this buffer
	if debounce_timers[bufnr] then
		vim.fn.timer_stop(debounce_timers[bufnr])
	end

	-- Set new timer with debounce
	debounce_timers[bufnr] = vim.fn.timer_start(50, function()
		M.add_decorations_to_buffer(bufnr)
		debounce_timers[bufnr] = nil
	end)
end

-- Decorate all NeoTree buffers
function M.decorate_neotree_buffers()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			if buf_name:match("neo%-tree") then
				M.add_decorations_to_buffer(bufnr)
			end
		end
	end
end

-- Add decorations to a specific buffer
function M.add_decorations_to_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local config = require("booky.config")
	local state = require("booky.state")
	local utils = require("booky.utils")

	-- Create namespace for our decorations
	local ns_id = vim.api.nvim_create_namespace("booky_bookmarks")

	-- Check if we need to update decorations (performance optimization)
	local current_tick = vim.api.nvim_buf_get_changedtick(bufnr)
	if decoration_cache[bufnr] and decoration_cache[bufnr].tick == current_tick then
		-- Still check if decorations actually exist
		local existing_marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
		if #existing_marks > 0 then
			return -- No changes and decorations exist, skip update
		end
	end

	-- Only clear existing decorations when actually needed
	local existing_marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
	if #existing_marks > 0 then
		vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
	end

	-- Initialize cache for this buffer
	decoration_cache[bufnr] = { tick = current_tick, decorations = {} }

	-- Get current working directory and project root for relative path resolution
	local cwd = vim.fn.getcwd()
	local current_project_root = utils.get_project_root(cwd)

	-- Get all lines in the buffer
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for i, line in ipairs(lines) do
		-- Extract filename from NeoTree line (improved pattern)
		local filename = line:match("([^%s│├└─▸▾@]+%.%w+)%s*$")

		if filename then
			-- Get only bookmarks for the current project
			local project_bookmarks = state.get_project_bookmarks(current_project_root)
			local found_match = false

			for _, bookmark in ipairs(project_bookmarks) do
				-- Check if the filename matches the end of any bookmark path
				if
					bookmark.path:match("/" .. filename:gsub("%-", "%%-") .. "$")
					or bookmark.path:match("/" .. filename:gsub("%.", "%%.") .. "$")
					or bookmark.name == filename
				then
					-- Add virtual text decoration at far right with persistent options
					local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, #line, {
						virt_text = { { config.options.neotree.icon, config.options.neotree.highlight } },
						virt_text_pos = "right_align",
						invalidate = false, -- Keep extmarks when buffer changes
						strict = false, -- Allow positioning even if line changes
					})
					-- Cache the decoration
					decoration_cache[bufnr].decorations[i] = extmark_id
					found_match = true
					break
				end
			end

			-- Fallback: try relative path from current working directory (but still check if it's in current project)
			if not found_match then
				local relative_path = cwd .. "/" .. filename
				if vim.fn.filereadable(relative_path) == 1 then
					local full_path = vim.fn.resolve(vim.fn.expand(relative_path))
					-- Only show bookmark if the file is actually bookmarked AND within the current project
					local file_project_root = utils.get_project_root(full_path)
					if file_project_root == current_project_root and state.is_bookmarked(full_path) then
						-- Add virtual text decoration at far right with persistent options
						local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, #line, {
							virt_text = { { config.options.neotree.icon, config.options.neotree.highlight } },
							virt_text_pos = "right_align",
							invalidate = false, -- Keep extmarks when buffer changes
							strict = false, -- Allow positioning even if line changes
						})
						-- Cache the decoration
						decoration_cache[bufnr].decorations[i] = extmark_id
					end
				end
			end
		end
	end
end

-- Clear decoration cache for a specific buffer
function M.clear_cache(bufnr)
	if bufnr then
		decoration_cache[bufnr] = nil
		if debounce_timers[bufnr] then
			vim.fn.timer_stop(debounce_timers[bufnr])
			debounce_timers[bufnr] = nil
		end
	else
		-- Clear all cache
		decoration_cache = {}
		for _, timer_id in pairs(debounce_timers) do
			vim.fn.timer_stop(timer_id)
		end
		debounce_timers = {}
	end
end

-- Function to refresh NeoTree display
function M.refresh()
	-- Clear cache to force refresh
	M.clear_cache()

	-- Force refresh all NeoTree buffers
	M.decorate_neotree_buffers()

	-- Also try to refresh NeoTree itself
	local has_neotree, manager = pcall(require, "neo-tree.sources.manager")
	if has_neotree and manager then
		manager.refresh("filesystem")
	end

	-- Alternative refresh method
	vim.cmd("silent! Neotree refresh")
end

-- Debug function to help troubleshoot decorations
function M.debug_decorations()
	print("\n=== NEOTREE DEBUG ===")

	local state = require("booky.state")
	local config = require("booky.config")

	-- Find NeoTree buffers and test decorations
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			local buf_name = vim.api.nvim_buf_get_name(bufnr)
			if buf_name:match("neo%-tree") then
				print(string.format("Processing NeoTree buffer %d: %s", bufnr, buf_name))

				-- Get current working directory
				local cwd = vim.fn.getcwd()
				print("Current working directory:", cwd)

				-- Get lines and try to match paths
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				print("Total lines in buffer:", #lines)

				for i, line in ipairs(lines) do
					if i <= 10 then -- Only show first 10 for debugging
						print(string.format("  Line %d: '%s'", i, line))

						-- Test our pattern matching
						local filename = line:match("([^%s│├└─▸▾@]+%.%w+)%s*$")
						if filename then
							print(string.format("    -> Found filename: %s", filename))

							-- Get current project root for debugging
							local utils = require("booky.utils")
							local current_project_root = utils.get_project_root(cwd)
							print(string.format("    -> Current project root: %s", current_project_root))
							
							-- Get only bookmarks for current project
							local project_bookmarks = state.get_project_bookmarks(current_project_root)
							local found_match = false

							for _, bookmark in ipairs(project_bookmarks) do
								-- Check if the filename matches the end of any bookmark path
								if
									bookmark.path:match("/" .. filename:gsub("%-", "%%-") .. "$")
									or bookmark.path:match("/" .. filename:gsub("%.", "%%.") .. "$")
									or bookmark.name == filename
								then
									print(string.format("    -> MATCHED bookmark: %s", bookmark.path))
									print("    -> SHOULD ADD DECORATION!")
									M.test_decoration(bufnr, i - 1, line)
									found_match = true
									break
								end
							end

							if not found_match then
								-- Fallback: Try relative path from current working directory (but check project)
								local relative_path = cwd .. "/" .. filename
								print(string.format("    -> Trying path: %s", relative_path))
								print(
									string.format("    -> File readable: %s", vim.fn.filereadable(relative_path) == 1)
								)
								
								if vim.fn.filereadable(relative_path) == 1 then
									local full_path = vim.fn.resolve(vim.fn.expand(relative_path))
									local file_project_root = utils.get_project_root(full_path)
									print(string.format("    -> File project root: %s", file_project_root))
									print(string.format("    -> Current project root: %s", current_project_root))
									print(string.format("    -> Is bookmarked: %s", state.is_bookmarked(full_path)))

									if file_project_root == current_project_root and state.is_bookmarked(full_path) then
										print("    -> SHOULD ADD DECORATION!")
										M.test_decoration(bufnr, i - 1, line)
										found_match = true
									end
								end
							end
						end
					end
				end
				break -- Only process first NeoTree buffer for debugging
			end
		end
	end
end

-- Test adding a decoration to a specific line
function M.test_decoration(bufnr, line_num, line_text)
	local config = require("booky.config")
	local ns_id = vim.api.nvim_create_namespace("booky_test")

	print(string.format("Adding test decoration to buffer %d, line %d", bufnr, line_num))
	print(string.format("Icon: %s, Highlight: %s", config.options.neotree.icon, config.options.neotree.highlight))

	-- Clear and add decoration
	vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line_num, line_num + 1)

	local success, err = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line_num, #line_text, {
		virt_text = { { config.options.neotree.icon .. " BOOKMARK", config.options.neotree.highlight } },
		virt_text_pos = "right_align",
	})

	if success then
		print("    -> Test decoration added successfully!")
	else
		print("    -> Failed to add test decoration:", err)
	end
end

return M

