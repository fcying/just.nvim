local M = {}

function M.setup(opts)
    require("just.config").setup(opts)
    require("just.util").setup()

    local task = require("just.task")
    task.setup()
    M.run_task = task.run_task
    M.run_select_task = task.run_select_task
    M.stop_current_task = task.stop_current_task
    M.add_task_template = task.add_task_template

    vim.api.nvim_create_user_command("Just", M.run_task, {
        nargs = "?",
        complete = function()
            return vim.tbl_map(function(t) return t[2] end, get_task_names())
        end,
    })
    vim.api.nvim_create_user_command("JustSelect", M.run_select_task, {
        nargs = 0,
        desc = "Open task picker"
    })
    vim.api.nvim_create_user_command("JustStop", M.stop_current_task, {
        nargs = 0,
        desc = "Stops current task"
    })
    vim.api.nvim_create_user_command("JustCreateTemplate", M.add_task_template, {
        nargs = 0,
        desc = "Creates template for just"
    })
end

return M
