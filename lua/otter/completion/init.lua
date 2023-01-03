local source = require 'otter.completion.source'

local M = {}

---Registered client and source mapping.
M.cmp_client_source_map = {}
M.allowed_clients = {}

---Setup cmp-nvim-lsp source.
M.setup_source = function(main_nr, otter_nr)
  local callback = function()
    M.cmp_on_insert_enter(main_nr, otter_nr)
  end
  vim.api.nvim_create_autocmd('InsertEnter', {
    buffer = main_nr,
    group = vim.api.nvim_create_augroup('cmp_quarto' .. otter_nr, { clear = true }),
    callback = callback
  })
end

---Refresh sources on InsertEnter.
-- adds a source for the otter buffer
M.cmp_on_insert_enter = function(main_nr, otter_nr)
  local cmp = require('cmp')

  -- register all active clients.
  for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = otter_nr })) do
    M.allowed_clients[client.id] = client
    if not M.cmp_client_source_map[client.id] then
      local s = source.new(client, main_nr, otter_nr, require 'otter.keeper'.sync_this_raft)
      if s:is_available() then
        M.cmp_client_source_map[s.client.id] = cmp.register_source('otter', s)
      end
    end
  end

  -- unregister stopped/detached clients.
  for client_id, source_id in pairs(M.cmp_client_source_map) do
    if not M.allowed_clients[client_id] or M.allowed_clients[client_id]:is_stopped() then
      cmp.unregister_source(source_id)
      M.cmp_client_source_map[client_id] = nil
    end
  end


end


return M
