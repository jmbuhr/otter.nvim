local M = {}

local api = vim.api
local keeper = require 'otter.keeper'

M.activate = keeper.activate
M.sync_raft = keeper.sync_raft
M.send_request = keeper.send_request
M.export = keeper.export_raft
M.export_otter_as = keeper.export_otter_as


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
    vim.lsp.buf.hover
  )
end


M.debug = function()
  local main_nr = api.nvim_get_current_buf()
  M.send_request(main_nr, "textDocument/hover", function(response)
    return response
  end)
end

M.dev_setup = function()
  api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = { "*.md" },
    callback = function()
      M.activate({ 'r', 'python', 'lua' }, true)
      vim.api.nvim_buf_set_keymap(0, 'n', 'gd', ":lua require'otter'.ask_definition()<cr>", { silent = true })
      vim.api.nvim_buf_set_keymap(0, 'n', 'K', ":lua require'otter'.ask_hover()<cr>", { silent = true })
    end,
  })
end


return M
