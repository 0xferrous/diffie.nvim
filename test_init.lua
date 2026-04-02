-- Minimal config for testing diffie.nvim
-- Run: nvim -u test_init.lua

-- Set leader before plugin loads
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Add current directory (plugin root) to runtimepath
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Basic settings for testing
vim.opt.number = true
vim.opt.signcolumn = "yes"

-- Load and setup plugin
require("diffie").setup({})

-- Create a test buffer with some content
local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
	"Line 1: function foo()",
	"Line 2:     return 42",
	"Line 3: end",
	"Line 4:",
	"Line 5: function bar()",
	"Line 6:     local x = nil",
	"Line 7:     return x + 1",
	"Line 8: end",
})

-- Add sample comments
local comments = require("diffie.comments")

-- Expanded comment on line 6
comments.add_comment(bufnr, 6, "Potential nil arithmetic here!\nShould check for nil before adding.", {
	author = "reviewer",
})

-- Collapsed comment on line 3
comments.add_comment(bufnr, 3, "This could be simplified", {
	author = "alice",
	collapsed = true,
})

-- Resolved comment on line 2
comments.add_comment(bufnr, 2, "Good constant name", {
	author = "bob",
	resolved = true,
	collapsed = true,
})

print("diffie.nvim loaded!")
print("Keybinds:")
print("  <leader>ca - Add comment")
print("  <leader>cc - Toggle collapsed")
print("  <leader>cr - Toggle resolved")
print("  <leader>cd - Delete comment")
