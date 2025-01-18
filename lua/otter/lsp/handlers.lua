--- Intermediate handlers for otter-ls where the response needs to be modified
--- before being passed on to the default handler
--- docs: https://microsoft.github.io/language-server-protocol/specifications/specification-current/
---@type table<string, lsp.Handler>
local M = {}

local fn = require("otter.tools.functions")
local ms = vim.lsp.protocol.Methods
local keeper = require("otter.keeper")
local modify_position = keeper.modify_position

local function filter_one_or_many(response, filter)
  if #response == 0 then
    return filter(response)
  else
    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, filter(res))
    end
    return modified_response
  end
end

--- see e.g.
--- vim.lsp.handlers.hover(_, result, ctx)
---@param err lsp.ResponseError?
---@param response lsp.Hover
---@param ctx lsp.HandlerContext
M[ms.textDocument_hover] = function(err, response, ctx)
  if not response then
    -- no response, nothing to do
    return
  end

  -- pretend the response is coming from the main buffer
  ctx.params.textDocument.uri = ctx.params.otter.main_uri

  -- pass modified response on to the default handler
  return err, response, ctx
end

M[ms.textDocument_inlayHint] = function(err, response, ctx)
  if not response then
    return
  end

  -- pretend the response is coming from the main buffer
  ctx.params.textDocument.uri = ctx.params.otter.main_uri

  return err, response, ctx
end

M[ms.textDocument_definition] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    if res.uri ~= nil then
      if fn.is_otterpath(res.uri) then
        res.uri = ctx.params.otter.main_uri
      end
    end
    if res.targetUri ~= nil then
      if fn.is_otterpath(res.targetUri) then
        res.targetUri = ctx.params.otter.main_uri
      end
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)
  return err, response, ctx
end

M[ms.textDocument_documentSymbol] = function(err, response, ctx)
  if not response then
    return
  end

  local function filter(res)
    if not res.location or not res.location.uri then
      return res
    end
    local uri = res.location.uri
    if fn.is_otterpath(uri) then
      res.location.uri = ctx.params.otter.main_uri
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)

  ctx.params.textDocument.uri = fn.otterpath_to_path(ctx.params.textDocument.uri)
  return err, response, ctx
end

M[ms.textDocument_typeDefinition] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    if res.uri ~= nil then
      if fn.is_otterpath(res.uri) then
        res.uri = ctx.params.otter.main_uri
      end
    end
    if res.targetUri ~= nil then
      if fn.is_otterpath(res.targetUri) then
        res.targetUri = ctx.params.otter.main_uri
      end
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)

  return err, response, ctx
end

M[ms.textDocument_rename] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    local changes = res.changes
    if changes ~= nil then
      local new_changes = {}
      for uri, change in pairs(changes) do
        if fn.is_otterpath(uri) then
          uri = ctx.params.otter.main_uri
        end
        new_changes[uri] = change
      end
      res.changes = new_changes
      modify_position(res, ctx.params.otter.main_nr)
      return res
    else
      changes = res.documentChanges
      local new_changes = {}
      for _, change in ipairs(changes) do
        local uri = change.textDocument.uri
        if fn.is_otterpath(uri) then
          change.textDocument.uri = ctx.params.otter.main_uri
        end
        table.insert(new_changes, change)
      end
      res.documentChanges = new_changes
      modify_position(res, ctx.params.otter.main_nr)
      return res
    end
  end
  response = filter_one_or_many(response, filter)
  return err, response, ctx
end

M[ms.textDocument_references] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    local uri = res.uri
    if not res.uri then
      return res
    end
    if fn.is_otterpath(uri) then
      res.uri = ctx.params.otter.main_uri
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)

  -- change the ctx after the otter buffer has responded
  ctx.params.textDocument.uri = fn.otterpath_to_path(ctx.params.textDocument.uri)
  return err, response, ctx
end

M[ms.textDocument_implementation] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    if res.uri ~= nil then
      if fn.is_otterpath(res.uri) then
        res.uri = ctx.params.otter.main_uri
      end
    end
    if res.targetUri ~= nil then
      if fn.is_otterpath(res.targetUri) then
        res.targetUri = ctx.params.otter.main_uri
      end
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)

  return err, response, ctx
end

M[ms.textDocument_declaration] = function(err, response, ctx)
  if not response then
    return
  end
  local function filter(res)
    if res.uri ~= nil then
      if fn.is_otterpath(res.uri) then
        res.uri = ctx.params.otter.main_uri
      end
    end
    if res.targetUri ~= nil then
      if fn.is_otterpath(res.targetUri) then
        res.targetUri = ctx.params.otter.main_uri
      end
    end
    modify_position(res, ctx.params.otter.main_nr)
    return res
  end
  response = filter_one_or_many(response, filter)
  return err, response, ctx
end

--- Modifying textDocument_completion
--- was not strictly required in the completion handlers tested so far,
--- but why not.
--- Might come in handy down the line.
M[ms.textDocument_completion] = function(err, response, ctx)
  ctx.params.textDocument.uri = ctx.params.otter.main_uri
  ctx.bufnr = ctx.params.otter.main_nr
  for _, item in ipairs(response.items) do
    if item.data ~= nil then
      item.data.uri = ctx.params.otter.main_uri
    end
  end

  return err, response, ctx
end

--- Modifying completionItem_resolve
--- was not strictly required in the completion handlers tested so far,
--- even without it e.g. auto imports are done in the main buffer already
M[ms.completionItem_resolve] = function(err, response, ctx)
  if response == nil then
    return err, response, ctx
  end

  if ctx.params.data ~= nil then
    ctx.params.data.uri = ctx.params.otter.main_uri
  end
  ctx.params.textDocument.uri = ctx.params.otter.main_uri
  ctx.bufnr = ctx.params.otter.main_nr

  ---blink.cmp modifies the context of the completionItem/resolve handler
  ---and adds those fields to it.
  if ctx.params.textEdit ~= nil then
    if ctx.params.textEdit.range ~= nil then
      modify_position(ctx.params.textEdit, ctx.params.otter.main_nr)
    end
    if ctx.params.textEdit.insert ~= nil then
      modify_position(ctx.params.textEdit, ctx.params.otter.main_nr)
    end
    if ctx.params.textEdit.replace ~= nil then
      modify_position(ctx.params.textEdit, ctx.params.otter.main_nr)
    end
  end

  if response.textDocument ~= nil then
    response.textDocument.uri = ctx.params.otter.main_uri
  end

  if response.data ~= nil then
    if response.data.file ~= nil then
      response.data.file = ctx.params.otter.main_uri:gsub("file://", "")
    end
    if response.data.offset ~= nil then
      response.data.offset = response.data.offset +
      keeper.get_leading_offset(response.data.line, ctx.params.otter.main_nr)
    end
  end

  if response.textEdit ~= nil then
    if response.textEdit.range ~= nil then
      modify_position(response.textEdit, ctx.params.otter.main_nr)
    end
    if response.textEdit.insert ~= nil then
      modify_position(response.textEdit, ctx.params.otter.main_nr)
    end
    if response.textEdit.replace ~= nil then
      modify_position(response.textEdit, ctx.params.otter.main_nr)
    end
  end
  response.textDocument.uri = ctx.params.otter.main_uri

  return err, response, ctx
end

return M
