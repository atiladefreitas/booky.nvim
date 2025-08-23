local M = {}

local config = require("booky.config")
local state = require("booky.state")

-- Setup function
function M.setup(opts)
    -- Setup configuration
    config.setup(opts)
    
    -- Load existing bookmarks
    state.load_bookmarks()
    
    -- Setup NeoTree integration
    local ok, neotree = pcall(require, "booky.neotree")
    if ok then
        neotree.setup()
    end
    
    -- Create user commands
    vim.api.nvim_create_user_command("BookyAdd", function()
        M.add_current_file()
    end, { desc = "Add current file to bookmarks" })
    
    vim.api.nvim_create_user_command("BookyRemove", function()
        M.remove_current_file()
    end, { desc = "Remove current file from bookmarks" })
    
    vim.api.nvim_create_user_command("BookyToggle", function()
        M.toggle_current_file()
    end, { desc = "Toggle current file bookmark" })
    
    vim.api.nvim_create_user_command("BookyList", function()
        M.open_telescope()
    end, { desc = "Open bookmark list in Telescope" })
    
    vim.api.nvim_create_user_command("BookyRefresh", function()
        M.refresh_neotree()
    end, { desc = "Refresh NeoTree bookmark decorations" })
    
    vim.api.nvim_create_user_command("BookyDebug", function()
        M.debug_neotree()
    end, { desc = "Debug NeoTree integration" })
    
    vim.api.nvim_create_user_command("BookyTest", function()
        M.test_virtual_text()
    end, { desc = "Test virtual text decoration" })
    
    -- Set up default keymaps
    local keymap_opts = { noremap = true, silent = true }
    
    vim.keymap.set("n", config.options.keymaps.add_bookmark, function()
        M.toggle_current_file()
    end, vim.tbl_extend("force", keymap_opts, { desc = "Toggle bookmark for current file" }))
    
    vim.keymap.set("n", config.options.keymaps.toggle_telescope, function()
        M.open_telescope()
    end, vim.tbl_extend("force", keymap_opts, { desc = "Open bookmark telescope picker" }))
end

-- Add current file to bookmarks
function M.add_current_file()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("No file in current buffer", vim.log.levels.WARN)
        return
    end
    
    if state.add_bookmark(filepath) then
        vim.notify("Added bookmark: " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
        -- Refresh NeoTree
        require("booky.neotree").refresh()
    else
        vim.notify("File is already bookmarked", vim.log.levels.INFO)
    end
end

-- Remove current file from bookmarks
function M.remove_current_file()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("No file in current buffer", vim.log.levels.WARN)
        return
    end
    
    if state.remove_bookmark(filepath) then
        vim.notify("Removed bookmark: " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
        -- Refresh NeoTree
        require("booky.neotree").refresh()
    else
        vim.notify("File is not bookmarked", vim.log.levels.INFO)
    end
end

-- Toggle bookmark for current file
function M.toggle_current_file()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == "" then
        vim.notify("No file in current buffer", vim.log.levels.WARN)
        return
    end
    
    if state.is_bookmarked(filepath) then
        M.remove_current_file()
    else
        M.add_current_file()
    end
end

-- Open telescope bookmark picker
function M.open_telescope()
    local telescope = require("booky.telescope")
    telescope.open_bookmark_picker()
end

-- Get all bookmarks (for external use)
function M.get_bookmarks()
    return state.get_bookmarks()
end

-- Check if file is bookmarked (for external use)
function M.is_bookmarked(filepath)
    return state.is_bookmarked(filepath)
end

-- Refresh NeoTree decorations
function M.refresh_neotree()
    local neotree = require("booky.neotree")
    neotree.refresh()
    vim.notify("Refreshed NeoTree bookmark decorations", vim.log.levels.INFO)
end

-- Debug NeoTree integration
function M.debug_neotree()
    local bookmarks = state.get_bookmarks()
    print("=== BOOKY DEBUG ===")
    print("Bookmarks found:", #bookmarks)
    for i, bookmark in ipairs(bookmarks) do
        print(string.format("  %d: %s -> %s", i, bookmark.name, bookmark.path))
    end
    
    print("\nNeoTree buffers:")
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            local buf_name = vim.api.nvim_buf_get_name(bufnr)
            if buf_name:match("neo%-tree") then
                print(string.format("  Buffer %d: %s", bufnr, buf_name))
                local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false)
                for j, line in ipairs(lines) do
                    if j <= 5 then -- Just show first 5 lines
                        print(string.format("    Line %d: %s", j, line))
                    end
                end
            end
        end
    end
    
    local neotree = require("booky.neotree")
    neotree.debug_decorations()
end

-- Test virtual text decoration on current buffer
function M.test_virtual_text()
    local bufnr = vim.api.nvim_get_current_buf()
    local config = require("booky.config")
    local ns_id = vim.api.nvim_create_namespace("booky_test")
    
    print("Testing virtual text on current buffer:", bufnr)
    print("Buffer name:", vim.api.nvim_buf_get_name(bufnr))
    
    -- Add test decoration to line 1
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
        virt_text = { { " " .. config.options.neotree.icon .. " TEST", config.options.neotree.highlight } },
        virt_text_pos = "eol",
    })
    
    print("Added test decoration to line 1!")
    vim.notify("Test virtual text added to line 1", vim.log.levels.INFO)
end

return M