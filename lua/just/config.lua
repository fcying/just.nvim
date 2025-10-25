local M = {}

local default_config = {
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

M.config = vim.deepcopy(default_config)

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", default_config, opts or {})
end

return M
