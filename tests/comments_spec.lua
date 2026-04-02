local comments = require("diffie.comments")

describe("comments state management", function()
  local bufnr

  before_each(function()
    comments.state = {}
    bufnr = create_test_buffer()
  end)

  after_each(function()
    comments.clear_buffer(bufnr)
  end)

  describe("add_comment", function()
    it("stores single-line comment in state", function()
      local id = comments.add_comment(bufnr, 5, 5, "Test comment")

      assert.is_number(id)
      assert.is_not_nil(comments.state[bufnr])
      assert.equals(1, #comments.state[bufnr])
      assert.same({ "Test comment" }, comments.state[bufnr][1].text)
      assert.is_false(comments.state[bufnr][1].resolved)
      assert.is_false(comments.state[bufnr][1].collapsed)
      assert.equals(5, comments.state[bufnr][1].start_lnum)
      assert.equals(5, comments.state[bufnr][1].end_lnum)
    end)

    it("stores range comment in state", function()
      local id = comments.add_comment(bufnr, 3, 7, "Range comment")

      assert.equals(3, comments.state[bufnr][1].start_lnum)
      assert.equals(7, comments.state[bufnr][1].end_lnum)
    end)

    it("allows overlapping comments", function()
      local id1 = comments.add_comment(bufnr, 3, 6, "First comment")
      local id2 = comments.add_comment(bufnr, 5, 8, "Second comment (overlap)")

      assert.equals(2, #comments.state[bufnr])
      assert.are_not.equal(id1, id2)

      -- Both should be findable
      local all = comments._find_comments_at_line(bufnr, 5)
      assert.equals(2, #all)
    end)

    it("swaps range if start > end", function()
      comments.add_comment(bufnr, 8, 4, "Reversed range")

      assert.equals(4, comments.state[bufnr][1].start_lnum)
      assert.equals(8, comments.state[bufnr][1].end_lnum)
    end)

    it("accepts multiline text", function()
      comments.add_comment(bufnr, 3, 3, "Line 1\nLine 2\nLine 3")

      assert.same({ "Line 1", "Line 2", "Line 3" }, comments.state[bufnr][1].text)
    end)

    it("accepts custom options", function()
      comments.add_comment(bufnr, 10, 10, "Test", {
        author = "Alice",
        resolved = true,
        collapsed = true,
      })

      local comment = comments.state[bufnr][1]
      assert.equals("Alice", comment.author)
      assert.is_true(comment.resolved)
      assert.is_true(comment.collapsed)
    end)

    it("assigns unique IDs", function()
      local id1 = comments.add_comment(bufnr, 1, 1, "First")
      local id2 = comments.add_comment(bufnr, 2, 2, "Second")
      local id3 = comments.add_comment(bufnr, 3, 3, "Third")

      assert.is_true(id1 < id2)
      assert.is_true(id2 < id3)
    end)
  end)

  describe("delete_comment", function()
    it("removes comment by line (smallest range)", function()
      comments.add_comment(bufnr, 5, 5, "To delete")
      assert.equals(1, #comments.state[bufnr])

      comments.delete_comment(bufnr, 5)
      -- Buffer state is nil when empty
      assert.is_true(comments.state[bufnr] == nil or #comments.state[bufnr] == 0)
    end)

    it("deletes smallest overlapping comment", function()
      -- Add overlapping: A(3-8), B(5-6)
      comments.add_comment(bufnr, 3, 8, "Large range")
      comments.add_comment(bufnr, 5, 6, "Small range")

      -- Delete on line 5 should delete B (smaller)
      comments.delete_comment(bufnr, 5)

      -- Should have 1 left (the large one)
      assert.equals(1, #comments.state[bufnr])
      assert.equals("Large range", comments.state[bufnr][1].text[1])
    end)

    it("cleans up empty buffer state", function()
      comments.add_comment(bufnr, 5, 5, "Only comment")
      comments.delete_comment(bufnr, 5)

      assert.is_nil(comments.state[bufnr])
    end)
  end)

  describe("edit_comment", function()
    it("edits comment text by line", function()
      comments.add_comment(bufnr, 5, 5, "Original text")

      local result = comments.edit_comment(bufnr, 5, "Updated text")

      assert.is_true(result)
      assert.same({ "Updated text" }, comments.state[bufnr][1].text)
    end)

    it("edits multiline text", function()
      comments.add_comment(bufnr, 5, 5, "Line 1")

      comments.edit_comment(bufnr, 5, "New line 1\nNew line 2")

      assert.same({ "New line 1", "New line 2" }, comments.state[bufnr][1].text)
    end)

    it("edits smallest overlapping comment", function()
      comments.add_comment(bufnr, 3, 8, "Large range")
      comments.add_comment(bufnr, 5, 6, "Small range")

      -- Edit on line 5 should edit "Small"
      comments.edit_comment(bufnr, 5, "Edited small")

      assert.equals("Edited small", comments.state[bufnr][2].text[1])
      assert.equals("Large range", comments.state[bufnr][1].text[1]) -- Unchanged
    end)

    it("edits by ID", function()
      local id = comments.add_comment(bufnr, 5, 5, "Original")

      comments.edit_comment(bufnr, id, "By ID", { by_id = true })

      assert.same({ "By ID" }, comments.state[bufnr][1].text)
    end)

    it("returns false for non-existent comment", function()
      local result = comments.edit_comment(bufnr, 999, "Text")
      assert.is_false(result)
    end)
  end)

  describe("toggle operations on overlaps", function()
    it("toggles smallest comment at line", function()
      comments.add_comment(bufnr, 3, 8, "Large")
      comments.add_comment(bufnr, 5, 6, "Small")

      -- Toggle on line 5 should affect "Small"
      comments.toggle_resolved(bufnr, 5)

      -- Find which is resolved
      local small = comments.state[bufnr][2]
      assert.is_true(small.resolved)
    end)

    it("finds smallest comment correctly", function()
      comments.add_comment(bufnr, 1, 10, "Big")
      comments.add_comment(bufnr, 3, 8, "Medium")
      comments.add_comment(bufnr, 5, 6, "Small")

      local smallest = comments._find_smallest_comment_at_line(bufnr, 5)
      assert.equals("Small", smallest.text[1])
    end)
  end)

  describe("get_comment", function()
    it("returns smallest comment at line", function()
      comments.add_comment(bufnr, 3, 8, "Large")
      comments.add_comment(bufnr, 5, 6, "Small")

      local found = comments.get_comment(bufnr, 5)
      assert.equals("Small", found.text[1])
    end)

    it("returns nil for non-existent comment", function()
      local found = comments.get_comment(bufnr, 999)
      assert.is_nil(found)
    end)
  end)

  describe("get_comments_at_line", function()
    it("returns all comments at line", function()
      comments.add_comment(bufnr, 3, 6, "A")
      comments.add_comment(bufnr, 5, 8, "B")
      comments.add_comment(bufnr, 10, 10, "C")

      local all = comments.get_comments_at_line(bufnr, 5)
      assert.equals(2, #all)
    end)
  end)

  describe("clear_buffer", function()
    it("removes all comments from buffer", function()
      comments.add_comment(bufnr, 1, 1, "One")
      comments.add_comment(bufnr, 5, 7, "Two")
      comments.add_comment(bufnr, 10, 10, "Three")

      comments.clear_buffer(bufnr)

      assert.is_nil(comments.state[bufnr])
    end)
  end)

  describe("state isolation", function()
    it("keeps buffers independent", function()
      local buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "A", "B", "C" })

      comments.add_comment(bufnr, 5, 5, "Buffer 1")
      -- Manually add to buf2 to avoid render
      comments.state[buf2] = { { text = { "Buffer 2" }, id = 999, start_lnum = 2, end_lnum = 2 } }

      assert.equals("Buffer 1", comments.state[bufnr][1].text[1])
      assert.equals("Buffer 2", comments.state[buf2][1].text[1])

      comments.state[buf2] = nil
    end)
  end)
end)

describe("comments renderer", function()
  local bufnr

  before_each(function()
    comments.state = {}
    bufnr = create_test_buffer()
  end)

  after_each(function()
    comments._renderer.clear(bufnr)
    comments.state = {}
  end)

  describe("clear", function()
    it("clears all extmarks from namespace", function()
      comments.add_comment(bufnr, 2, 2, "Test")

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, vim.api.nvim_create_namespace("diffie_comments"), 0, -1, {})
      assert.is_true(#marks > 0)

      comments._renderer.clear(bufnr)
      marks = vim.api.nvim_buf_get_extmarks(bufnr, vim.api.nvim_create_namespace("diffie_comments"), 0, -1, {})
      assert.equals(0, #marks)
    end)
  end)
end)
