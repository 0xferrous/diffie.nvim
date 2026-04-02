-- Bootstrap for plenary tests
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Bootstrap plenary if not installed
local plenary_path = vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
  print("Installing plenary.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary_path,
  })
end

vim.opt.rtp:prepend(plenary_path)

-- Ensure comments module can be loaded
require("diffie").setup({})

-- Helper to create a buffer with content for tests
_G.create_test_buffer = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  -- Add some lines so extmarks can be placed
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Line 1",
    "Line 2",
    "Line 3",
    "Line 4",
    "Line 5",
    "Line 6",
    "Line 7",
    "Line 8",
    "Line 9",
    "Line 10",
  })
  return buf
end
