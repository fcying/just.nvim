# just.nvim
[Just](https://github.com/fcying/just.nvim) task runner for neovim

## Installation
Using [lazy](https://github.com/folke/lazy.nvim)
```lua
{
    "fcying/just.nvim",
    dependencies = {
        'nvim-lua/plenary.nvim', -- async jobs
        'nvim-telescope/telescope.nvim', -- task picker (optional)
        'rcarriga/nvim-notify', -- general notifications (optional)
        'j-hui/fidget.nvim', -- task progress (optional)
    },
    config = true
}
```

## Configuration
Default config is:
```lua
require("just").setup({
    message_limit = 32, -- limit for length of fidget progress message 
    open_qf_on_error = true, -- opens quickfix when task fails
    open_qf_on_run = true, -- opens quickfix when running `run` task (`:JustRun`)
    open_qf_on_any = false; -- opens quickfix when running any task (overrides other open_qf options)
    telescope_borders = { -- borders for telescope window
        prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" }, 
        results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
        preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
    }
})
```

### Usage
Commands:
- `Just` - If 0 args supplied runs `default` task, if 1 arg supplied runs task passes as that arg. If ran with bang (`!`) then stops currently running task before executing new one.
- `JustSelect` - Gives you selection of all tasks in `justfile`.
- `JustStop` - Stops currently executed task
- `JustCreateTemplate` - Creates template `justfile` with included "cheatsheet".

Only one task can be executed at same time.

Forked and rewrite from [nxuv/just.nvim](https://github.com/nxuv/just.nvim)
