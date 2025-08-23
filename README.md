# Booky

Booky is a simple yet powerful bookmark manager for Neovim. It allows you to quickly bookmark files and navigate between them using Telescope integration, with visual indicators in NeoTree.

## 🚀 Features

- 📖 **Quick Bookmarking**: Add/remove bookmarks with simple keybindings
- 🔍 **Telescope Integration**: Browse and open bookmarks using Telescope picker
- 🌲 **NeoTree Integration**: Orange bookmark icons appear next to bookmarked files in NeoTree
- 💾 **Persistent Storage**: Bookmarks are saved and persist across Neovim sessions
- ⚙️ **Configurable**: Customizable keybindings and appearance

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
        add_bookmark = "<leader>ba",     -- Add/toggle bookmark for current file
        toggle_telescope = "<leader>fb", -- Open telescope bookmark picker
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
        theme = "dropdown",  -- dropdown, ivy, cursor
        prompt_title = "📖 Bookmarks",
        results_title = "Files",
    },
}
```

## 🔑 Default Keybindings

| Key | Action |
|-----|--------|
| `<leader>ba` | Toggle bookmark for current file |
| `<leader>fb` | Open telescope bookmark picker |

### Telescope Picker Keybindings

| Key | Action |
|-----|--------|
| `<CR>` | Open selected file |
| `<C-d>` | Remove bookmark (both insert and normal mode) |

## 📝 Commands

- `:BookyAdd` - Add current file to bookmarks
- `:BookyRemove` - Remove current file from bookmarks
- `:BookyToggle` - Toggle bookmark for current file
- `:BookyList` - Open bookmark list in Telescope

## 🔧 Usage

1. **Add Bookmarks**: Press `<leader>ba` while in any file to bookmark it
2. **View Bookmarks**: Press `<leader>fb` to open the Telescope picker with all bookmarks
3. **Remove Bookmarks**: Either press `<leader>ba` again on a bookmarked file, or use `<C-d>` in the Telescope picker
4. **Visual Indicators**: Bookmarked files will show an orange bookmark icon (󰃃) in NeoTree

## 🎨 Customization

### Custom Keybindings

```lua
require("booky").setup({
    keymaps = {
        add_bookmark = "<leader>bm",     -- Custom bookmark toggle key
        toggle_telescope = "<leader>bl", -- Custom telescope key
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
        theme = "ivy",  -- Use ivy theme instead of dropdown
        prompt_title = "My Bookmarks",
    },
})
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
