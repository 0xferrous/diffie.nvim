local M = {}

local comments = require("diffie.comments")

--- Default configuration
M.config = {
	enabled = true,
}

--- Setup function
---@param opts table|nil User configuration options
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if not M.config.enabled then
		return
	end

	comments.setup_highlights()

	-- Example mappings
	vim.keymap.set("n", "<leader>ca", function()
		vim.ui.input({ prompt = "Comment: " }, function(input)
			if input then
				comments.add_comment(nil, nil, input)
			end
		end)
	end, { desc = "Add review comment" })

	vim.keymap.set("n", "<leader>cd", comments.delete_comment, { desc = "Delete comment at line" })
	vim.keymap.set("n", "<leader>cr", comments.toggle_resolved, { desc = "Toggle comment resolved" })
	vim.keymap.set("n", "<leader>cc", comments.toggle_collapsed, { desc = "Toggle comment collapsed" })
end

-- Expose comment module
M.comments = comments

return M
