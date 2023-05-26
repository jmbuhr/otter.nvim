local util = require('vim.lsp.util')
local api = vim.api
local validate = vim.validate

local M = {}

function M.hover(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  -- don't ignore hover responses from other buffers
  if not (result and result.contents) then
    vim.notify('No information available')
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
  markdown_lines = util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    vim.notify('No information available')
    return
  end
  -- returns bufnr,winnr buffer and window number of the newly created floating
  local bufnr, _ = util.open_floating_preview(markdown_lines, 'markdown', config)
  return result
end

return M
