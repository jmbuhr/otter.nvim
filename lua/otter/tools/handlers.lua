local util = vim.lsp.util
local otterpath_to_path = require("otter.tools.functions").otterpath_to_path
local api = vim.api

local has_telescope = false
local ok, mod = pcall(require, "telescope")
if ok then
  has_telescope = true
end

local M = {}

local function trim_empty_lines(lines)
  local start = 1
  for i = 1, #lines do
    if lines[i] ~= nil and #lines[i] > 0 then
      start = i
      break
    end
  end
  local finish = 1
  for i = #lines, 1, -1 do
    if lines[i] ~= nil and #lines[i] > 0 then
      finish = i
      break
    end
  end
  return vim.list_extend({}, lines, start, finish)
end

function M.hover(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  -- don't ignore hover responses from other buffers
  if not (result and result.contents) then
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
  markdown_lines = trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    return
  end
  -- returns bufnr,winnr buffer and window number of the newly created floating
  local bufnr, _ = util.open_floating_preview(markdown_lines, "markdown", config)
  -- vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
  return result
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
function M.document_symbol(_, result, ctx, config)
  config = config or {}
  if not result then
    return
  end
  ctx.params.textDocument.uri = otterpath_to_path(ctx.params.textDocument.uri)
  local items = util.symbols_to_items(result)
  local fname = vim.fn.fnamemodify(vim.uri_to_fname(ctx.params.textDocument.uri), ":.")
  local title = string.format("Symbols in %s", fname)

  if config.loclist then
    vim.fn.setloclist(0, {}, " ", { title = title, items = items, context = ctx })
    api.nvim_command("lopen")
  elseif config.on_list then
    assert(type(config.on_list) == "function", "on_list is not a function")
    config.on_list({ title = title, items = items, context = ctx })
  elseif has_telescope then
    vim.fn.setqflist({}, " ", { title = title, items = items, context = ctx })
    vim.cmd([[Telescope quickfix]])
  else
    vim.fn.setqflist({}, " ", { title = title, items = items, context = ctx })
    api.nvim_command("botright copen")
  end
end

M.format = function(_, result, ctx, _)
  if not result then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end
  -- use the current buffer, 0
  util.apply_text_edits(result, 0, client.offset_encoding)
end

return M
