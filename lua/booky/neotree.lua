local M = {}

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

    -- Try to register using NeoTree's renderer system
    vim.defer_fn(function()
        M.register_decorator()
    end, 1000) -- Give NeoTree time to load
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
    vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost"}, {
        pattern = "*",
        callback = function()
            vim.defer_fn(function()
                M.decorate_neotree_buffers()
            end, 50)
        end,
    })
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
    
    -- Create namespace for our decorations
    local ns_id = vim.api.nvim_create_namespace("booky_bookmarks")
    
    -- Clear existing decorations
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    
    -- Get current working directory for relative path resolution
    local cwd = vim.fn.getcwd()
    
    -- Get all lines in the buffer
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    
    for i, line in ipairs(lines) do
        -- Extract filename from NeoTree line (improved pattern)
        local filename = line:match("([^%s│├└─▸▾@]+%.%w+)%s*$")
        
        if filename then
            -- Get all bookmarks to try matching by filename
            local bookmarks = state.get_bookmarks()
            local found_match = false
            
            for _, bookmark in ipairs(bookmarks) do
                -- Check if the filename matches the end of any bookmark path
                if bookmark.path:match("/" .. filename:gsub("%-", "%%-") .. "$") or 
                   bookmark.path:match("/" .. filename:gsub("%.", "%%.") .. "$") or
                   bookmark.name == filename then
                    -- Add virtual text decoration at far right
                    vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, #line, {
                        virt_text = { { config.options.neotree.icon, config.options.neotree.highlight } },
                        virt_text_pos = "right_align",
                    })
                    found_match = true
                    break
                end
            end
            
            -- Fallback: try building full paths if direct match failed
            if not found_match then
                local paths_to_try = {
                    cwd .. "/" .. filename,
                    cwd .. "/lua/atila/plugins/" .. filename,
                    vim.fn.expand("~/Dotfiles/nvim/lua/atila/plugins/" .. filename),
                }
                
                for _, full_path in ipairs(paths_to_try) do
                    if vim.fn.filereadable(full_path) == 1 and state.is_bookmarked(full_path) then
                        -- Add virtual text decoration at far right
                        vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, #line, {
                            virt_text = { { config.options.neotree.icon, config.options.neotree.highlight } },
                            virt_text_pos = "right_align",
                        })
                        break
                    end
                end
            end
        end
    end
end

-- Function to refresh NeoTree display
function M.refresh()
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
                            
                            -- Get all bookmarks to try matching
                            local bookmarks = state.get_bookmarks()
                            local found_match = false
                            
                            for _, bookmark in ipairs(bookmarks) do
                                -- Check if the filename matches the end of any bookmark path
                                if bookmark.path:match("/" .. filename:gsub("%-", "%%-") .. "$") or 
                                   bookmark.path:match("/" .. filename:gsub("%.", "%%.") .. "$") or
                                   bookmark.name == filename then
                                    print(string.format("    -> MATCHED bookmark: %s", bookmark.path))
                                    print("    -> SHOULD ADD DECORATION!")
                                    M.test_decoration(bufnr, i - 1, line)
                                    found_match = true
                                    break
                                end
                            end
                            
                            if not found_match then
                                -- Fallback: Try building paths in common directories
                                local paths_to_try = {
                                    cwd .. "/" .. filename,
                                    cwd .. "/lua/atila/plugins/" .. filename,
                                    vim.fn.expand("~/Dotfiles/nvim/lua/atila/plugins/" .. filename),
                                }
                                
                                for _, full_path in ipairs(paths_to_try) do
                                    print(string.format("    -> Trying path: %s", full_path))
                                    print(string.format("    -> File readable: %s", vim.fn.filereadable(full_path) == 1))
                                    print(string.format("    -> Is bookmarked: %s", state.is_bookmarked(full_path)))
                                    
                                    if state.is_bookmarked(full_path) then
                                        print("    -> SHOULD ADD DECORATION!")
                                        M.test_decoration(bufnr, i - 1, line)
                                        found_match = true
                                        break
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