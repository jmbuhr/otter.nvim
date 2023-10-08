local source = require 'otter.completion.source'
local keeper = require 'otter.keeper'
local cmp = require('cmp')

local M = {}

---Registered client and source mapping.
M.cmp_client_source_map = {}
M.allowed_clients = {}

---Setup nvim-cmp otter source.
M.setup_sources = function(main_nr, otters_attached)
  vim.notify("otter.completion.setup_source: " .. main_nr)

  local callback = function(opts)
    M.cmp_on_insert_enter(main_nr, opts)
  end
  vim.api.nvim_create_autocmd('InsertEnter', {
    -- buffer = main_nr,
    group = vim.api.nvim_create_augroup('cmp_otter' .. main_nr, { clear = true }),
    callback = callback
  })
end

---Refresh sources on InsertEnter.
-- adds a source for the otter buffer
M.cmp_on_insert_enter = function(main_nr, opts)
  vim.notify("cmp_on_insert_enter: " .. main_nr)

  if main_nr ~= vim.api.nvim_get_current_buf() then
    vim.notify("Unregister sources, not in main buffer")
    for client_id, source_id in pairs(M.cmp_client_source_map) do
      cmp.unregister_source(source_id)
    end
    M.cmp_client_source_map = {}
    M.allowed_clients = {}
    return
  end


  for lang, otter_nr in pairs(keeper._otters_attached[main_nr].buffers) do
    -- register all active clients.
    for _, client in ipairs(vim.lsp.get_active_clients({ bufnr = otter_nr })) do
      M.allowed_clients[client.id] = client
      if not M.cmp_client_source_map[client.id] then

        local updater = function ()
          keeper.sync_raft(main_nr, lang)
        end

        local s = source.new(client, main_nr, otter_nr, updater, keeper._otters_attached[main_nr].tsquery)
        if s:is_available() then
          M.cmp_client_source_map[s.client.id] = cmp.register_source('otter', s)
        end
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
