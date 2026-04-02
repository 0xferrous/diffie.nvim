# diffie.nvim

Add review comments directly in your code. Inspired by GitHub PR review comments, but works locally in Neovim.

![demo](https://user-images.githubusercontent.com/placeholder/demo.png)

## Features

- **Inline comments** - Add comments on any line or range of lines
- **Overlapping ranges** - Multiple comments can overlap (e.g., function-level + specific line comments)
- **Collapse/Expand** - Hide comments to reduce visual clutter
- **Visual selection** - Comment on selected ranges in visual mode
- **Edit & Delete** - Modify or remove comments with pickers for overlapping ranges
- **Configurable** - Customizable keymaps and sign column

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "0xferrous/diffie.nvim",
    opts = {},
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "0xferrous/diffie.nvim",
    config = function()
        require("diffie").setup({})
    end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug '0xferrous/diffie.nvim'
```

Then in your Lua config:
```lua
require("diffie").setup({})
```

## Usage

### Keymaps (default)

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ca` | Normal | Add comment on current line |
| `<leader>ca` | Visual | Add comment on selected range |
| `<leader>ce` | Normal | Edit comment (shows picker if overlapping) |
| `<leader>cd` | Normal | Delete comment (shows picker if overlapping) |
| `<leader>cc` | Normal | Toggle collapsed/expanded |

### Example Workflow

```lua
-- Add a comment on line 5
<leader>ca
> Check for nil here

-- Add a comment on lines 10-15 in visual mode
V (select lines 10-15)
<leader>ca
> Refactor this block

-- Toggle collapse to hide comments
<leader>cc

-- Edit a comment
<leader>ce

-- Delete a comment
<leader>cd
```

## Configuration

```lua
require("diffie").setup({
    enabled = true,
    sign_column = true, -- Show 💬 in sign column

    -- Keymap configuration
    keymaps = {
        add = "<leader>ca",
        edit = "<leader>ce",
        delete = "<leader>cd",
        toggle_collapsed = "<leader>cc",
    },
})
```

### Disable specific keymaps

```lua
require("diffie").setup({
    keymaps = {
        delete = false, -- disable delete keymap
        edit = "<leader>cE", -- change to different key
    },
})
```

### Disable all keymaps (set manually)

```lua
require("diffie").setup({
    keymaps = false,
})
```

## Overlapping Comments

diffie.nvim supports multiple comments on overlapping ranges. When you have overlapping comments:

- **Sign column** shows the count (e.g., `2`, `3`) instead of `💬`
- **`<leader>cc`** (toggle collapse) affects the smallest/narrowest comment at cursor
- **`<leader>ce`** and **`<leader>cd`** show pickers to select which comment to edit/delete

Example:
```
Line 1: 💬 function processUser(user) {    -- Comment A (lines 1-11)
Line 2: 2   if (x) {                      -- Comment B (lines 2-4) overlaps A
Line 3:     bar()                         -- Line 3 is in both A and B
Line 4: 2   }                             -- Comment C (lines 3-5) also overlaps
```

## Testing

Run tests with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim):

```bash
just test
```

Or manually:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" -c "qa!"
```

## License

MIT
