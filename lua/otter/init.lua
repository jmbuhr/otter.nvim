local M = {}

local api = vim.api
local keeper = require 'otter.keeper'
local handlers = require 'otter.tools.handlers'
local config = require 'otter.config'.config
local tsq = require'nvim-treesitter.query'
local ts = vim.treesitter

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

  local lang = vim.api.nvim_buf_get_option(0, 'filetype')
  local parser = vim.treesitter.get_parser(0, lang)
  local query = tsq.get_query(lang, 'injections')
  local tree = parser:parse()
  local root = tree[1]:root()

  for id, node, metadata in query:iter_captures(root, 0) do
    local name = query.captures[id] -- name of the capture in the query
    -- typically useful info about the node:
    local type = node:type() -- type of the captured node
    local row1, col1, row2, col2 = node:range() -- range of the capture
    print(name)
    print(row1 .. ' - ' .. row2)
    print(ts.get_node_text(node, 0, metadata))
  end
  

  -- M.activate({ 'r', 'python', 'lua' }, true)
  -- vim.api.nvim_buf_set_keymap(0, 'n', 'gd', ":lua require'otter'.ask_definition()<cr>", { silent = true })
  -- vim.api.nvim_buf_set_keymap(0, 'n', 'K', ":lua require'otter'.ask_hover()<cr>", { silent = true })
  -- vim.api.nvim_buf_set_keymap(0, 'n', 'gr', ":lua require'otter'.ask_references()<cr>", { silent = true })
  -- vim.api.nvim_buf_set_keymap(0, 'n', '<leader>lR', ":lua require'otter'.ask_rename()<cr>", { silent = true })
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
    config.lsp.hover
  )
end


M.ask_references = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local uri = res.uri
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



M.ask_rename = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local changes = res.documentChanges
    local new_changes = {}
    for _, change in ipairs(changes) do
      local uri = change.textDocument.uri
      if require 'otter.tools.functions'.is_otterpath(uri) then
        change.textDocument.uri = main_uri
      end
      table.insert(new_changes, change)
    end
    res.documentChanges = new_changes
    return res
  end

  M.send_request(main_nr, "textDocument/rename",
    redirect,
    vim.lsp.buf.rename
  )
end


return M
