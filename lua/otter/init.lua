M = {}

local api = vim.api

local keeper = require 'otter.keeper'

M.activate = keeper.activate
M.sync_raft = keeper.sync_raft
M.send_request = keeper.send_request


M.ask_definition = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)
  M.send_request(main_nr, "textDocument/definition", function(response)
    local modified_response = {}
    for _,res in ipairs(response) do
      if res.uri ~= nil then
        if require'otter.tools.functions'.is_otterpath(res.uri) then
            res.uri = main_uri
        end
        table.insert(modified_response, res)
      end
    return modified_response
    end
    end
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
