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

-- Open bookmark picker
function M.open_bookmark_picker()
    local state = require("booky.state")
    local config = require("booky.config")
    local bookmarks = state.get_bookmarks()
    
    if #bookmarks == 0 then
        vim.notify("No bookmarks found", vim.log.levels.INFO)
        return
    end
    
    -- Prepare entries for telescope
    local entries = {}
    for _, bookmark in ipairs(bookmarks) do
        table.insert(entries, {
            path = bookmark.path,
            name = bookmark.name,
            display = bookmark.name .. " (" .. vim.fn.fnamemodify(bookmark.path, ":~:.") .. ")",
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
    
    opts.prompt_title = config.options.telescope.prompt_title
    opts.results_title = config.options.telescope.results_title
    
    pickers.new(opts, {
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
    }):find()
end

return M