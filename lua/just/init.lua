local M = {}

function M.setup(opts)
    require("just.config").setup(opts)
    require("just.util").setup()

    local task = require("just.task")
    vim.api.nvim_create_user_command("Just", task.run_task, {
        nargs = "?",
        complete = function()
            local names = task.get_task_names()
            return vim.tbl_map(function(t)
                return type(t) == "table" and t[2] or t
            end, names)
        end,
        desc = "Run a just task",
    })
    vim.api.nvim_create_user_command("JustSelect", task.run_select_task, {
        nargs = 0,
        desc = "Open task picker"
    })
    vim.api.nvim_create_user_command("JustStop", task.stop_current_task, {
        nargs = 0,
        desc = "Stops current task"
    })
    vim.api.nvim_create_user_command("JustCreateTemplate", task.add_task_template, {
        nargs = 0,
        desc = "Creates template for just"
    })
end

return M
