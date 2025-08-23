local M = {}

M.bookmarks = {}

local utils = require("booky.utils")

local function get_save_path()
    return require("booky.config").options.save_path
end

-- Load bookmarks from file
function M.load_bookmarks()
    local save_path = get_save_path()
    local file = io.open(save_path, "r")
    
    if not file then
        M.bookmarks = {}
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    if content and content ~= "" then
        local success, decoded = pcall(vim.fn.json_decode, content)
        if success and decoded then
            M.bookmarks = decoded
            -- Migrate old bookmarks to include project_root
            M.migrate_bookmarks()
        else
            vim.notify("Failed to load bookmarks: Invalid JSON", vim.log.levels.WARN)
            M.bookmarks = {}
        end
    else
        M.bookmarks = {}
    end
end

-- Migrate old bookmarks to include project information
function M.migrate_bookmarks()
    local updated = false
    for _, bookmark in ipairs(M.bookmarks) do
        if not bookmark.project_root then
            bookmark.project_root = utils.get_project_root(bookmark.path)
            bookmark.project_name = utils.get_project_name(bookmark.project_root)
            updated = true
        end
    end
    
    if updated then
        M.save_bookmarks()
    end
end

-- Save bookmarks to file
function M.save_bookmarks()
    local save_path = get_save_path()
    local encoded = vim.fn.json_encode(M.bookmarks)
    
    -- Ensure directory exists
    local dir = vim.fn.fnamemodify(save_path, ":h")
    vim.fn.mkdir(dir, "p")
    
    local file = io.open(save_path, "w")
    if file then
        file:write(encoded)
        file:close()
    else
        vim.notify("Failed to save bookmarks to " .. save_path, vim.log.levels.ERROR)
    end
end

-- Add a bookmark
function M.add_bookmark(filepath)
    if not filepath then
        return false
    end
    
    -- Normalize path
    local normalized = vim.fn.resolve(vim.fn.expand(filepath))
    
    -- Check if already bookmarked
    for _, bookmark in ipairs(M.bookmarks) do
        if bookmark.path == normalized then
            return false -- Already exists
        end
    end
    
    -- Get project information
    local project_root = utils.get_project_root(normalized)
    local project_name = utils.get_project_name(project_root)
    
    -- Add new bookmark
    local bookmark = {
        path = normalized,
        name = vim.fn.fnamemodify(normalized, ":t"), -- filename only
        added_at = os.time(),
        project_root = project_root,
        project_name = project_name,
    }
    
    table.insert(M.bookmarks, bookmark)
    M.save_bookmarks()
    return true
end

-- Remove a bookmark
function M.remove_bookmark(filepath)
    if not filepath then
        return false
    end
    
    local normalized = vim.fn.resolve(vim.fn.expand(filepath))
    
    for i, bookmark in ipairs(M.bookmarks) do
        if bookmark.path == normalized then
            table.remove(M.bookmarks, i)
            M.save_bookmarks()
            return true
        end
    end
    
    return false
end

-- Check if file is bookmarked
function M.is_bookmarked(filepath)
    if not filepath then
        return false
    end
    
    local normalized = vim.fn.resolve(vim.fn.expand(filepath))
    
    for _, bookmark in ipairs(M.bookmarks) do
        if bookmark.path == normalized then
            return true
        end
    end
    
    return false
end

-- Get all bookmarks
function M.get_bookmarks()
    return M.bookmarks
end

-- Toggle bookmark
function M.toggle_bookmark(filepath)
    if M.is_bookmarked(filepath) then
        return M.remove_bookmark(filepath)
    else
        return M.add_bookmark(filepath)
    end
end

-- Get bookmarks for current project
function M.get_project_bookmarks(project_root)
    project_root = project_root or utils.get_current_project_root()
    
    local project_bookmarks = {}
    for _, bookmark in ipairs(M.bookmarks) do
        -- Update project info if missing (for migration)
        if not bookmark.project_root then
            bookmark.project_root = utils.get_project_root(bookmark.path)
            bookmark.project_name = utils.get_project_name(bookmark.project_root)
        end
        
        if bookmark.project_root == project_root then
            table.insert(project_bookmarks, bookmark)
        end
    end
    
    return project_bookmarks
end

-- Get bookmarks grouped by project
function M.get_bookmarks_by_project()
    local grouped = {}
    
    for _, bookmark in ipairs(M.bookmarks) do
        -- Update project info if missing (for migration)
        if not bookmark.project_root then
            bookmark.project_root = utils.get_project_root(bookmark.path)
            bookmark.project_name = utils.get_project_name(bookmark.project_root)
        end
        
        local project_root = bookmark.project_root
        if not grouped[project_root] then
            grouped[project_root] = {
                name = bookmark.project_name,
                root = project_root,
                bookmarks = {}
            }
        end
        
        table.insert(grouped[project_root].bookmarks, bookmark)
    end
    
    -- Convert to array and sort by project name
    local projects = {}
    for _, project_data in pairs(grouped) do
        table.insert(projects, project_data)
    end
    
    table.sort(projects, function(a, b)
        return a.name < b.name
    end)
    
    return projects
end

return M