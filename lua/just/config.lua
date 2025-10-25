local M = {}

local default_config = {
    message_limit = 32,         -- limit for length of fidget progress message 
    open_qf_on_error = true,    -- opens quickfix when task fails
    open_qf_on_run = true,      -- opens quickfix when running `run` task (`:JustRun`)
    open_qf_on_any = false,     -- opens quickfix when running any task (overrides other open_qf options)
    picker = "ui",              -- which picker to use: "snacks", "telescope", or "ui"
    justfile_name = "justfile",
    justfile_template = [[
# https://just.systems

default:
    just --list

build:
    echo "Building project..."
]],
}

M.config = vim.deepcopy(default_config)

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
