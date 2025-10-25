local M = {}
local util = require("just.util")
local config = require("just.config").config
local pick_impl = nil

-------------------------------------------------------
-- Telescope Picker
-------------------------------------------------------
function M.telescope_picker(tasks, on_select)
    local ok = util.try_require("telescope")
    if not ok then
        util.warn("Telescope not available")
        return false
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local themes = require("telescope.themes")

    local picker = pickers.new(
        themes.get_dropdown({
            prompt_title = "Just Tasks",
        }),
        {
            finder = finders.new_table({
                results = tasks,
                entry_maker = function(entry)
                    if type(entry) == "table" then
                        return {
                            value = entry[2],
                            display = entry[1],
                            ordinal = entry[1],
                        }
                    else
                        return {
                            value = entry,
                            display = entry,
                            ordinal = entry,
                        }
                    end
                end,
            }),
            sorter = conf.generic_sorter(),
            attach_mappings = function(bufnr)
                actions.select_default:replace(function()
                    actions.close(bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection and selection.value then
                        on_select(selection.value)
                    end
                end)
                return true
            end,
        }
    )
    picker:find()
    return true
end

-------------------------------------------------------
-- Snacks Picker
-------------------------------------------------------
function M.snacks_picker(tasks, on_select)
    local picker = util.try_require("snacks.picker")
    if not picker then
        util.warn("Snacks picker not available")
        return false
    end

    vim.ui.select(tasks, { prompt = "Just Tasks" }, function(choice)
        if not choice then
            return
        end
        on_select(choice)
    end)
    return true
end

-------------------------------------------------------
-- vim.ui.select
-------------------------------------------------------
function M.ui_picker(tasks, on_select)
    vim.ui.select(tasks, { prompt = "Just Tasks" }, function(choice)
        if not choice then
            return
        end
        on_select(choice)
    end)
    return true
end

function M.pick_task(tasks, on_select)
    local which = config.picker

    if not pick_impl then
        if which == "snacks" then
            pick_impl = M.snacks_picker
        elseif which == "telescope" then
            pick_impl = M.telescope_picker
        else
            pick_impl = M.ui_picker
        end
    end

    pick_impl(tasks, on_select)
end

return M
