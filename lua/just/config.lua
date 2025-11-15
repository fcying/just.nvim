local M = {}

local default_config = {
    message_limit = 32,                 -- max length of fidget progress message
    open_qf_on_error = true,            -- open quickfix when task fails
    open_qf_on_run = true,              -- open quickfix when running task
    open_qf_on_any = false,             -- always open quickfix (overrides above)
    post_run = nil,                     -- callback function(return_code) triggered after a job finish
    picker = "ui",                      -- which picker to use: "snacks", "telescope", or "ui"
    global_justfile = "~/.justfile",    -- fallback global Justfile
    justfile_name = "justfile",         -- justfile name for JustCreateTemplate

    -- Template for :JustCreateTemplate
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
