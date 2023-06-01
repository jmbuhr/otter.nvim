local ts = vim.treesitter
local tsq = require 'nvim-treesitter.query'
local get_current_language_context = require 'otter.tools.functions'.get_current_language_context

local source = {}

source.new = function(client, main_nr, otter_nr, updater, queries)
  local self = setmetatable({}, { __index = source })
  self.client = client
  self.otter_nr = otter_nr
  self.otter_ft = vim.api.nvim_buf_get_option(otter_nr, 'filetype')
  self.main_nr = main_nr
  self.main_ft = vim.api.nvim_buf_get_option(main_nr, 'filetype')
  self.otter_parsername = vim.treesitter.language.get_lang(self.otter_ft)
  self.main_parsername = vim.treesitter.language.get_lang(self.main_ft)
  self.main_tsquery = queries[self.main_ft]
  self.context = require 'otter.tools.contexts'[self.main_ft]
  self.id = otter_nr
  self.request_ids = {}
  self.updater = updater
  return self
end

---Determine if the cursor is in a code context for the otter language.
---associated with this source.
---@return boolean
source.is_otter_lang_context = function(self)
  return get_current_language_context(self.main_nr) == self.otter_ft
end


---Get debug name.
---@return string
source.get_debug_name = function(self)
  return table.concat({ 'quarto', self.client.name }, ':')
end

---Return the source is available.
---@return boolean
source.is_available = function(self)
  -- client is stopped.
  if self.client.is_stopped() then
    return false
  end

  -- don't filter clients from other buffers
  -- client is not attached to current buffer.

  -- disable completion outside of language context
  if not self:is_otter_lang_context() then
    return false
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider' }) then
    return false
  end
  return true;
end

---Get LSP's PositionEncodingKind.
---@return lsp.PositionEncodingKind
source.get_position_encoding_kind = function(self)
  return self:_get(self.client.server_capabilities, { 'positionEncoding' }) or self.client.offset_encoding or 'utf-16'
end

---Get triggerCharacters.
---@return string[]
source.get_trigger_characters = function(self)
  return self:_get(self.client.server_capabilities, { 'completionProvider', 'triggerCharacters' }) or {}
end

---Get get_keyword_pattern.
---@param params cmp.SourceApiParams
---@return string
source.get_keyword_pattern = function(self, params)
  return (params.option or {})[self.client.name] or require('cmp').get_config().completion.keyword_pattern
end

---Resolve LSP CompletionItem.
---@param params cmp.SourceCompletionApiParams
---@param callback function
source.complete = function(self, params, callback)
  local otter_nrs = self.updater()
  local win = vim.api.nvim_get_current_win()
  local lsp_params = vim.lsp.util.make_position_params(win, self.client.offset_encoding)
  lsp_params.textDocument = {
    uri = vim.uri_from_bufnr(self.otter_nr)
  }
  lsp_params.context = {}
  lsp_params.context.triggerKind = params.completion_context.triggerKind
  lsp_params.context.triggerCharacter = params.completion_context.triggerCharacter
  self:_request('textDocument/completion', lsp_params, function(_, response)
    callback(response)
  end)
end

---Resolve LSP CompletionItem.
---@param completion_item lsp.CompletionItem
---@param callback function
source.resolve = function(self, completion_item, callback)
  -- client is stopped.
  if self.client.is_stopped() then
    return callback()
  end

  -- client has no completion capability.
  if not self:_get(self.client.server_capabilities, { 'completionProvider', 'resolveProvider' }) then
    return callback()
  end

  self:_request('completionItem/resolve', completion_item, function(_, response)
    callback(response or completion_item)
  end)
end

---Execute LSP CompletionItem.
---@param completion_item lsp.CompletionItem
---@param callback function
source.execute = function(self, completion_item, callback)
  -- client is stopped.
  if self.client.is_stopped() then
    return callback()
  end

  -- completion_item has no command.
  if not completion_item.command then
    return callback()
  end

  self:_request('workspace/executeCommand', completion_item.command, function(_, _)
    callback()
  end)
end

---Get object path.
---@param root table
---@param paths string[]
---@return any
source._get = function(_, root, paths)
  local c = root
  for _, path in ipairs(paths) do
    c = c[path]
    if not c then
      return nil
    end
  end
  return c
end

---Send request to nvim-lsp servers with backward compatibility.
---@param method string
---@param params table
---@param callback function
source._request = function(self, method, params, callback)
  if self.request_ids[method] ~= nil then
    self.client.cancel_request(self.request_ids[method])
    self.request_ids[method] = nil
  end
  local _, request_id
  _, request_id = self.client.request(method, params, function(arg1, arg2, arg3)
    if self.request_ids[method] ~= request_id then
      return
    end
    self.request_ids[method] = nil

    -- Text changed, retry
    if arg1 and arg1.code == -32801 then
      self:_request(method, params, callback)
      return
    end

    if method == arg2 then
      callback(arg1, arg3) -- old signature
    else
      callback(arg1, arg2) -- new signature
    end
  end)
  self.request_ids[method] = request_id
end

return source
