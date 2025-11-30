# just.nvim
[Just](https://github.com/casey/just) task runner for neovim.  

## Installation
With [lazy](https://github.com/folke/lazy.nvim)
```lua
{
    "fcying/just.nvim",
    dependencies = {
        'nvim-lua/plenary.nvim',            -- async jobs (required)
        'rcarriga/nvim-notify',             -- notifications (optional)
        'j-hui/fidget.nvim',                -- task progress (optional)
        'folke/snacks.nvim',                -- alternative task picker (optional)
        'nvim-telescope/telescope.nvim',    -- alternative task picker (optional)
    },
    cmd = { "Just", "JustSelect", "JustStop", "JustCreateTemplate" },
    config = true
}
```

## Configuration
Default config is:
```lua
require("just").setup({
    message_limit = 32,                 -- max length of fidget progress message
    open_qf_on_error = false,           -- open quickfix when task fail
    open_qf_on_start = true,            -- open quickfix when task start
    close_qf_on_success = false,        -- close quickfix when task success
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
})
```

### Usage
| Commands | Descriptions |
|----------|--------------|
|Just|Run `default` if no args; run given task if one arg; ! stops current task before running new one.|
|JustSelect|Select a task from `justfile`.|
|JustStop|Stop current task.|
|JustCreateTemplate|Create template justfile from `justfile_template`.|

Only one task can be executed at same time.



---
Based on [nxuv/just.nvim](https://github.com/nxuv/just.nvim).
Rewritten and extended for better integration / performance / maintainability.
