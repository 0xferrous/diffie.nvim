-- Minimal config for testing diffie.nvim
-- Run: nvim -u test_init.lua

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.number = true
vim.opt.signcolumn = "yes"

require("diffie").setup({})

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "1: function processUser(user)",
  "2:   if not user then",
  "3:     return nil",
  "4:   end",
  "5:   local name = user.name",
  "6:   local email = user.email",
  "7:   if email then",
  "8:     sendEmail(email)",
  "9:   end",
  "10:  return { name = name }",
  "11: end",
})

local comments = require("diffie.comments")

comments.add_comment(bufnr, 1, 11, "Refactor this function - too many responsibilities", {
  collapsed = true,
})

comments.add_comment(bufnr, 2, 4, "Should throw error instead of returning nil", {
  collapsed = true,
})

comments.add_comment(bufnr, 6, 9, "Extract email logic to separate function\nThis violates SRP and makes testing difficult\nConsider: extract into sendUserEmail(user)", {
  collapsed = true,
})

comments.add_comment(bufnr, 8, 8, "Add logging here", {
  collapsed = true,
})

print("")
print("═══ diffie.nvim test loaded ═══")
print("")
print("Keybinds:")
print("  <leader>ca - Add comment")
print("  <leader>ce - Edit comment")
print("  <leader>cc - Toggle collapsed")
print("  <leader>cd - Delete comment")
print("  <leader>cx - Export comments to clipboard")
