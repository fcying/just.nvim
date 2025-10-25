local M = {}
local notify
local loaded = {}

local function popup(msg, level, title)
    notify(msg, level or vim.log.levels.INFO, { title = title or "Just" })
end
function M.info(msg) popup(msg, vim.log.levels.INFO, "Just") end

function M.warn(msg) popup(msg, vim.log.levels.WARN, "Just") end

function M.err(msg) popup(msg, vim.log.levels.ERROR, "Just") end

function M.try_require(module)
    if loaded[module] ~= nil then
        return loaded[module]
    end
    local ok, lib = pcall(require, module)
    if ok then
        loaded[module] = lib
        return lib
    end
    loaded[module] = false
    return false
end

function M.split(str, sep)
    local t = {}
    local pattern = string.format("([^%s]+)", sep)
    for part in string.gmatch(str, pattern) do
        table.insert(t, part)
    end
    return t
end

function M.starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

function M.setup()
    local mod = M.try_require("notify")
    if mod then
        notify = mod
    else
        notify = vim.notify
    end
end

return M
