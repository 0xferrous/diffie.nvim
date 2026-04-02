local comments = require("diffie.comments")

describe("comments state management", function()
  local bufnr

  before_each(function()
    -- Reset global state
    comments.state = {}
    
    -- Create a fresh buffer with content for each test
    bufnr = create_test_buffer()
  end)

  after_each(function()
    comments.clear_buffer(bufnr)
  end)

  describe("add_comment", function()
    it("stores comment in state", function()
      comments.add_comment(bufnr, 5, "Test comment")

      assert.is_not_nil(comments.state[bufnr])
      assert.is_not_nil(comments.state[bufnr][5])
      assert.same({ "Test comment" }, comments.state[bufnr][5].text)
      assert.equals("You", comments.state[bufnr][5].author)
      assert.is_false(comments.state[bufnr][5].resolved)
      assert.is_false(comments.state[bufnr][5].collapsed)
    end)

    it("accepts multiline text", function()
      comments.add_comment(bufnr, 3, "Line 1\nLine 2\nLine 3")

      assert.same({ "Line 1", "Line 2", "Line 3" }, comments.state[bufnr][3].text)
    end)

    it("accepts table of strings", function()
      comments.add_comment(bufnr, 3, { "Line 1", "Line 2" })

      assert.same({ "Line 1", "Line 2" }, comments.state[bufnr][3].text)
    end)

    it("accepts custom options", function()
      comments.add_comment(bufnr, 10, "Test", {
        author = "Alice",
        resolved = true,
        collapsed = true,
      })

      local comment = comments.state[bufnr][10]
      assert.equals("Alice", comment.author)
      assert.is_true(comment.resolved)
      assert.is_true(comment.collapsed)
    end)

    it("uses current line when lnum not provided", function()
      vim.api.nvim_win_set_cursor(0, { 7, 0 })
      comments.add_comment(bufnr, nil, "At line 7")

      assert.is_not_nil(comments.state[bufnr][7])
    end)
  end)

  describe("delete_comment", function()
    it("removes comment from state", function()
      comments.add_comment(bufnr, 5, "To delete")
      assert.is_not_nil(comments.state[bufnr][5])

      comments.delete_comment(bufnr, 5)
      -- Buffer state may be nil after cleanup, so check safely
      assert.is_true(comments.state[bufnr] == nil or comments.state[bufnr][5] == nil)
    end)

    it("cleans up empty buffer state", function()
      comments.add_comment(bufnr, 5, "Only comment")
      comments.delete_comment(bufnr, 5)

      assert.is_nil(comments.state[bufnr])
    end)
  end)

  describe("toggle_resolved", function()
    it("toggles resolved state", function()
      comments.add_comment(bufnr, 5, "Test")
      assert.is_false(comments.state[bufnr][5].resolved)

      comments.toggle_resolved(bufnr, 5)
      assert.is_true(comments.state[bufnr][5].resolved)

      comments.toggle_resolved(bufnr, 5)
      assert.is_false(comments.state[bufnr][5].resolved)
    end)

    it("does nothing on non-existent comment", function()
      -- Should not error
      comments.toggle_resolved(bufnr, 999)
    end)
  end)

  describe("toggle_collapsed", function()
    it("toggles collapsed state", function()
      comments.add_comment(bufnr, 5, "Test")
      assert.is_false(comments.state[bufnr][5].collapsed)

      comments.toggle_collapsed(bufnr, 5)
      assert.is_true(comments.state[bufnr][5].collapsed)

      comments.toggle_collapsed(bufnr, 5)
      assert.is_false(comments.state[bufnr][5].collapsed)
    end)
  end)

  describe("get_comment", function()
    it("returns comment data", function()
      comments.add_comment(bufnr, 5, "Test comment", { author = "Bob" })

      local comment = comments.get_comment(bufnr, 5)
      assert.is_not_nil(comment)
      assert.equals("Bob", comment.author)
      assert.same({ "Test comment" }, comment.text)
    end)

    it("returns nil for non-existent comment", function()
      local comment = comments.get_comment(bufnr, 999)
      assert.is_nil(comment)
    end)
  end)

  describe("clear_buffer", function()
    it("removes all comments from buffer", function()
      comments.add_comment(bufnr, 1, "One")
      comments.add_comment(bufnr, 5, "Two")
      comments.add_comment(bufnr, 10, "Three")

      comments.clear_buffer(bufnr)

      assert.is_nil(comments.state[bufnr])
    end)
  end)

  describe("state isolation", function()
    it("keeps buffers independent", function()
      -- Create second buffer with content
      local buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "A", "B", "C", "D", "E" })

      -- Only test state, skip rendering for buf2 by manipulating state directly
      comments.add_comment(bufnr, 5, "Buffer 1 comment")
      comments.state[buf2] = { [3] = { text = { "Buffer 2 comment" }, author = "test" } }

      assert.equals("Buffer 1 comment", comments.state[bufnr][5].text[1])
      assert.equals("Buffer 2 comment", comments.state[buf2][3].text[1])

      -- Clean up
      comments.state[buf2] = nil
    end)
  end)
end)

describe("comments renderer", function()
  local bufnr

  before_each(function()
    comments.state = {}
    bufnr = create_test_buffer()
    
    -- Set up buffer with some lines
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "Line 1",
      "Line 2",
      "Line 3",
      "Line 4",
      "Line 5",
    })
  end)

  after_each(function()
    comments._renderer.clear(bufnr)
    comments.state = {}
  end)

  describe("clear", function()
    it("clears all extmarks from namespace", function()
      comments.add_comment(bufnr, 2, "Test")
      
      -- Verify extmark exists
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, vim.api.nvim_create_namespace("diffie_comments"), 0, -1, {})
      assert.is_true(#marks > 0)
      
      -- Clear and verify gone
      comments._renderer.clear(bufnr)
      marks = vim.api.nvim_buf_get_extmarks(bufnr, vim.api.nvim_create_namespace("diffie_comments"), 0, -1, {})
      assert.equals(0, #marks)
    end)
  end)

  describe("render_collapsed", function()
    it("creates eol extmark", function()
      local comment = {
        text = { "Test comment" },
        author = "You",
        timestamp = os.time(),
        resolved = false,
        collapsed = true,
      }

      comments._renderer.clear(bufnr)
      local id = comments._renderer.render_collapsed(bufnr, 2, comment)
      
      assert.is_number(id)
      assert.is_true(id > 0)
    end)
  end)

  describe("render_expanded", function()
    it("creates virt_lines extmark", function()
      local comment = {
        text = { "Line 1", "Line 2" },
        author = "You",
        timestamp = os.time(),
        resolved = false,
        collapsed = false,
      }

      comments._renderer.clear(bufnr)
      local id = comments._renderer.render_expanded(bufnr, 2, comment)
      
      assert.is_number(id)
      assert.is_true(id > 0)
    end)
  end)
end)
