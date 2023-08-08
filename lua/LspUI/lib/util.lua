local api, fn = vim.api, vim.fn
local M = {}

local version = "v2-undefined"

local key_bind_opt = { noremap = true, silent = true }
local move_keys = { "h", "ge", "e", "0", "$", "l", "w", "b", "<Bs>", "j", "k", "<Left>", "<Right>", "<Up>", "<Down>" }
local other_keys = { "x", "y", "v", "o", "O", "q" }

-- disable keys about moving
--- @param buffer_id integer
M.disable_move_keys = function(buffer_id)
	for _, key in pairs(move_keys) do
		api.nvim_buf_set_keymap(buffer_id, "n", key, "", key_bind_opt)
	end
	for _, key in pairs(other_keys) do
		api.nvim_buf_set_keymap(buffer_id, "n", key, "", key_bind_opt)
	end
end

-- check buffer is listed ?
--- @param buffer_id integer
--- @return boolean
M.buffer_is_listed = function(buffer_id)
	return fn.buflisted(buffer_id) == 1
end

-- generate command description
--- @param desc string
M.command_desc = function(desc)
	return "[LspUI]: " .. desc
end

M.version = function()
	return version
end

return M