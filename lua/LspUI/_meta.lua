--- @class LspUI_rename_config
--- @field enable boolean whether enable `rename` module
--- @field command_enable boolean whether enable command for `rename`
--- @field auto_select boolean whether select all string in float window
--- @field key_binding { exec: string, quit: string } keybind for `rename`

--- @class LspUI_lighthulb_config
--- @field enable boolean whether enable `lighthulb` module
--- @field is_cached boolean whether enable cache
--- @field icon string icon for lighthulb

--- @class LspUI_code_action_config
--- @field enable boolean whether enable `code_action` module
--- @field command_enable boolean whether enable command for `lighthulb`
--- @field key_binding { exec: string, prev: string, next: string, quit: string } keybind for `code_action`

--- @class LspUI_config config for LspUI
--- @field rename LspUI_rename_config `rename` module
--- @field lighthulb LspUI_lighthulb_config `lighthulb` module
--- @field code_action LspUI_code_action_config `code_action` module