local M = {}

local context = require 'cmp.config.context'
local ts = vim.treesitter
local parsers = require 'nvim-treesitter.parsers'

M.contains = function(list, x)
  for _, v in pairs(list) do
    if v == x then return true end
  end
  return false
end


M.lines = function(str)
  local result = {}
  for line in str:gmatch '([^\n]*)\n?' do
    table.insert(result, line)
  end
  result[#result] = nil
  return result
end

M.spaces = function(n)
  local s = {}
  for i = 1, n do
    s[i] = ' '
  end
  return s
end

M.if_nil = function(val, default)
  if val == nil then return default end
  return val
end


M.path_to_otterpath = function(path, lang)
  return path .. '-tmp' .. lang
end

--- @param path string a path
--- @return string
M.otterpath_to_path = function(path)
  local s,_ = path:gsub('-tmp%..+', '')
  return s
end

--- @param path string a path
--- @return string
M.otterpath_to_plain_path = function(path)
  local s,_ = path:gsub('%..+', '')
  return s
end

--- @param path string
M.is_otterpath = function(path)
  return path:find('.+-tmp%..+') ~= nil
end

---Determine if the cursor is in any otter context, irrespective of the language
---@return boolean
M.is_otter_context = function(main_nr, tsquery)
  local ft = vim.api.nvim_buf_get_option(main_nr, 'filetype')
  local parsername = parsers.ft_to_lang(ft) or ft
  local language_tree = ts.get_parser(main_nr, parsername)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  -- create capture
  local query = ts.parse_query(parsername, tsquery)

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  col = col

  -- get text ranges
  for pattern, match, metadata in query:iter_matches(root, main_nr) do
    -- each match has two nodes, the language and the code
    -- the language node is the first one
    for id, node in pairs(match) do
      local name = query.captures[id]
      local ok, text = pcall(ts.query.get_node_text, node, 0)
      if not ok then return false end
      if name == 'code' and ts.is_in_node_range(node, row, col) then
        return true
      end
    end
  end
  return false
end

return M
