-- custom handlers for otter-ls where the default handlers are not sufficient
-- docs: https://microsoft.github.io/language-server-protocol/specifications/specification-current/
local fn = require("otter.tools.functions")
local ms = vim.lsp.protocol.Methods

local M = {}

--- see e.g.
--- vim.lsp.handlers.hover(_, result, ctx, config)
---@param err lsp.ResponseError?
---@param response lsp.Hover
---@param ctx lsp.HandlerContext
---@return integer? bufnr of the floating window
---@return integer? winnr of the floating window
M[ms.textDocument_hover] = function(err, response, ctx, config)
  if not response then
    return
  end

  -- pretend the response is coming from the main buffer
  ctx.params.textDocument.uri = ctx.params.otter.main_uri

  vim.lsp.handlers[ms.textDocument_hover](err, response, ctx, config)
end

M[ms.textDocument_definition] = function(err, response, ctx)
  if not response then
    return
  end
  if #response == 0 then
    if response.uri ~= nil then
      if fn.is_otterpath(response.uri) then
        response.uri = ctx.params.otter.main_uri
      end
    end
    if response.targetUri ~= nil then
      if fn.is_otterpath(response.targetUri) then
        response.targetUri = ctx.params.otter.main_uri
      end
    end
  else
    for _, resp in ipairs(response) do
      if resp.uri ~= nil then
        if fn.is_otterpath(resp.uri) then
          resp.uri = ctx.params.otter.main_uri
        end
      end
      if resp.targetUri ~= nil then
        if fn.is_otterpath(resp.targetUri) then
          resp.targetUri = ctx.params.otter.main_uri
        end
      end
    end
  end
  vim.lsp.handlers[ms.textDocument_definition](err, response, ctx)
end

M[ms.textDocument_documentSymbol] = function(err, response, ctx, conf)
  conf = conf or {}
  if not response then
    return
  end

  local function redirect(res)
    if not res.location or not res.location.uri then
      return res
    end
    local uri = res.location.uri
    if fn.is_otterpath(uri) then
      res.location.uri = ctx.params.otter.main_uri
    end
    return res
  end
  if #response == 0 then
    response = redirect(response)
  else
    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect(res))
    end
    response = modified_response
  end

  ctx.params.textDocument.uri = fn.otterpath_to_path(ctx.params.textDocument.uri)
  vim.lsp.handlers[ms.textDocument_documentSymbol](err, response, ctx, conf)
end

M[ms.textDocument_typeDefinition] = function(err, response, ctx, conf)
  if not response then
    return
  end
  local function redirect_definition(res)
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
    return res
  end
  if #response == 0 then
    response = redirect_definition(response)
  else
    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect_definition(res))
    end
    response = modified_response
  end
  vim.lsp.handlers[ms.textDocument_typeDefinition](err, response, ctx, conf)
end

M[ms.textDocument_rename] = function(err, response, ctx, conf)
  if not response then
    return
  end
  local function redirect(res)
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
      return res
    end
  end
  if #response == 0 then
    response = redirect(response)
  else
    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect(res))
    end
    response = modified_response
  end
  vim.lsp.handlers[ms.textDocument_rename](err, response, ctx, conf)
end

M[ms.textDocument_references] = function(err, response, ctx, conf)
  if not response then
    return
  end
  local function redirect(res)
    local uri = res.uri
    if not res.uri then
      return res
    end
    if fn.is_otterpath(uri) then
      res.uri = ctx.params.otter.main_uri
    end
    return res
  end
  if #response == 0 then
    response = redirect(response)
  else
    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect(res))
    end
    response = modified_response
  end
  -- change the ctx after the otter buffer has responded
  ctx.params.textDocument.uri = fn.otterpath_to_path(ctx.params.textDocument.uri)
  vim.lsp.handlers[ms.textDocument_references](err, response, ctx, conf)
end

M[ms.textDocument_completion] = function(err, response, ctx, conf)
  -- this handler doesn't actually get called
  -- but it still works.
  -- I assume nvim-cmp and nvims omnifunc handle the response directly
  vim.lsp.handlers[ms.textDocument_completion](err, response, ctx, conf)
end

M[ms.completionItem_resolve] = function(err, response, ctx, conf)
  -- this handler doesn't actually get called
  -- but it still works.
  -- I assume nvim-cmp and nvims omnifunc handle the response directly
  vim.lsp.handlers[ms.completionItem_resolve](err, response, ctx, conf)
end

return M
