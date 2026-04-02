local M = {}

-- Namespace for all extmarks
local ns = vim.api.nvim_create_namespace("diffie_comments")

-- ============================================================================
-- STATE (pure data, easily testable)
-- ============================================================================

---@class Comment
---@field text string[]
---@field author string
---@field timestamp number
---@field resolved boolean
---@field collapsed boolean

---@type table<integer, table<integer, Comment>>
M.state = {} -- bufnr -> { [lnum] = Comment }

-- ============================================================================
-- RENDER STATE (tracks extmark IDs for cleanup)
-- ============================================================================

---@class RenderState
---@field extmarks integer[] -- list of extmark IDs
---@field sign_ids integer[] -- list of sign IDs

---@type table<integer, RenderState>
local render_state = {} -- bufnr -> RenderState

-- ============================================================================
-- RENDERER (handles all UI, separate from state logic)
-- ============================================================================

local Renderer = {}

---Clear all extmarks and signs for a buffer
---@param bufnr integer
function Renderer.clear(bufnr)
  -- Clear extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  
  -- Clear signs
  vim.fn.sign_unplace("diffie", { buffer = bufnr })
  
  -- Reset render state tracking
  render_state[bufnr] = { extmarks = {}, sign_ids = {} }
end

---Create inline extmark for collapsed comment
---@param bufnr integer
---@param lnum integer (1-indexed)
---@param comment Comment
---@return integer extmark_id
function Renderer.render_collapsed(bufnr, lnum, comment)
  local hl_group = comment.resolved and "DiffieCommentResolved" or "DiffieComment"
  
  local preview = comment.text[1]:sub(1, 40)
  if #comment.text[1] > 40 then
    preview = preview .. "..."
  end
  
  local lines_count = #comment.text > 1 and (" (+" .. (#comment.text - 1) .. " lines)") or ""
  
  local virt_text = {
    { " ", "Normal" },
    { "▶ ", "DiffieCommentBorder" },
    { comment.author .. ": ", hl_group },
    { preview, "DiffieCommentMeta" },
    { lines_count, "DiffieCommentMeta" },
    { comment.resolved and " ✓" or "", "DiffieCommentResolved" },
  }
  
  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
  
  table.insert(render_state[bufnr].extmarks, id)
  return id
end

---Create virtual lines for expanded comment
---@param bufnr integer
---@param lnum integer (1-indexed)
---@param comment Comment
---@return integer extmark_id
function Renderer.render_expanded(bufnr, lnum, comment)
  local hl_group = comment.resolved and "DiffieCommentResolved" or "DiffieComment"
  local lines = {}
  
  -- Header
  table.insert(lines, {
    { "┌─ ", "DiffieCommentBorder" },
    { comment.author .. " ", hl_group },
    { os.date("%Y-%m-%d %H:%M", comment.timestamp), "DiffieCommentMeta" },
    { comment.resolved and " ✓" or "", "DiffieCommentResolved" },
  })
  
  -- Body
  for i, line in ipairs(comment.text) do
    local prefix = i == #comment.text and "└─ " or "│  "
    table.insert(lines, {
      { prefix, "DiffieCommentBorder" },
      { line, hl_group },
    })
  end
  
  -- Empty separator
  table.insert(lines, { { "", "Normal" } })
  
  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
    virt_lines = lines,
    virt_lines_above = false,
  })
  
  table.insert(render_state[bufnr].extmarks, id)
  return id
end

---Place sign in sign column
---@param bufnr integer
---@param lnum integer (1-indexed)
---@return integer sign_id
function Renderer.render_sign(bufnr, lnum)
  vim.fn.sign_define("DiffieComment", { text = "💬", texthl = "DiffieComment" })
  
  -- Ensure valid buffer (handle bufnr=0 at startup)
  local target_buf = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  
  local sign_id = vim.fn.sign_place(0, "diffie", "DiffieComment", target_buf, { lnum = lnum })
  
  table.insert(render_state[bufnr].sign_ids, sign_id)
  return sign_id
end

---Render all comments for a buffer based on current state
---@param bufnr integer
function Renderer.render_buffer(bufnr)
  -- Always clear first
  Renderer.clear(bufnr)
  
  local comments = M.state[bufnr]
  if not comments then
    return
  end
  
  for lnum, comment in pairs(comments) do
    -- Render comment content
    if comment.collapsed then
      Renderer.render_collapsed(bufnr, lnum, comment)
    else
      Renderer.render_expanded(bufnr, lnum, comment)
    end
    
    -- Always show sign
    Renderer.render_sign(bufnr, lnum)
  end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Normalize buffer number (0 -> actual bufnr)
---@param bufnr integer|nil
---@return integer
local function normalize_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

---Add a comment
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed)
---@param text string|string[]
---@param opts table|nil {author, timestamp, resolved, collapsed}
function M.add_comment(bufnr, lnum, text, opts)
  opts = opts or {}
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  
  -- Normalize text to string array
  local text_arr = type(text) == "string" and vim.split(text, "\n") or text
  
  -- Initialize state for buffer
  if not M.state[bufnr] then
    M.state[bufnr] = {}
  end
  
  -- Set state
  M.state[bufnr][lnum] = {
    text = text_arr,
    author = opts.author or "You",
    timestamp = opts.timestamp or os.time(),
    resolved = opts.resolved or false,
    collapsed = opts.collapsed or false,
  }
  
  -- Trigger render
  Renderer.render_buffer(bufnr)
end

---Delete a comment
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed)
function M.delete_comment(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  
  if M.state[bufnr] then
    M.state[bufnr][lnum] = nil
    
    -- Clean up empty buffer state
    if vim.tbl_isempty(M.state[bufnr]) then
      M.state[bufnr] = nil
    end
  end
  
  Renderer.render_buffer(bufnr)
end

---Toggle resolved state
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed)
function M.toggle_resolved(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  
  if M.state[bufnr] and M.state[bufnr][lnum] then
    M.state[bufnr][lnum].resolved = not M.state[bufnr][lnum].resolved
    Renderer.render_buffer(bufnr)
  end
end

---Toggle collapsed state
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed)
function M.toggle_collapsed(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
  
  if M.state[bufnr] and M.state[bufnr][lnum] then
    M.state[bufnr][lnum].collapsed = not M.state[bufnr][lnum].collapsed
    Renderer.render_buffer(bufnr)
  end
end

---Get comment at line (for testing/inspection)
---@param bufnr integer|nil
---@param lnum integer
---@return Comment|nil
function M.get_comment(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  return M.state[bufnr] and M.state[bufnr][lnum]
end

---Clear all comments from a buffer
---@param bufnr integer|nil
function M.clear_buffer(bufnr)
  bufnr = normalize_bufnr(bufnr)
  M.state[bufnr] = nil
  Renderer.clear(bufnr)
end

---Setup highlight groups
function M.setup_highlights()
  vim.api.nvim_set_hl(0, "DiffieComment", { fg = "#e6edf3", bg = "#161b22" })
  vim.api.nvim_set_hl(0, "DiffieCommentBorder", { fg = "#58a6ff", bg = "#161b22" })
  vim.api.nvim_set_hl(0, "DiffieCommentMeta", { fg = "#8b949e", bg = "#161b22" })
  vim.api.nvim_set_hl(0, "DiffieCommentResolved", { fg = "#3fb950", bg = "#161b22" })
end

-- Expose renderer for advanced testing
M._renderer = Renderer

return M
