local M = {}

function M.can_load(module)
    local ok, _ = pcall(require, module)
    return ok
end

---@param self string
---@param sep string
---@return string[]
function string:split(sep)
    local t = {}
    local pattern = string.format("([^%s]+)", sep)
    for part in self:gmatch(pattern) do
        table.insert(t, part)
    end
    return t
end
function M.split(str, sep)
    local t = {}
    local pattern = string.format("([^%s]+)", sep)
    for part in string.gmatch(str, pattern) do
        table.insert(t, part)
    end
    return t
end

---@param self string
---@param prefix string
---@return boolean
function string:starts_with(prefix)
    return self:sub(1, #prefix) == prefix
end
function M.starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

---@param self string
---@param find string
---@param repl string
---@return string
function string:replace(find, repl)
    local s, e = self:find(find, 1, true)
    if not s then
        return self
    end
    return self:sub(1, s - 1) .. repl .. self:sub(e + 1)
end

---@param self string
---@param pattern string
---@param repl string
---@return string
function string:replace_all(pattern, repl)
    local s = self:gsub(pattern, repl)
    return s
end

---@param self string
---@param pos integer
---@param text string
---@return string
function string:insert(pos, text)
    return self:sub(1, pos - 1) .. text .. self:sub(pos)
end

---@param count integer
---@return string
string["repeat"] = function(self, count)
    return self:rep(count)
end

---@param tbl table
---@return any?
function M.shift(tbl)
    table.remove(tbl, 1)
end;

---@param tbl table
---@return any?
table.pop = function(tbl)
    table.remove(tbl)
end

---@generic T
---@param sequence T[]
---@param predicate fun(v: T): boolean
---@return T[]
function table.filter(sequence, predicate)
    local newlist = {}
    for _, v in ipairs(sequence) do
        if predicate(v) then
            table.insert(newlist, v)
        end
    end
    return newlist
end

return M
