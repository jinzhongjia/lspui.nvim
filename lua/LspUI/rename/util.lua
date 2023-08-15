local lsp, api, fn = vim.lsp, vim.api, vim.fn
local rename_feature = lsp.protocol.Methods.textDocument_rename
local prepare_rename_feature = lsp.protocol.Methods.textDocument_prepareRename

local config = require("LspUI.config")
local lib_util = require("LspUI.lib.util")
local lib_windows = require("LspUI.lib.windows")

local M = {}

-- get all valid clients of rename
--- @param buffer_id integer
--- @return lsp.Client[]? clients array or nil
M.get_clients = function(buffer_id)
    -- note: we need get lsp clients attached to current buffer
    local clients =
        lsp.get_clients({ bufnr = buffer_id, method = rename_feature })
    return #clients == 0 and nil or clients
end

-- rename
--- @param client lsp.Client lsp client instance, must be element of func `get_clients`
--- @param buffer_id integer buffer id
--- @param position_param lsp.RenameParams  this param must be generated by `vim.lsp.util.make_position_params`, has newname attribute
--- @param callback function
M.rename = function(client, buffer_id, position_param, callback)
    local handler = client.handlers[rename_feature]
        or lsp.handlers[rename_feature]
    client.request(rename_feature, position_param, function(...)
        handler(...)
        callback()
    end, buffer_id)
end

-- prepare rename, whether we can execute rename
-- if request return eroor, that mean we can't rename, and we should skip this
--- @param client lsp.Client lsp client instance, must be element of func `get_clients`
--- @param buffer_id integer buffer id
--- @param position_param lsp.PrepareRenameParams  this param must be generated by `vim.lsp.util.make_position_params`
--- @param callback function
M.prepare_rename = function(client, buffer_id, position_param, callback)
    client.request(prepare_rename_feature, position_param, function(err, result)
        if err or result == nil then
            callback(false)
            return
        end
        callback(true)
    end, buffer_id)
end

-- do rename, a wrap function for prepare_rename and rename
--- @param id integer
--- @param clients lsp.Client[] lsp client instance, must be element of func `get_clients`
--- @param buffer_id integer buffer id
--- @param position_param lsp.PrepareRenameParams|lsp.RenameParams this param must be generated by `vim.lsp.util.make_position_params`, has newname attribute
M.do_rename = function(id, clients, buffer_id, position_param)
    local client = clients[id]
    -- when client is nil, return
    if not client then
        return
    end
    -- TODO: client.supports_method is not listed by document
    if client.supports_method(prepare_rename_feature) then
        M.prepare_rename(
            client,
            buffer_id,
            --- @cast position_param lsp.PrepareRenameParams
            position_param,
            -- result is true, that is preparename is ok
            --- @param result boolean
            function(result)
                if result then
                    --- @cast position_param lsp.RenameParams
                    M.rename(client, buffer_id, position_param, function()
                        local next_id, _ = next(clients, id)
                        M.do_rename(next_id, clients, buffer_id, position_param)
                    end)
                else
                    local next_id, _ = next(clients, id)
                    M.do_rename(next_id, clients, buffer_id, position_param)
                end
            end
        )
    else
        --- @cast position_param lsp.RenameParams
        M.rename(client, buffer_id, position_param, function()
            local next_id, _ = next(clients, id)
            M.do_rename(next_id, clients, buffer_id, position_param)
        end)
    end
end

-- wrap windows.close_window
-- add detect insert mode
--- @param window_id integer
local close_window = function(window_id)
    if vim.fn.mode() == "i" then
        vim.cmd([[stopinsert]])
    end
    lib_windows.close_window(window_id)
end

M.render = function(clients, buffer_id, current_win, old_name)
    -- TODO: this func maybe should not pass win id ?
    local position_param = lsp.util.make_position_params(current_win)

    -- Here we need to define window

    local new_buffer = api.nvim_create_buf(false, true)

    -- note: this must set before modifiable, when modifiable is false, this function will fail
    api.nvim_buf_set_lines(new_buffer, 0, -1, false, {
        --- @cast old_name string
        old_name,
    })
    api.nvim_buf_set_option(new_buffer, "filetype", "LspUI-rename")
    api.nvim_buf_set_option(new_buffer, "modifiable", true)
    api.nvim_buf_set_option(new_buffer, "bufhidden", "wipe")

    local new_window_wrap = lib_windows.new_window(new_buffer)

    -- For aesthetics, the minimum width is 8
    local width = fn.strdisplaywidth(
        --- @cast old_name string
        old_name
    )
                    + 5
                > 8
            and fn.strdisplaywidth(old_name) + 5
        or 10

    lib_windows.set_width_window(new_window_wrap, width)
    lib_windows.set_height_window(new_window_wrap, 1)
    lib_windows.set_enter_window(new_window_wrap, true)
    lib_windows.set_anchor_window(new_window_wrap, "NW")
    lib_windows.set_border_window(new_window_wrap, "rounded")
    lib_windows.set_focusable_window(new_window_wrap, true)
    lib_windows.set_relative_window(new_window_wrap, "cursor")
    lib_windows.set_col_window(new_window_wrap, 1)
    lib_windows.set_row_window(new_window_wrap, 1)
    lib_windows.set_style_window(new_window_wrap, "minimal")
    lib_windows.set_right_title_window(new_window_wrap, "rename")

    local window_id = lib_windows.display_window(new_window_wrap)

    api.nvim_win_set_option(window_id, "winhighlight", "Normal:Normal")

    if config.options.rename.auto_select then
        vim.cmd([[normal! V]])
        api.nvim_feedkeys(
            api.nvim_replace_termcodes("<C-g>", true, true, true),
            "n",
            true
        )
    end

    -- keybinding and autocommand
    M.keybinding_autocmd(
        window_id,
        old_name,
        clients,
        buffer_id,
        new_buffer,
        position_param
    )
end

-- keybinding and autocommand
--- @param window_id integer rename float window's id
--- @param old_name string the word's old name
--- @param clients lsp.Client[] lsp clients
--- @param old_buffer integer the buffer which word belongs to
--- @param new_buffer integer the buffer which attach wto rename float window
--- @param position_param lsp.PrepareRenameParams|lsp.RenameParams this param must be generated by `vim.lsp.util.make_position_params`
M.keybinding_autocmd = function(
    window_id,
    old_name,
    clients,
    old_buffer,
    new_buffer,
    position_param
)
    -- keybinding exec
    for _, mode in pairs({ "i", "n", "v" }) do
        api.nvim_buf_set_keymap(
            new_buffer,
            mode,
            config.options.rename.key_binding.exec,
            "",
            {
                nowait = true,
                noremap = true,
                callback = function()
                    local new_name = vim.trim(api.nvim_get_current_line())
                    if old_name ~= new_name then
                        position_param.newName = new_name
                        M.do_rename(1, clients, old_buffer, position_param)
                    end
                    close_window(window_id)
                end,
                desc = lib_util.command_desc("exec rename"),
            }
        )
    end

    -- keybinding quit
    api.nvim_buf_set_keymap(
        new_buffer,
        "n",
        config.options.rename.key_binding.quit,
        "",
        {
            nowait = true,
            noremap = true,
            callback = function()
                close_window(window_id)
            end,
            desc = lib_util.command_desc("quit rename"),
        }
    )

    -- auto command: auto close window, when focus leave rename float window
    api.nvim_create_autocmd("WinLeave", {
        buffer = new_buffer,
        once = true,
        callback = function()
            close_window(window_id)
        end,
        desc = lib_util.command_desc(
            "rename auto close windows when focus leave"
        ),
    })
end

return M
