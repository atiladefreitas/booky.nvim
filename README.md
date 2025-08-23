# Booky

Booky is a powerful project-aware bookmark manager for Neovim. It intelligently organizes your bookmarks by project, allowing you to focus on current project files or browse all bookmarks across projects with a beautiful interface.

## 🚀 Features

- 📂 **Project-Aware Bookmarking**: Automatically detects and organizes bookmarks by project
- 🎯 **Project-Specific View**: Show only bookmarks from your current project
- 🌍 **Global Bookmarks View**: Beautiful floating window showing all bookmarks grouped by project
- 🔍 **Telescope Integration**: Browse project bookmarks using Telescope picker
- 🌲 **NeoTree Integration**: Orange bookmark icons appear next to bookmarked files in NeoTree
- 💾 **Persistent Storage**: Bookmarks are saved and persist across Neovim sessions
- 🔄 **Automatic Migration**: Existing bookmarks are automatically updated with project information
- ⚙️ **Configurable**: Customizable keybindings and appearance
- 📖 **Interactive Help**: Built-in help system with keybinding reference

## 📦 Installation

### Prerequisites

- Neovim `>= 0.5.0`
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (required)
- [NeoTree](https://github.com/nvim-neo-tree/neo-tree.nvim) (optional, for visual indicators)

### Using Lazy.nvim

```lua
{
    "atiladefreitas/booky",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-neo-tree/neo-tree.nvim", -- optional
    },
    config = function()
        require("booky").setup({
            -- your custom config here (optional)
        })
    end,
}
```

## ⚙️ Configuration

Default configuration:

```lua
{
    -- File to store bookmarks
    save_path = vim.fn.stdpath("data") .. "/booky_bookmarks.json",
    
    -- Keymaps
    keymaps = {
        add_bookmark = "<leader>ba",      -- Add/toggle bookmark for current file
        toggle_telescope = "<leader>bb",  -- Open project bookmarks in telescope
        global_bookmarks = "<leader>bg",  -- Open global bookmarks in floating window
    },
    
    -- NeoTree integration
    neotree = {
        enabled = true,
        icon = "󰃃",  -- Orange bookmark nerd font icon
        highlight = "BookyBookmarkIcon",
    },
    
    -- Telescope integration  
    telescope = {
        enabled = true,
        theme = nil,  -- nil (default), "dropdown", "ivy", "cursor"
        prompt_title = " Bookmarks",
        results_title = "Files",
    },
}
```

## 🔑 Default Keybindings

| Key | Action |
|-----|--------|
| `<leader>ba` | Toggle bookmark for current file |
| `<leader>bb` | Open project bookmarks in Telescope |
| `<leader>bg` | Open global bookmarks in floating window |

### Project Bookmarks (Telescope) - `<leader>bb`

| Key | Action |
|-----|--------|
| `<CR>` | Open selected file |
| `<C-d>` | Remove bookmark (both insert and normal mode) |

### Global Bookmarks (Floating Window) - `<leader>bg`

| Key | Action |
|-----|--------|
| `<CR>`, `o` | Open selected bookmark |
| `d`, `x` | Delete bookmark |
| `r` | Refresh bookmark list |
| `?` | Show help with all keybindings |
| `q`, `<Esc>` | Close window |
| `j/k`, `↓/↑` | Navigate up/down |
| `gg/G` | Go to top/bottom |
| `<C-d>/<C-u>` | Page down/up |

## 📝 Commands

- `:BookyAdd` - Add current file to bookmarks
- `:BookyRemove` - Remove current file from bookmarks
- `:BookyToggle` - Toggle bookmark for current file
- `:BookyList` - Open project bookmarks in Telescope
- `:BookyGlobal` - Open global bookmarks in floating window

## 🔧 Usage

### Basic Operations
1. **Add Bookmarks**: Press `<leader>ba` while in any file to bookmark it
2. **Remove Bookmarks**: Press `<leader>ba` again on a bookmarked file to remove it

### Viewing Bookmarks

#### Project Bookmarks (`<leader>bb`)
- Shows only bookmarks from your current project
- Uses Telescope interface for fuzzy searching
- Displays relative paths from project root
- Perfect for focused project work

#### Global Bookmarks (`<leader>bg`)  
- Beautiful floating window showing all bookmarks
- Organized by project with clear visual separation
- Current project highlighted with `▶` marker
- Interactive navigation and management
- Press `?` for help with all available keybindings

### Visual Indicators
- **NeoTree**: Bookmarked files show an orange bookmark icon (󰃃)
- **Global View**: Current project marked with `▶`, others with `▷`

## 🎨 Customization

### Custom Keybindings

```lua
require("booky").setup({
    keymaps = {
        add_bookmark = "<leader>bm",     -- Custom bookmark toggle key
        toggle_telescope = "<leader>bl", -- Custom project bookmarks key  
        global_bookmarks = "<leader>bG", -- Custom global bookmarks key
    },
})
```

### Custom NeoTree Icon

```lua
require("booky").setup({
    neotree = {
        icon = "★",  -- Use star instead of bookmark
        highlight = "MyCustomHighlight",
    },
})
```

### Telescope Theme

```lua
require("booky").setup({
    telescope = {
        theme = "ivy",  -- Use ivy theme: "dropdown", "ivy", "cursor", or nil
        prompt_title = "My Project Bookmarks",
        results_title = "Project Files",
    },
})
```

### Custom Storage Location

```lua
require("booky").setup({
    save_path = vim.fn.expand("~/.config/nvim/my_bookmarks.json"),
})
```

## 🔄 Migration from Previous Versions

Booky automatically migrates existing bookmarks to include project information when you first load the plugin after updating. No manual action required!

## 🎯 Project-Specific Features

### Automatic Project Detection
Booky intelligently detects your project boundaries and organizes bookmarks accordingly. Each bookmark is automatically tagged with its project root and name.

### Smart Display
- **Project View** (`<leader>bb`): Shows only bookmarks from your current project with relative paths
- **Global View** (`<leader>bg`): Groups all bookmarks by project with full context

### Visual Project Indicators
- Current project: `▶` (green highlight)
- Other projects: `▷` (blue highlight)
- Bookmark icon: `󰃃` (orange highlight)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

*This README was generated with AI assistance.*
