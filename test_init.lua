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

-- Comment 1: On the whole function (lines 1-11)
comments.add_comment(bufnr, 1, 11, "Refactor this function - too many responsibilities", {
  resolved = false,
  collapsed = true,
})

-- Comment 2: On nil check block (lines 2-4) - overlaps with 1
comments.add_comment(bufnr, 2, 4, "Should throw error instead of returning nil", {
  resolved = false,
  collapsed = true,
})

-- Comment 3: On email handling (lines 6-9) - overlaps with 1
comments.add_comment(bufnr, 6, 9, "Extract email logic to separate function", {
  collapsed = true,
})

-- Comment 4: Specific line 8 - overlaps with 3 and 1
comments.add_comment(bufnr, 8, 8, "Add logging here", {
  collapsed = true,
})

print("diffie.nvim loaded!")
print("")
print("Demo: Overlapping comments")
print("Line 1: 💬  (1 comment - whole function)")
print("Line 2: 2   (2 comments - overlaps with function)")
print("Line 6: 2   (2 comments - email section)")
print("Line 8: 3   (3 comments - most overlaps!)")
print("")
print("Keybinds:")
print("  <leader>ca - Add comment")
print("  <leader>ce - Edit comment (picker when overlapping)")
print("  <leader>cc - Toggle collapsed (smallest range wins)")
print("  <leader>cr - Toggle resolved")
print("  <leader>cd - Delete comment (picker when overlapping)")
print("")
print("Try <leader>cc on different lines to see smallest-range-wins behavior")
