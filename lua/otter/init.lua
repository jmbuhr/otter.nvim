local M = {}

local api = vim.api
local keeper = require 'otter.keeper'
local handlers = require 'otter.tools.handlers'

local default_config = {
  lsp = {
    hover = {
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
    }
  }
}

M.config = default_config
M.setup = function(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

M.activate = keeper.activate
M.sync_raft = keeper.sync_raft
M.send_request = keeper.send_request
M.export = keeper.export_raft
M.export_otter_as = keeper.export_otter_as

M.debug = function()
  local main_nr = api.nvim_get_current_buf()
  M.send_request(main_nr, "textDocument/hover", function(response)
    return response
  end)
end

M.dev_setup = function()

  M.activate({ 'r', 'python', 'lua', 'html', 'css' }, true)
  vim.api.nvim_buf_set_keymap(0, 'n', 'gS', ":lua require'otter'.ask_document_symbols()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', 'gd', ":lua require'otter'.ask_definition()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', 'gD', ":lua require'otter'.ask_type_definition()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', 'K', ":lua require'otter'.ask_hover()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', 'gr', ":lua require'otter'.ask_references()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, 'n', '<leader>lR', ":lua require'otter'.ask_rename()<cr>", { silent = true })
end

-- example implementations to work with the send_request function
M.ask_definition = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect_definition(res)
    if res.uri ~= nil then
      if require 'otter.tools.functions'.is_otterpath(res.uri) then
        res.uri = main_uri
      end
    end
    if res.targetUri ~= nil then
      if require 'otter.tools.functions'.is_otterpath(res.targetUri) then
        res.targetUri = main_uri
      end
    end
    return res
  end

  M.send_request(main_nr, "textDocument/definition", function(response)
      if #response == 0 then
        return redirect_definition(response)
      end

      local modified_response = {}
      for _, res in ipairs(response) do
        table.insert(modified_response, redirect_definition(res))
      end
      return modified_response
    end,
    vim.lsp.buf.definition
  )
end

M.ask_type_definition = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect_definition(res)
    if res.uri ~= nil then
      if require 'otter.tools.functions'.is_otterpath(res.uri) then
        res.uri = main_uri
      end
    end
    if res.targetUri ~= nil then
      if require 'otter.tools.functions'.is_otterpath(res.targetUri) then
        res.targetUri = main_uri
      end
    end
    return res
  end

  M.send_request(main_nr, "textDocument/typeDefinition", function(response)
      if #response == 0 then
        return redirect_definition(response)
      end

      local modified_response = {}
      for _, res in ipairs(response) do
        table.insert(modified_response, redirect_definition(res))
      end
      return modified_response
    end,
    vim.lsp.buf.type_definition
  )
end


local function replace_header_div(response)
  response.contents = response.contents:gsub('<div class="container">', '')
  return response
end


-- See <https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/buf.lua>
M.ask_hover = function()
  local main_nr = api.nvim_get_current_buf()
  M.send_request(main_nr, "textDocument/hover", function(response)
      local ok, filtered_response = pcall(replace_header_div, response)
      if ok then
        return filtered_response
      else
        return response
      end
    end,
    vim.lsp.buf.hover,
    handlers.hover,
    M.config.lsp.hover
  )
end


M.ask_references = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local uri = res.uri
    if not res.uri then return end
    if require 'otter.tools.functions'.is_otterpath(uri) then
      res.uri = main_uri
    end
    return res
  end

  M.send_request(main_nr, "textDocument/references",
    redirect,
    vim.lsp.buf.references
  )
end


M.ask_document_symbols = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    if not res.location or not res.location.uri then return end
    local uri = res.location.uri
    if require 'otter.tools.functions'.is_otterpath(uri) then
      res.location.uri = main_uri
    end
    return res
  end

  M.send_request(main_nr, "textDocument/documentSymbol",
    redirect,
    vim.lsp.buf.document_symbol,
    handlers.document_symbol
  )
end



M.ask_rename = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local changes = res.changes
    local new_changes = {}
    for uri, change in pairs(changes) do
      if require 'otter.tools.functions'.is_otterpath(uri) then
        uri = main_uri
      end
      new_changes[uri]= change
    end
    res.changes = new_changes
    return res
  end

  M.send_request(main_nr, "textDocument/rename",
    redirect,
    vim.lsp.buf.rename
  )
end


return M
