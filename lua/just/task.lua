local M = {}
local config = require("just.config").config
local util = require("just.util")

local async_worker = nil
local use_global_justfile = false

local function run_just(cmd)
    local output = vim.fn.system(cmd)
    vim.print(cmd)
    if vim.v.shell_error ~= 0 then
        if output:match("No justfile found") then
            if vim.loop.fs_stat(config.global_justfile) then
                local fallback = vim.deepcopy(cmd)
                table.insert(fallback, "-f")
                table.insert(fallback, config.global_justfile)
                vim.print(fallback)
                output = vim.fn.system(fallback)
            end
            if vim.v.shell_error ~= 0 then
                return ""
            end
        end
    end
    return vim.trim(output)
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
        return vim.loop.os_uname().sysname
    elseif arg == "PCNAME" then
        return vim.loop.os_uname().nodename
    end
    return " "
end

local function get_task_args(task_name)
    task_name = task_name:match("^(%S+)")

    local task_info = run_just({ "just", "-s", task_name })
    if task_info == "" then
        util.err(("Failed to get task info for '%s' %s"):format(task_name, task_info))
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
    table.remove(parts, 1)

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
                util.err(("Argument '%s' is required"):format(prompt))
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
        util.err("A task is already running")
        return
    end

    local task = task_name:match("^(%S+)") or task_name
    local arg_obj = get_task_args(task)
    if arg_obj.fail then return end
    if not arg_obj.all then
        util.err("Failed to get all arguments for task")
        return
    end

    local args = arg_obj.args
    local handle = nil
    local fidget = util.try_require("fidget")
    if fidget then
        handle = fidget.progress.handle.create({
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

    local function append_qf_data(data)
        if async_worker == nil then
            return
        end

        if not data or data == "" then
            data = " "
        end

        -- clean up special characters
        data = data:gsub("'", "''")
        data = data:gsub("%z", "")

        -- Append using :caddexpr (preserves error parsing)
        vim.cmd(string.format([=[caddexpr '%s']=], data))

        if #data > config.message_limit then
            data = string.format("%s...", data:sub(1, config.message_limit))
        end

        if handle then
            handle.message = data
        end
        vim.cmd("cbottom")
    end

    local start_time = vim.loop.hrtime()
    async_worker = require("plenary.job"):new({
        command = "just",
        args = vim.list_extend({ task }, args),
        cwd = vim.fn.getcwd(),
        env = vim.fn.environ(),

        on_stdout = function(_, data)
            vim.schedule(function()
                append_qf_data(data)
            end)
        end,

        on_stderr = function(_, data)
            vim.schedule(function()
                append_qf_data(data)
            end)
        end,

        on_start = function()
            vim.fn.setqflist({ { text = ("Starting task: %s"):format(task_name) } }, "r")
        end,

        on_exit = function(_, code)
            local status = (code == 0) and "Finished" or "Failed"
            local elapsed = (vim.loop.hrtime() - start_time) / 1e9
            local elapsed_str = ("%s in %.2fs"):format(status, elapsed)
            vim.schedule(function()
                if handle then
                    handle.message = elapsed_str
                    handle:finish()
                end
                vim.fn.setqflist({ { text = elapsed_str } }, "a")
                if code ~= 0 and config.open_qf_on_error and not should_open_qf then
                    vim.cmd("copen | wincmd p")
                end
                vim.cmd("cbottom")
                if config.post_run then
                    config.post_run(code)
                end
                async_worker = nil
            end)
        end,
    })

    local ok, msg = pcall(function() async_worker:start() end)
    if not ok then
        async_worker = nil
        util.err("Failed to start job: " .. msg)
    end
end

function M.get_task_names()
    local output = run_just({ "just", "--list" })
    if vim.v.shell_error ~= 0 or output == "" then
        util.err(("Failed to run 'just --list': %s"):format(output))
        return {}
    end
    local lines = util.split(output, "\n")

    if lines[1] and util.starts_with(lines[1], "error") then
        util.err(output)
        return {}
    end
    -- remove Available recipes:
    table.remove(lines, 1)

    local tasks = {}
    for _, line in ipairs(lines) do
        local name = vim.trim(line)
        if name ~= "" then
            table.insert(tasks, name)
        end
    end
    return tasks
end

function M.run_select_task()
    local tasks = M.get_task_names()
    if #tasks == 0 then
        util.warn("There are no tasks defined in justfile")
        return
    end
    require("just.ui").pick_task(tasks, function(task_name)
        if not task_name or task_name == "" then
            util.info("Selection cancelled")
            return
        end
        task_runner(task_name)
    end)
end

function M.stop_current_task()
    if async_worker ~= nil then
        async_worker:shutdown()
        util.info("Stopped current task.")
    else
        util.warn("No running task to stop.")
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
            util.info("Cancelled creating justfile.")
            return
        end
    end

    local f, msg = io.open(filename, "w")
    if not f then
        util.err(string.format("Failed to create justfile: %s", msg))
        return
    end

    f:write(config.justfile_template)
    f:close()

    util.info(string.format("Template justfile created at %s", filename))
end

return M
