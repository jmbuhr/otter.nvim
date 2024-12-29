local M = {}

local config = require("otter.config")

M.contains = function(list, x)
  for _, v in pairs(list) do
    if v == x then
      return true
    end
  end
  return false
end

M.replace_header_div = function(response)
  response.contents = response.contents:gsub('<div class="container">', "")
  -- response.contents = response.contents:gsub('``` R', '```r')
  return response
end

---strip wrapping quotes from a string
---@param s string
---@return string s, boolean stripped The stripped string and a boolean indicating whether the string was stripped
M.strip_wrapping_quotes = function(s)
  for _, c in ipairs(config.cfg.strip_wrapping_quote_characters) do
    if s:sub(1, 1) == c and s:sub(#s, #s) == c then
      return s:sub(2, #s - 1), true
    end
  end
  return s, false
end

---split a string by newlines
---@param str string
---@return string[]
M.lines = function(str)
  local result = {}
  for line in str:gmatch("([^\n]*)\n?") do
    table.insert(result, line)
  end
  result[#result] = nil
  return result
end

M.concat = function(ls)
  local s = ""
  for _, l in ipairs(ls) do
    if l ~= "" then
      s = s .. "\n" .. l
    end
  end
  return s .. "\n"
end

M.unlines = function(ls)
  local s = ""
  for _, l in ipairs(ls) do
    s = s .. "\n" .. l
  end
  return s .. "\n"
end

M.spaces = function(n)
  local s = {}
  for i = 1, n do
    s[i] = " "
  end
  return s
end

M.empty_lines = function(n)
  local s = {}
  for i = 1, n do
    s[i] = ""
  end
  return s
end

M.if_nil = function(val, default)
  if val == nil then
    return default
  end
  return val
end

M.path_to_otterpath = function(path, lang)
  return path .. ".otter" .. lang
end

--- @param path string a path
--- @return string
M.otterpath_to_path = function(path)
  local s, _ = path:gsub("%.otter%..+", "")
  return s
end

--- @param path string a path
--- @return string
M.otterpath_to_plain_path = function(path)
  local s, _ = path:gsub("%..+%.otter%..+$", "")
  return s
end

--- @param path string
M.is_otterpath = function(path)
  return path:find(".+.otter%..+") ~= nil
end

M.is_otter_language_context = function(lang)
  vim.b["quarto_is_" .. lang .. "_chunk"] = false
  local current = require("otter.keeper").get_current_language_context()
  if current == lang then
    vim.b["quarto_is_" .. lang .. "_chunk"] = true
    return true
  else
    return false
  end
end

return M
