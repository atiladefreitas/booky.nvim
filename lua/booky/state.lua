local M = {}

M.bookmarks = {}

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
        else
            vim.notify("Failed to load bookmarks: Invalid JSON", vim.log.levels.WARN)
            M.bookmarks = {}
        end
    else
        M.bookmarks = {}
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
    
    -- Add new bookmark
    local bookmark = {
        path = normalized,
        name = vim.fn.fnamemodify(normalized, ":t"), -- filename only
        added_at = os.time(),
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

return M