---Preset themes for diffie.nvim
local M = {}

---@class DiffieTheme
---@field DiffieComment table
---@field DiffieCommentBorder table
---@field DiffieCommentMeta table
---@field DiffieCommentMultiple table
---@field DiffieCommentRange table

---@type table<string, DiffieTheme>
M.themes = {
  -- Default: links to standard highlight groups
  default = {
    DiffieComment = { link = "NormalFloat" },
    DiffieCommentBorder = { link = "FloatBorder" },
    DiffieCommentMeta = { link = "NonText" },
    DiffieCommentMultiple = { link = "DiagnosticWarn" },
    DiffieCommentRange = { link = "Folded" },
  },

  -- Gruvbox Dark Hard
  -- Based on https://github.com/morhetz/gruvbox
  gruvbox_dark_hard = {
    DiffieComment = { fg = "#ebdbb2", bg = "#1d2021" },
    DiffieCommentBorder = { fg = "#83a598", bg = "#1d2021" },
    DiffieCommentMeta = { fg = "#928374", bg = "#1d2021" },
    DiffieCommentMultiple = { fg = "#fe8019", bg = "#1d2021" },
    DiffieCommentRange = { bg = "#282828" },
  },

  -- Gruvbox Light Hard
  gruvbox_light_hard = {
    DiffieComment = { fg = "#3c3836", bg = "#f9f5d7" },
    DiffieCommentBorder = { fg = "#076678", bg = "#f9f5d7" },
    DiffieCommentMeta = { fg = "#928374", bg = "#f9f5d7" },
    DiffieCommentMultiple = { fg = "#af3a03", bg = "#f9f5d7" },
    DiffieCommentRange = { bg = "#ebdbb2" },
  },

  -- Catppuccin Mocha (dark)
  -- Based on https://github.com/catppuccin/nvim
  catppuccin_mocha = {
    DiffieComment = { fg = "#cdd6f4", bg = "#1e1e2e" },
    DiffieCommentBorder = { fg = "#89b4fa", bg = "#1e1e2e" },
    DiffieCommentMeta = { fg = "#6c7086", bg = "#1e1e2e" },
    DiffieCommentMultiple = { fg = "#fab387", bg = "#1e1e2e" },
    DiffieCommentRange = { bg = "#313244" },
  },

  -- One Dark
  -- Based on https://github.com/joshdick/onedark.vim
  one_dark = {
    DiffieComment = { fg = "#abb2bf", bg = "#282c34" },
    DiffieCommentBorder = { fg = "#61afef", bg = "#282c34" },
    DiffieCommentMeta = { fg = "#5c6370", bg = "#282c34" },
    DiffieCommentMultiple = { fg = "#e5c07b", bg = "#282c34" },
    DiffieCommentRange = { bg = "#2c313a" },
  },
}

---Apply a theme
---@param theme_name string|table
function M.apply(theme_name)
  local theme

  if type(theme_name) == "table" then
    -- Custom theme table
    theme = theme_name
  elseif M.themes[theme_name] then
    -- Preset theme
    theme = M.themes[theme_name]
  else
    -- Unknown theme, fall back to default
    vim.notify("diffie.nvim: Unknown theme '" .. tostring(theme_name) .. "', using default", vim.log.levels.WARN)
    theme = M.themes.default
  end

  for hl_group, opts in pairs(theme) do
    vim.api.nvim_set_hl(0, hl_group, opts)
  end
end

---List available preset themes
---@return string[]
function M.available()
  local names = {}
  for name, _ in pairs(M.themes) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return M
