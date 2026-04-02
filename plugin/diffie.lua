-- Plugin entry point
-- This file is automatically loaded by Neovim when the plugin is in 'runtimepath'

-- Guard against loading multiple times
if vim.g.loaded_diffie then
	return
end
vim.g.loaded_diffie = 1

-- Auto-load the main module when needed
-- Users should call require("diffie").setup({}) in their config
