--- Intermediate handlers for otter-ls where the response needs to be modified
--- before being passed on to the default handler
--- docs: https://microsoft.github.io/language-server-protocol/specifications/specification-current/
---@type table<string, lsp.Handler>
local M = {}

local fn = require("otter.tools.functions")
local ms = vim.lsp.protocol.Methods
local modify_position = require("otter.keeper").modify_position

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
    return err, response, ctx
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
    return err, response, ctx
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
    return err, response, ctx
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
    return err, response, ctx
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
    return err, response, ctx
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
    return err, response, ctx
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
    return err, response, ctx
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

---@param err lsp.ResponseError
---@param response vim.lsp.CompletionResult
---@param ctx lsp.HandlerContext
---@return lsp.ResponseError
---@return vim.lsp.CompletionResult?
---@return lsp.HandlerContext
M[ms.textDocument_completion] = function(err, response, ctx)
  if not response then
    return err, response, ctx
  end
  ctx.params.textDocument.uri = ctx.params.otter.main_uri
  ctx.bufnr = ctx.params.otter.main_nr

  -- treat response as lsp.CompletionItem[] instead of lsp.CompletionList if isIncomplete is missing
  -- see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionParams response
  local is_completion_list = response.isIncomplete ~= nil
  ---@type lsp.CompletionItem[]
  local items = is_completion_list and response.items or response
  for _, item in ipairs(items) do
    if item.data ~= nil and item.data.uri ~= nil then
      item.data.uri = ctx.params.otter.main_uri
    end
    -- not needed for now:
    -- item.position = modify_position(item.position, ctx.params.otter.main_nr)
  end
  return err, response, ctx
end

M[ms.completionItem_resolve] = function(err, response, ctx)
  if not response then
    return err, response, ctx
  end
  if ctx.params.data ~= nil then
    ctx.params.data.uri = ctx.params.otter.main_uri
  end
  ctx.params.textDocument.uri = ctx.params.otter.main_uri
  ctx.bufnr = ctx.params.otter.main_nr

  if response.data ~= nil and response.data.uri ~= nil then
    response.data.uri = ctx.params.otter.main_uri
  end

  return err, response, ctx
end

return M
