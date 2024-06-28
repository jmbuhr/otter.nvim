-- custom handlers for otter-ls where the default handlers are not sufficient
-- example:
-- vim.lsp.handlers.hover(_?, result, ctx, config)
local util = vim.lsp.util
local otterpath_to_path = require("otter.tools.functions").otterpath_to_path
local api = vim.api
local otterconfig = require("otter.config").cfg
local ms = vim.lsp.protocol.Methods

local M = {}

local has_telescope = false
local ok, mod = pcall(require, "telescope")
if ok then
  has_telescope = true
end

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

---@param _ lsp.ResponseError?
---@param result lsp.Hover
---@param ctx lsp.HandlerContext
--- see
--- vim.lsp.handlers.hover(_, result, ctx, config)
M[ms.textDocument_hover] = function(_, response, ctx, _)
  local opts = otterconfig.lsp.hover
  opts.focus_id = ctx.method
  -- don't ignore hover responses from other buffers
  if not (response and response.contents) then
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(response.contents)
  markdown_lines = trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    return
  end
  -- returns bufnr,winnr buffer and window number of the newly created floating
  return util.open_floating_preview(markdown_lines, "markdown", opts)
end

-- elseif method == "textDocument/definition" then
--   local function redirect_definition(res)
--     if res.uri ~= nil then
--       if require("otter.tools.functions").is_otterpath(res.uri) then
--         res.uri = main_uri
--       end
--     end
--     if res.targetUri ~= nil then
--       if require("otter.tools.functions").is_otterpath(res.targetUri) then
--         res.targetUri = main_uri
--       end
--     end
--     return res
--   end
--   M.send_request(main_nr, method, params, function(response)
--     if #response == 0 then
--       return redirect_definition(response)
--     end
--
--     local modified_response = {}
--     for _, res in ipairs(response) do
--       table.insert(modified_response, redirect_definition(res))
--     end
--     return modified_response
--   end)
M[ms.textDocument_definition] = function(_, response, ctx)
  if #response == 0 then
    if response.uri ~= nil then
      if require("otter.tools.functions").is_otterpath(response.uri) then
        response.uri = ctx.params.otter.main_uri
      end
    end
    if response.targetUri ~= nil then
      if require("otter.tools.functions").is_otterpath(response.targetUri) then
        response.targetUri = ctx.params.otter.main_uri
      end
    end
  else
    for _, resp in ipairs(response) do
      if resp.uri ~= nil then
        if require("otter.tools.functions").is_otterpath(resp.uri) then
          resp.uri = ctx.params.otter.main_uri
        end
      end
      if resp.targetUri ~= nil then
        if require("otter.tools.functions").is_otterpath(resp.targetUri) then
          resp.targetUri = ctx.params.otter.main_uri
        end
      end
    end
  end
  vim.lsp.handlers["textDocument/definition"](_, response, ctx)
end

--see: https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
M[ms.textDocument_documentSymbol] = function(err, response, ctx, conf)
  conf = conf or {}
  if not response then
    return
  end
  ctx.params.textDocument.uri = otterpath_to_path(ctx.params.textDocument.uri)
  local items = util.symbols_to_items(response)
  local fname = vim.fn.fnamemodify(vim.uri_to_fname(ctx.params.textDocument.uri), ":.")
  local title = string.format("Symbols in %s", fname)

  if conf.loclist then
    vim.fn.setloclist(0, {}, " ", { title = title, items = items, context = ctx })
    api.nvim_command("lopen")
  elseif conf.on_list then
    assert(type(conf.on_list) == "function", "on_list is not a function")
    conf.on_list({ title = title, items = items, context = ctx })
  elseif has_telescope then
    vim.fn.setqflist({}, " ", { title = title, items = items, context = ctx })
    vim.cmd([[Telescope quickfix]])
  else
    vim.fn.setqflist({}, " ", { title = title, items = items, context = ctx })
    api.nvim_command("botright copen")
  end
end

M[ms.textDocument_rangeFormatting] = function(err, response, ctx, conf)
  conf = conf or {}
  if not response then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end
  util.apply_text_edits(response, conf.main_nr, client.offset_encoding)
end

return M
