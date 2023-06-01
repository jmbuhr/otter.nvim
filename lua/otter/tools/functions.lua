local M = {}

local ts = vim.treesitter
local tsq = require 'nvim-treesitter.query'

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


M.empty_lines = function(n)
  local s = {}
  for i = 1, n do
    s[i] = ''
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
  local s, _ = path:gsub('-tmp%..+', '')
  return s
end

--- @param path string a path
--- @return string
M.otterpath_to_plain_path = function(path)
  local s, _ = path:gsub('%..+', '')
  return s
end

--- @param path string
M.is_otterpath = function(path)
  return path:find('.+-tmp%..+') ~= nil
end


M.get_current_language_context = function(main_nr)
  main_nr = main_nr or 0

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  col = col

  local main_ft = vim.api.nvim_buf_get_option(main_nr, 'filetype')
  local parsername = ts.language.get_lang(main_ft)
  if parsername == nil then return {} end
  local parser = ts.get_parser(main_nr, parsername)
  local query = tsq.get_query(parsername, 'injections')
  local tree = parser:parse()
  local root = tree[1]:root()

  local found_chunk = false
  local lang_capture
  for id, node, metadata in query:iter_captures(root, main_nr) do
    local name = query.captures[id]
    local text

    -- chunks where the name of the injected language is dynamic
    -- e.g. markdown code chunks
    if name == '_lang' then
      text = ts.get_node_text(node, main_nr, metadata)
      lang_capture = text
      found_chunk = true
    end
    if name == 'content' and found_chunk and ts.is_in_node_range(node, row, col) then
      return lang_capture
    end

    if ts.is_in_node_range(node, row, col) then
      return name
    end
  end
end


M.is_otter_language_context = function(lang)
  vim.b['quarto_is_' .. lang .. '_chunk'] = false
  local current = M.get_current_language_context(0)
  if current == lang then
    vim.b['quarto_is_' .. lang .. '_chunk'] = true
  end
end


return M
