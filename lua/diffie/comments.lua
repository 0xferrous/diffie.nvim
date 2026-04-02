local M = {}

-- Namespace for all extmarks
local ns = vim.api.nvim_create_namespace("diffie_comments")

-- ============================================================================
-- STATE (pure data, easily testable)
-- ============================================================================

---@class Comment
---@field id integer
---@field text string[]
---@field author string
---@field timestamp number
---@field resolved boolean
---@field collapsed boolean
---@field start_lnum integer (1-indexed, inclusive)
---@field end_lnum integer (1-indexed, inclusive)

---@type table<integer, Comment[]>
M.state = {} -- bufnr -> array of Comments

-- Counter for unique comment IDs
local next_id = 1

-- ============================================================================
-- RENDER STATE (tracks extmark IDs for cleanup)
-- ============================================================================

---@class RenderState
---@field extmarks table<integer, integer> -- comment_id -> extmark_id mapping
---@field sign_ids integer[] -- list of sign IDs

---@type table<integer, RenderState>
local render_state = {} -- bufnr -> RenderState

-- ============================================================================
-- SPATIAL INDEX for fast overlap queries
-- ============================================================================

---Build spatial index for a buffer
---@param bufnr integer
---@return table -- interval tree-like structure
local function build_spatial_index(bufnr)
  local index = {}
  local comments = M.state[bufnr] or {}

  for _, comment in ipairs(comments) do
    table.insert(index, {
      start_lnum = comment.start_lnum,
      end_lnum = comment.end_lnum,
      comment = comment,
    })
  end

  -- Sort by start_lnum for efficient range queries
  table.sort(index, function(a, b)
    return a.start_lnum < b.start_lnum
  end)

  return index
end

---Find all comments covering a line
---@param bufnr integer
---@param lnum integer
---@return Comment[]
local function find_comments_at_line(bufnr, lnum)
  local comments = M.state[bufnr] or {}
  local result = {}

  for _, comment in ipairs(comments) do
    if lnum >= comment.start_lnum and lnum <= comment.end_lnum then
      table.insert(result, comment)
    end
  end

  return result
end

---Find the smallest (narrowest range) comment at a line
---@param bufnr integer
---@param lnum integer
---@return Comment|nil
local function find_smallest_comment_at_line(bufnr, lnum)
  local covering = find_comments_at_line(bufnr, lnum)

  if #covering == 0 then
    return nil
  end

  -- Find smallest range
  local smallest = covering[1]
  for _, comment in ipairs(covering) do
    local range = comment.end_lnum - comment.start_lnum
    local smallest_range = smallest.end_lnum - smallest.start_lnum
    if range < smallest_range then
      smallest = comment
    end
  end

  return smallest
end

---Count comments at a line (for sign column)
---@param bufnr integer
---@param lnum integer
---@return integer
local function count_comments_at_line(bufnr, lnum)
  return #find_comments_at_line(bufnr, lnum)
end

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

---Highlight the range of lines for a comment
---@param bufnr integer
---@param comment Comment
function Renderer.render_range_highlight(bufnr, comment)
  for lnum = comment.start_lnum, comment.end_lnum do
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum - 1, 0, {
      line_hl_group = "DiffieCommentRange",
      priority = 10,
    })
  end
end

---Create inline extmark for collapsed comment
---@param bufnr integer
---@param comment Comment
---@return integer extmark_id
function Renderer.render_collapsed(bufnr, comment)
  local hl_group = comment.resolved and "DiffieCommentResolved" or "DiffieComment"

  local preview = comment.text[1]:sub(1, 40)
  if #comment.text[1] > 40 then
    preview = preview .. "..."
  end

  local lines_count = #comment.text > 1 and (" (+" .. (#comment.text - 1) .. " lines)") or ""
  local range_str = comment.start_lnum == comment.end_lnum and "" or (" [L" .. comment.start_lnum .. "-" .. comment.end_lnum .. "]")

  local virt_text = {
    { " ", "Normal" },
    { "▶ ", "DiffieCommentBorder" },
    { preview, "DiffieCommentMeta" },
    { lines_count, "DiffieCommentMeta" },
    { range_str, "DiffieCommentBorder" },
    { comment.resolved and " ✓" or "", "DiffieCommentResolved" },
  }

  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, comment.end_lnum - 1, 0, {
    virt_text = virt_text,
    virt_text_pos = "eol",
    hl_mode = "combine",
  })

  render_state[bufnr].extmarks[comment.id] = id
  return id
end

---Create virtual lines for expanded comment
---@param bufnr integer
---@param comment Comment
---@param stack_position integer position in stack (for visual separation)
---@return integer extmark_id
function Renderer.render_expanded(bufnr, comment, stack_position)
  local hl_group = comment.resolved and "DiffieCommentResolved" or "DiffieComment"
  local lines = {}

  -- Add separator between stacked comments
  if stack_position > 1 then
    table.insert(lines, { { "", "Normal" } })
  end

  -- Header with range info
  local range_str = comment.start_lnum == comment.end_lnum and "" or (" [lines " .. comment.start_lnum .. "-" .. comment.end_lnum .. "]")
  table.insert(lines, {
    { "┌─ ", "DiffieCommentBorder" },
    { range_str, "DiffieCommentBorder" },
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

  -- Empty separator after each comment
  table.insert(lines, { { "", "Normal" } })

  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, comment.end_lnum - 1, 0, {
    virt_lines = lines,
    virt_lines_above = false,
  })

  render_state[bufnr].extmarks[comment.id] = id
  return id
end

---Place sign in sign column with count
---@param bufnr integer
---@param lnum integer (1-indexed)
---@param count integer number of comments on this line
---@return integer sign_id
function Renderer.render_sign(bufnr, lnum, count)
  local text
  if count == 1 then
    text = "💬"
  elseif count < 10 then
    text = tostring(count)
  else
    text = "+"
  end

  vim.fn.sign_define("DiffieComment" .. lnum, {
    text = text,
    texthl = count > 1 and "DiffieCommentMultiple" or "DiffieComment",
  })

  local target_buf = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  local sign_id = vim.fn.sign_place(0, "diffie", "DiffieComment" .. lnum, target_buf, { lnum = lnum })

  table.insert(render_state[bufnr].sign_ids, sign_id)
  return sign_id
end

---Render all comments for a buffer
---@param bufnr integer
function Renderer.render_buffer(bufnr)
  Renderer.clear(bufnr)

  local comments = M.state[bufnr]
  if not comments or #comments == 0 then
    return
  end

  -- Build a map of end_lnum -> list of comments ending there
  -- to handle stacking
  local by_end = {}
  for _, comment in ipairs(comments) do
    if not by_end[comment.end_lnum] then
      by_end[comment.end_lnum] = {}
    end
    table.insert(by_end[comment.end_lnum], comment)
  end

  -- Track which lines have signs already
  local signed_lines = {}

  -- Render in creation order (already sorted by id/timestamp implicitly)
  for end_lnum, ending_comments in pairs(by_end) do
    -- Sort by creation time (id) for stacking order
    table.sort(ending_comments, function(a, b)
      return a.id < b.id
    end)

    -- Render each comment at this end position
    for i, comment in ipairs(ending_comments) do
      -- Range highlight
      Renderer.render_range_highlight(bufnr, comment)

      -- Comment content
      if comment.collapsed then
        Renderer.render_collapsed(bufnr, comment)
      else
        Renderer.render_expanded(bufnr, comment, i)
      end

      -- Sign at start line (once per line, with count)
      if not signed_lines[comment.start_lnum] then
        local count = count_comments_at_line(bufnr, comment.start_lnum)
        Renderer.render_sign(bufnr, comment.start_lnum, count)
        signed_lines[comment.start_lnum] = true
      end
    end
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

---Find comment by ID
---@param bufnr integer
---@param id integer
---@return Comment|nil, integer|nil -- comment and its index in array
local function find_comment_by_id(bufnr, id)
  local comments = M.state[bufnr]
  if not comments then
    return nil
  end

  for i, comment in ipairs(comments) do
    if comment.id == id then
      return comment, i
    end
  end

  return nil
end

---Add a comment (supports ranges and overlaps)
---@param bufnr integer|nil
---@param start_lnum integer|nil (1-indexed, inclusive)
---@param end_lnum integer|nil (1-indexed, inclusive)
---@param text string|string[]
---@param opts table|nil {author, timestamp, resolved, collapsed}
function M.add_comment(bufnr, start_lnum, end_lnum, text, opts)
  opts = opts or {}
  bufnr = normalize_bufnr(bufnr)

  -- Handle both old API (bufnr, lnum, text, opts) and new API (bufnr, start, end, text, opts)
  if type(end_lnum) == "string" or (type(end_lnum) == "table" and end_lnum[1]) then
    text = end_lnum
    end_lnum = start_lnum
    opts = text or {}
  end

  start_lnum = start_lnum or vim.api.nvim_win_get_cursor(0)[1]
  end_lnum = end_lnum or start_lnum

  -- Ensure start <= end
  if start_lnum > end_lnum then
    start_lnum, end_lnum = end_lnum, start_lnum
  end

  -- Normalize text to string array
  local text_arr = type(text) == "string" and vim.split(text, "\n") or text

  -- Initialize state for buffer
  if not M.state[bufnr] then
    M.state[bufnr] = {}
  end

  -- Create comment with unique ID
  local comment = {
    id = next_id,
    text = text_arr,
    author = opts.author or "You",
    timestamp = opts.timestamp or os.time(),
    resolved = opts.resolved or false,
    collapsed = opts.collapsed or false,
    start_lnum = start_lnum,
    end_lnum = end_lnum,
  }

  next_id = next_id + 1

  -- Add to state (append preserves creation order)
  table.insert(M.state[bufnr], comment)

  -- Trigger render
  Renderer.render_buffer(bufnr)

  return comment.id
end

---Delete a comment by ID or by line (deletes smallest at line)
---@param bufnr integer|nil
---@param lnum_or_id integer|nil (1-indexed line, or comment ID if opts.by_id=true)
---@param opts table|nil {by_id}
function M.delete_comment(bufnr, lnum_or_id, opts)
  opts = opts or {}
  bufnr = normalize_bufnr(bufnr)

  local comment, index

  if opts.by_id then
    comment, index = find_comment_by_id(bufnr, lnum_or_id)
  else
    local lnum = lnum_or_id or vim.api.nvim_win_get_cursor(0)[1]
    comment = find_smallest_comment_at_line(bufnr, lnum)
    if comment then
      _, index = find_comment_by_id(bufnr, comment.id)
    end
  end

  if index and M.state[bufnr] then
    table.remove(M.state[bufnr], index)

    -- Clean up empty buffer state
    if #M.state[bufnr] == 0 then
      M.state[bufnr] = nil
    end
  end

  Renderer.render_buffer(bufnr)
end

---Toggle resolved state (smallest comment at line)
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed, anywhere within range)
function M.toggle_resolved(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]

  local comment = find_smallest_comment_at_line(bufnr, lnum)

  if comment then
    comment.resolved = not comment.resolved
    Renderer.render_buffer(bufnr)
  end
end

---Toggle collapsed state (smallest comment at line)
---@param bufnr integer|nil
---@param lnum integer|nil (1-indexed, anywhere within range)
function M.toggle_collapsed(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]

  local comment = find_smallest_comment_at_line(bufnr, lnum)

  if comment then
    comment.collapsed = not comment.collapsed
    Renderer.render_buffer(bufnr)
  end
end

---Edit a comment's text (by ID, or smallest at line)
---@param bufnr integer|nil
---@param lnum_or_id integer|nil (1-indexed line, or comment ID if opts.by_id=true)
---@param text string|string[]
---@param opts table|nil {by_id}
function M.edit_comment(bufnr, lnum_or_id, text, opts)
  opts = opts or {}
  bufnr = normalize_bufnr(bufnr)

  local comment

  if opts.by_id then
    comment = find_comment_by_id(bufnr, lnum_or_id)
  else
    local lnum = lnum_or_id or vim.api.nvim_win_get_cursor(0)[1]
    comment = find_smallest_comment_at_line(bufnr, lnum)
  end

  if comment then
    -- Normalize text to string array
    local text_arr = type(text) == "string" and vim.split(text, "\n") or text
    comment.text = text_arr
    Renderer.render_buffer(bufnr)
    return true
  end

  return false
end

---Get comment at line (returns smallest range)
---@param bufnr integer|nil
---@param lnum integer
---@return Comment|nil
function M.get_comment(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  return find_smallest_comment_at_line(bufnr, lnum)
end

---Get all comments at line
---@param bufnr integer|nil
---@param lnum integer
---@return Comment[]
function M.get_comments_at_line(bufnr, lnum)
  bufnr = normalize_bufnr(bufnr)
  return find_comments_at_line(bufnr, lnum)
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
  vim.api.nvim_set_hl(0, "DiffieCommentMultiple", { fg = "#f0883e", bg = "#161b22" }) -- Orange for overlaps
  vim.api.nvim_set_hl(0, "DiffieCommentRange", { bg = "#1e2530" })
end

-- Expose internals for testing
M._renderer = Renderer
M._find_comments_at_line = find_comments_at_line
M._find_smallest_comment_at_line = find_smallest_comment_at_line

return M
