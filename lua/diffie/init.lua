local M = {}

--- Default configuration
M.config = {
	-- Add your default config options here
	enabled = true,
}

--- Setup function
---@param opts table|nil User configuration options
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Initialize your plugin here
	if M.config.enabled then
		vim.notify("diffie.nvim initialized!", vim.log.levels.INFO)
	end
end

return M
