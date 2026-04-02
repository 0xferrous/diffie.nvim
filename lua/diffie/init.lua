local M = {}

local comments = require("diffie.comments")

--- Default configuration
M.config = {
	enabled = true,
	sign_column = true, -- Show sign column indicators
}

--- Setup function
---@param opts table|nil User configuration options
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if not M.config.enabled then
		return
	end

	comments.setup_highlights()
	comments.set_config({ sign_column = M.config.sign_column })

	-- Normal mode: comment current line
	vim.keymap.set("n", "<leader>ca", function()
		vim.ui.input({ prompt = "Comment: " }, function(input)
			if input then
				comments.add_comment(nil, nil, nil, input)
			end
		end)
	end, { desc = "Add review comment" })

	-- Visual mode: comment selected range
	vim.keymap.set("v", "<leader>ca", function()
		-- Exit visual mode first
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		-- Get selection range (marks are updated after exiting visual mode)
		local start_line = vim.fn.line("'<")
		local end_line = vim.fn.line("'>")
		vim.ui.input({ prompt = "Comment on lines " .. start_line .. "-" .. end_line .. ": " }, function(input)
			if input then
				comments.add_comment(nil, start_line, end_line, input)
			end
		end)
	end, { desc = "Add review comment on selection" })

	-- Delete: if multiple comments, show picker
	vim.keymap.set("n", "<leader>cd", function()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		local bufnr = vim.api.nvim_get_current_buf()
		local all = comments.get_comments_at_line(bufnr, lnum)

		if #all == 0 then
			vim.notify("No comment at line " .. lnum, vim.log.levels.WARN)
			return
		elseif #all == 1 then
			comments.delete_comment(bufnr, lnum)
		else
			-- Show picker for multiple comments
			local items = {}
			for i, c in ipairs(all) do
				local range = c.start_lnum == c.end_lnum and ("L" .. c.start_lnum) or ("L" .. c.start_lnum .. "-" .. c.end_lnum)
				local preview = c.text[1]:sub(1, 30)
				if #c.text[1] > 30 then preview = preview .. "..." end
				table.insert(items, i .. ". [" .. range .. "] " .. preview)
			end

			vim.ui.select(items, { prompt = "Delete which comment?" }, function(_, idx)
				if idx then
					comments.delete_comment(bufnr, all[idx].id, { by_id = true })
				end
			end)
		end
	end, { desc = "Delete comment (with picker for overlaps)" })

	-- Edit: if multiple comments, show picker
	vim.keymap.set("n", "<leader>ce", function()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		local bufnr = vim.api.nvim_get_current_buf()
		local all = comments.get_comments_at_line(bufnr, lnum)

		if #all == 0 then
			vim.notify("No comment at line " .. lnum, vim.log.levels.WARN)
			return
		elseif #all == 1 then
			-- Edit the single comment
			local current_text = table.concat(all[1].text, "\n")
			vim.ui.input({ prompt = "Edit comment: ", default = current_text }, function(input)
				if input then
					comments.edit_comment(bufnr, lnum, input)
				end
			end)
		else
			-- Show picker for multiple comments
			local items = {}
			for i, c in ipairs(all) do
				local range = c.start_lnum == c.end_lnum and ("L" .. c.start_lnum) or ("L" .. c.start_lnum .. "-" .. c.end_lnum)
				local preview = c.text[1]:sub(1, 30)
				if #c.text[1] > 30 then preview = preview .. "..." end
				table.insert(items, i .. ". [" .. range .. "] " .. preview)
			end

			vim.ui.select(items, { prompt = "Edit which comment?" }, function(_, idx)
				if idx then
					local current_text = table.concat(all[idx].text, "\n")
					vim.ui.input({ prompt = "Edit comment: ", default = current_text }, function(input)
						if input then
							comments.edit_comment(bufnr, all[idx].id, input, { by_id = true })
						end
					end)
				end
			end)
		end
	end, { desc = "Edit comment (with picker for overlaps)" })

	vim.keymap.set("n", "<leader>cr", comments.toggle_resolved, { desc = "Toggle comment resolved" })
	vim.keymap.set("n", "<leader>cc", comments.toggle_collapsed, { desc = "Toggle comment collapsed" })
end

-- Expose comment module
M.comments = comments

return M
