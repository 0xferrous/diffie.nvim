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
    opts = {
        -- Custom export format - exports comments from ALL open buffers
        export_format = function(ctx)
            -- ctx contains:
            --   comments: array of comment objects with file info
            --       { id, text[], author, timestamp, collapsed, start_lnum, end_lnum,
            --         filename, filepath, relative_path, bufnr }
            --   root_dir: project root directory (e.g., "/home/user/project")
            --   total_comments: total number of comments across all files
            --   total_files: number of files with comments
            local lines = {}
            table.insert(lines, "Reviewed " .. ctx.total_files .. " file(s) with " .. ctx.total_comments .. " comments:")
            
            local current_file = nil
            for _, c in ipairs(ctx.comments) do
                if c.relative_path ~= current_file then
                    current_file = c.relative_path
                    table.insert(lines, "")
                    table.insert(lines, "File: " .. current_file)
                end
                table.insert(lines, "  - Line " .. c.start_lnum .. ": " .. c.text[1])
            end
            return table.concat(lines, "\n")
        end,
    },
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
| `<leader>cx` | Normal | Export comments to clipboard |

### Commands

| Command | Description |
|---------|-------------|
| `:DiffieAdd [text]` | Add comment on current line (prompts if no text) |
| `:DiffieEdit` | Edit comment at cursor (shows picker if overlapping) |
| `:DiffieDelete` | Delete comment at cursor (shows picker if overlapping) |
| `:DiffieToggle` | Toggle collapsed/expanded for comment at cursor |
| `:DiffieExport` | Export all comments to clipboard |
| `:DiffieClear` | Clear all comments from current buffer |

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
        export = "<leader>cx",
    },
    
    -- Custom export format (optional)
    -- Function receives a context table with:
    --   - comments: array of comment objects with file info:
    --       { id, text[], author, timestamp, collapsed, start_lnum, end_lnum,
    --         filename, filepath, relative_path, bufnr }
    --   - root_dir: project root directory or nil
    --   - total_comments: total number of comments across all files
    --   - total_files: number of files with comments
    export_format = function(ctx)
        local lines = {}
        table.insert(lines, "Reviewed " .. ctx.total_files .. " file(s) with " .. ctx.total_comments .. " comments:")
        
        local current_file = nil
        for _, c in ipairs(ctx.comments) do
            if c.relative_path ~= current_file then
                current_file = c.relative_path
                table.insert(lines, "")
                table.insert(lines, "File: " .. current_file)
            end
            local range = c.start_lnum == c.end_lnum 
                and ("Line " .. c.start_lnum)
                or ("Lines " .. c.start_lnum .. "-" .. c.end_lnum)
            table.insert(lines, "  - " .. range .. ": " .. table.concat(c.text, " "))
        end
        return table.concat(lines, "\n")
    end,
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

## Styling

By default, diffie.nvim links to standard Neovim highlight groups so it automatically matches your colorscheme. You can override these if needed:

```lua
-- Default links (no config needed - they just work with your theme)
-- DiffieComment -> NormalFloat
-- DiffieCommentBorder -> FloatBorder
-- DiffieCommentMeta -> NonText
-- DiffieCommentMultiple -> DiagnosticWarn
-- DiffieCommentRange -> Folded

-- Override with custom colors
vim.api.nvim_set_hl(0, "DiffieComment", { fg = "#e6edf3", bg = "#1e2530" })
vim.api.nvim_set_hl(0, "DiffieCommentBorder", { fg = "#58a6ff" })
vim.api.nvim_set_hl(0, "DiffieCommentMeta", { fg = "#8b949e" })
vim.api.nvim_set_hl(0, "DiffieCommentMultiple", { fg = "#f0883e" }) -- Overlaps indicator
vim.api.nvim_set_hl(0, "DiffieCommentRange", { bg = "#161b22" })    -- Range highlight
```

**Available highlight groups:**

| Group | Default Link | Used For |
|-------|--------------|----------|
| `DiffieComment` | `NormalFloat` | Comment text content |
| `DiffieCommentBorder` | `FloatBorder` | Box drawing characters (┌, └, │) and headers |
| `DiffieCommentMeta` | `NonText` | Metadata like "(+2 lines)" and line numbers |
| `DiffieCommentMultiple` | `DiagnosticWarn` | Sign column when multiple comments overlap |
| `DiffieCommentRange` | `Folded` | Background highlight for commented line ranges |

## Export to Clipboard

Export **all comments from all open buffers** to clipboard with `<leader>cx`. The default format groups comments by file:

```
I reviewed your code and have the following comments. Please address them.

File: src/utils/helpers.js
  - Line 5: Check for nil here
  - Lines 10-15: Refactor this block into smaller functions
  - Line 20: Add error handling

File: src/main.js
  - Line 3: Import order is wrong
  - Line 45: Extract this to a constant
```

Project root is detected via `.git`, `.jj`, `.hg`, `.svn`, `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, or `Makefile`.

Customize the format with the `export_format` configuration option (see Configuration above).

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
