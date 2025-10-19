local M = {}
local util = require("just.util")

local config = {
    message_limit = 32,
    open_qf_on_error = true,
    open_qf_on_run = true,
    open_qf_on_any = false,
    justfile_name = "justfile",
    justfile_template = [[
# https://just.systems

default:
    just --list

build:
    echo "Building project..."
]],
    telescope_borders = {
        prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
        results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
        preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
    }
}

local async_worker = nil
local notify
local progress
local pickers = nil
local finders
local conf
local actions
local action_state
local themes

local function load_telescope_deps()
    if pickers ~= nil then
        return true
    end
    local ok = util.can_load("telescope")
    if not ok then
        return false
    end
    pickers = require("telescope.pickers")
    finders = require("telescope.finders")
    conf = require("telescope.config").values
    actions = require("telescope.actions")
    action_state = require("telescope.actions.state")
    themes = require("telescope.themes")
    return true
end

local function load_setup_deps()
    local ok_notify, n = pcall(require, "notify")
    notify = ok_notify and n or function(msg, level)
        if level == "error" then
            vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, { err = true })
        else
            vim.api.nvim_echo({ { msg, "Normal" } }, false, {})
        end
    end

    local ok_fidget, f = pcall(require, "fidget")
    if ok_fidget and f.progress then
        progress = f.progress
    end
end

local function popup(msg, level, title)
    notify(msg, level or "info", { title = title or "Just" })
end
local function info(msg) popup(msg, "info", "Just") end
local function warning(msg) popup(msg, "warn", "Just") end
local function error(msg) popup(msg, "error", "Just") end

local function get_task_names()
    local output = vim.fn.system("just --list")
    local lines = util.split(output, "\n")

    if lines[1] and util.starts_with(lines[1], "error") then
        error(output)
        return {}
    end
    util.shift(lines)

    local tasks = {}
    for _, line in ipairs(lines) do
        local parts = util.split(line, "#")
        local name = vim.trim(parts[1] or "")
        local comment = vim.trim(parts[2] or "")
        if name ~= "" then
            if pickers then
                local disp = name
                if comment ~= "" then disp = disp .. " — " .. comment end
                table.insert(tasks, { disp, name })
            else
                table.insert(tasks, name)
            end
        end
    end
    return tasks
end

local keyword_map = {
    FILEPATH = "%:p",
    FILENAME = "%:t",
    FILEDIR = "%:p:h",
    FILEEXT = "%:e",
    FILENOEXT = "%:t:r",
    CWD = "cwd",
    RELPATH = "%",
    RELDIR = "%:h",
}

local function check_keyword_arg(arg)
    local key = keyword_map[arg]
    if key then
        return key == "cwd" and vim.fn.getcwd() or vim.fn.expand(key)
    elseif arg == "TIME" then
        return os.date("%H:%M:%S")
    elseif arg == "DATE" then
        return os.date("%d/%m/%Y")
    elseif arg == "USDATE" then
        return os.date("%m/%d/%Y")
    elseif arg == "USERNAME" then
        return os.getenv("USER") or "unknown"
    elseif arg == "OS" then
        return vim.trim(vim.fn.system("uname"))
    elseif arg == "PCNAME" then
        return vim.trim(vim.fn.system("hostname"))
    end
    return " "
end

local function get_task_args(task_name)
    task_name = task_name:match("^(%S+)")

    local task_info = vim.fn.system(string.format("just -s %s", task_name))
    if vim.v.shell_error ~= 0 then
        error(("Failed to get task info for '%s'"):format(task_name))
        return { args = {}, all = false, fail = true }
    end

    local lines = util.split(task_info, "\n")
    local useful = {}
    for _, line in ipairs(lines) do
        if not (line:match("^#") or line:match("^alias")) then
            table.insert(useful, line)
        end
    end

    local signature = useful[1] and useful[1]:match("^[^:]+") or ""
    local parts = util.split(signature, " ")
    util.shift(parts) -- remove task name itself

    if #parts == 0 then
        return { args = {}, all = true, fail = false }
    end

    local out_args = {}
    for _, arg in ipairs(parts) do
        local keyword = check_keyword_arg(arg)
        local name, default = arg:match("^(.-)=%((.-)%)$")
        if not name then
            name, default = arg:match("^(.-)=(.*)$")
        end

        if keyword == " " then
            local prompt = name or arg
            local initial = default or ""
            local input_val = vim.fn.input(prompt .. ": ", initial)
            if input_val == "" then
                error(("Argument '%s' is required"):format(prompt))
                return { args = {}, all = false, fail = true }
            end
            table.insert(out_args, ("%s=%s"):format(prompt, input_val))
        else
            table.insert(out_args, ("%s=%s"):format(name or arg, default or keyword))
        end
    end

    return {
        args = out_args,
        all = #out_args == #parts,
        fail = false,
    }
end

local function task_runner(task_name)
    if async_worker then
        error("A task is already running")
        return
    end

    local task = task_name:match("^(%S+)") or task_name
    local arg_obj = get_task_args(task)
    if arg_obj.fail then return end
    if not arg_obj.all then
        error("Failed to get all arguments for task")
        return
    end

    local args = arg_obj.args
    local handle
    if progress then
        handle = progress.handle.create({
            title = "",
            message = ("Starting task \"%s\""):format(task),
            lsp_client = { name = "Just" },
            percentage = 0,
        })
    end

    local should_open_qf = config.open_qf_on_any or (config.open_qf_on_run and task == "run")
    if should_open_qf then
        vim.cmd("copen")
        vim.cmd("wincmd p")
    end
    vim.fn.setqflist({ { text = ("Starting task: just %s %s"):format(task, table.concat(args, " ")) } }, "r")

    local start_time = os.clock()
    async_worker = require("plenary.job"):new({
        command = "just",
        args = vim.list_extend({ task }, args),
        cwd = vim.fn.getcwd(),
        env = vim.fn.environ(),

        on_stdout = function(_, data)
            if data and data ~= "" then
                vim.schedule(function()
                    vim.cmd(("caddexpr '%s'"):format(data:gsub("'", "''")))
                    if handle then handle.message = data end
                end)
            end
        end,

        on_stderr = function(_, data)
            if data and data ~= "" then
                vim.schedule(function()
                    vim.cmd(("caddexpr '%s'"):format(data:gsub("'", "''")))
                end)
            end
        end,

        on_exit = function(_, code)
            local elapsed = os.clock() - start_time
            vim.schedule(function()
                local status = (code == 0) and "Finished" or "Failed"
                if handle then
                    handle.message = status
                    handle:finish()
                end
                vim.fn.setqflist({
                    { text = "" },
                    { text = ("%s in %.2fs"):format(status, elapsed) },
                }, "a")
                vim.cmd("cbottom")
                if code ~= 0 and config.open_qf_on_error then
                    vim.cmd("copen | wincmd p")
                end
                async_worker = nil
            end)
        end,
    })

    async_worker:start()
end

function M.task_select(opts)
    opts = opts or {}

    local tasks = get_task_names()
    if #tasks == 0 then
        popup("No tasks found in justfile", "warn")
        return
    end

    if pickers then
        local picker = pickers.new(
            themes.get_dropdown(vim.tbl_extend("force", {
                prompt_title = "Just Tasks",
                borderchars = config.telescope_borders.preview,
            }, opts)),
            {
                finder = finders.new_table({
                    results = tasks,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry[1],
                            ordinal = entry[1],
                        }
                    end,
                }),
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(bufnr)
                    actions.select_default:replace(function()
                        actions.close(bufnr)
                        local selection = action_state.get_selected_entry()
                        if not selection or not selection.value then
                            popup("No selection made", "warn")
                            return
                        end

                        -- use first word
                        local full_name = selection.value[2]
                        local task_name = full_name:match("^(%S+)")
                        if not task_name then
                            popup("Invalid task name", "error")
                            return
                        end
                        task_runner(task_name)
                    end)
                    return true
                end,
            }
        )
        picker:find()
        return
    end

    vim.ui.select(tasks, { prompt = "Select task" }, function(choice)
        if not choice then
            popup("Selection cancelled", "info")
            return
        end
        local task_name = choice:match("^(%S+)")
        if not task_name then
            popup("Invalid task name", "error")
            return
        end
        task_runner(task_name)
    end)
end

function M.run_select_task()
    local tasks = get_task_names()
    if #tasks == 0 then
        warning("There are no tasks defined in justfile")
        return
    end
    if pickers ~= nil then
        M.task_select(themes.get_dropdown({ borderchars = config.telescope_borders }))
    else
        M.task_select()
    end
end

function M.stop_current_task()
    if async_worker ~= nil then
        async_worker:shutdown()
    end
    async_worker = nil
end

function M.run_task(args)
    if args.bang then
        M.stop_current_task()
    end
    if #args.fargs == 0 then
        task_runner("default")
    else
        task_runner(args.fargs[1])
    end
end

---@param opts? { path?: string }
function M.add_task_template(opts)
    opts = opts or {}
    local filename = opts.path or (vim.fn.getcwd() .. "/" .. config.justfile_name)

    if vim.fn.filereadable(filename) == 1 then
        local choice = vim.fn.confirm(
            string.format("A justfile already exists at:\n%s\nOverwrite it?", filename),
            "&Yes\n&No",
            2
        )
        if choice ~= 1 then
            info("Cancelled creating justfile.")
            return
        end
    end

    local f, err = io.open(filename, "w")
    if not f then
        error(string.format("Failed to create justfile: %s", err))
        return
    end

    f:write(config.justfile_template)
    f:close()

    info(string.format("Template justfile created at %s", filename))
end

function M.setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", config, opts)
    load_setup_deps()
    load_telescope_deps()

    vim.api.nvim_create_user_command("Just", M.run_task, {
        nargs = "?",
        complete = function()
            return vim.tbl_map(function(t) return t[2] end, get_task_names())
        end,
    })
    vim.api.nvim_create_user_command("JustSelect", M.run_select_task, { nargs = 0, desc = "Open task picker" })
    vim.api.nvim_create_user_command("JustStop", M.stop_current_task, { nargs = 0, desc = "Stops current task" })
    vim.api.nvim_create_user_command("JustCreateTemplate", M.add_task_template,
        { nargs = 0, desc = "Creates template for just" })
end

return M
