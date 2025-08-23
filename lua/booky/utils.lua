local M = {}

-- Get project root for a given path
function M.get_project_root(path)
    path = path or vim.fn.getcwd()
    
    -- Root markers in order of priority
    local markers = {
        ".git",
        ".svn",
        ".hg",
        "package.json",
        "Cargo.toml",
        "go.mod",
        "requirements.txt",
        "setup.py",
        "pyproject.toml",
        "Gemfile",
        "Makefile",
        "CMakeLists.txt",
        ".project",
        ".vscode",
        ".idea"
    }
    
    -- Start from the file's directory or current directory
    local dir = vim.fn.isdirectory(path) == 1 and path or vim.fn.fnamemodify(path, ":h")
    
    -- Search upwards for project markers
    while dir ~= "/" and dir ~= "" do
        for _, marker in ipairs(markers) do
            local marker_path = dir .. "/" .. marker
            if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
                return vim.fn.resolve(dir)
            end
        end
        local parent = vim.fn.fnamemodify(dir, ":h")
        if parent == dir then
            break
        end
        dir = parent
    end
    
    -- If no project root found, use the directory of the file
    if vim.fn.isdirectory(path) == 1 then
        return vim.fn.resolve(path)
    else
        return vim.fn.resolve(vim.fn.fnamemodify(path, ":h"))
    end
end

-- Get project name from project root
function M.get_project_name(project_root)
    if not project_root then
        return "Unknown"
    end
    
    -- Get the last part of the path as project name
    local name = vim.fn.fnamemodify(project_root, ":t")
    if name == "" then
        name = "Root"
    end
    
    return name
end

-- Get current project root
function M.get_current_project_root()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file == "" then
        return M.get_project_root(vim.fn.getcwd())
    else
        return M.get_project_root(current_file)
    end
end

-- Get relative path from project root
function M.get_relative_path(filepath, project_root)
    if not filepath or not project_root then
        return filepath
    end
    
    local resolved_file = vim.fn.resolve(filepath)
    local resolved_root = vim.fn.resolve(project_root)
    
    -- Check if file is under project root
    if vim.startswith(resolved_file, resolved_root) then
        local relative = string.sub(resolved_file, #resolved_root + 2)
        return relative ~= "" and relative or vim.fn.fnamemodify(filepath, ":t")
    else
        -- File is outside project, return shortened path
        return vim.fn.fnamemodify(filepath, ":~:.")
    end
end

return M