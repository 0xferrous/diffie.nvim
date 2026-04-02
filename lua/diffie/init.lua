local M = {}

local comments = require("diffie.comments")

--- Default configuration
M.config = {
	enabled = true,
	sign_column = true, -- Show sign column indicators
	-- Keymap configuration: set to false to disable a keymap, or change the keys
	keymaps = {
		add = "<leader>ca",			-- Add comment (normal: current line, visual: selection)
		edit = "<leader>ce",		-- Edit comment
		delete = "<leader>cd",		-- Delete comment
		toggle_collapsed = "<leader>cc", -- Toggle collapsed status
		export = "<leader>cx",		-- Export comments to clipboard
	},
	-- Export format function: takes comments array, returns string
	-- Default format shows line ranges and comment text
	export_format = nil,
}

--- Setup function
---@param opts table|nil User configuration options
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	if not M.config.enabled then
		return
	end

	comments.setup_highlights()
	comments.set_config({
		sign_column = M.config.sign_column,
		export_format = M.config.export_format,
	})

	-- Shared action functions used by both keymaps and commands
	local actions = {}

	function actions.add(text)
		if text and text ~= "" then
			comments.add_comment(nil, nil, nil, text)
		else
			vim.ui.input({ prompt = "Comment: " }, function(input)
				if input then
					comments.add_comment(nil, nil, nil, input)
				end
			end)
		end
	end

	function actions.add_visual()
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
		local start_line = vim.fn.line("'")
		local end_line = vim.fn.line("'>")
		vim.ui.input({ prompt = "Comment on lines " .. start_line .. "-" .. end_line .. ": " }, function(input)
			if input then
				comments.add_comment(nil, start_line, end_line, input)
			end
		end)
	end

	function actions.edit()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		local bufnr = vim.api.nvim_get_current_buf()
		local all = comments.get_comments_at_line(bufnr, lnum)

		if #all == 0 then
			vim.notify("No comment at line " .. lnum, vim.log.levels.WARN)
			return
		elseif #all == 1 then
			local current_text = table.concat(all[1].text, "\n")
			vim.ui.input({ prompt = "Edit comment: ", default = current_text }, function(input)
				if input then
					comments.edit_comment(bufnr, lnum, input)
				end
			end)
		else
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
	end

	function actions.delete()
		local lnum = vim.api.nvim_win_get_cursor(0)[1]
		local bufnr = vim.api.nvim_get_current_buf()
		local all = comments.get_comments_at_line(bufnr, lnum)

		if #all == 0 then
			vim.notify("No comment at line " .. lnum, vim.log.levels.WARN)
			return
		elseif #all == 1 then
			comments.delete_comment(bufnr, lnum)
		else
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
	end

	function actions.toggle()
		comments.toggle_collapsed()
	end

	function actions.export()
		comments.export_comments()
	end

	function actions.clear()
		local bufnr = vim.api.nvim_get_current_buf()
		comments.clear_buffer(bufnr)
		vim.notify("Cleared all comments from buffer", vim.log.levels.INFO)
	end

	-- Keymaps
	local keymaps = M.config.keymaps
	local function set_keymap(mode, cfg_key, rhs, desc)
		if not keymaps or keymaps[cfg_key] == false then
			return
		end
		local lhs = keymaps[cfg_key]
		vim.keymap.set(mode, lhs, rhs, { desc = desc })
	end

	set_keymap("n", "add", function() actions.add() end, "Add review comment")
	set_keymap("v", "add", function() actions.add_visual() end, "Add review comment on selection")
	set_keymap("n", "edit", function() actions.edit() end, "Edit comment (with picker for overlaps)")
	set_keymap("n", "delete", function() actions.delete() end, "Delete comment (with picker for overlaps)")
	set_keymap("n", "toggle_collapsed", function() actions.toggle() end, "Toggle comment collapsed")
	set_keymap("n", "export", function() actions.export() end, "Export comments to clipboard")

	-- User commands - use the same action functions
	vim.api.nvim_create_user_command("DiffieAdd", function(opts)
		actions.add(opts.args)
	end, { nargs = "?", desc = "Add a comment on current line or range" })

	vim.api.nvim_create_user_command("DiffieEdit", function()
		actions.edit()
	end, { desc = "Edit comment at cursor (shows picker if overlapping)" })

	vim.api.nvim_create_user_command("DiffieDelete", function()
		actions.delete()
	end, { desc = "Delete comment at cursor (shows picker if overlapping)" })

	vim.api.nvim_create_user_command("DiffieToggle", function()
		actions.toggle()
	end, { desc = "Toggle collapsed/expanded for comment at cursor" })

	vim.api.nvim_create_user_command("DiffieExport", function()
		actions.export()
	end, { desc = "Export all comments to clipboard" })

	vim.api.nvim_create_user_command("DiffieClear", function()
		actions.clear()
	end, { desc = "Clear all comments from current buffer" })
end

-- Expose comment module
M.comments = comments

return M
