local api = vim.api
local keeper = require("otter.keeper")

M = {}
M.setup = function(main_nr)
  ---@type integer[]
  local nss = {}
  for lang, bufnr in pairs(keeper.rafts[main_nr].buffers) do
    local ns = api.nvim_create_namespace("otter-lang-" .. lang)
    nss[bufnr] = ns
  end
  keeper.rafts[main_nr].diagnostics_namespaces = nss

  local sync_diagnostics = function(args)
    if vim.tbl_contains(vim.tbl_values(keeper.rafts[main_nr].buffers), args.buf) then
      vim.diagnostic.reset(nss[args.buf], main_nr)
      local diags = args.data.diagnostics
      if diags then
        if OtterConfig.handle_leading_whitespace then
          for _, diag in ipairs(diags) do
            local offset = keeper.get_leading_offset(diag.lnum, main_nr)
            diag.col = diag.col + offset
            diag.end_col = diag.end_col + offset
          end
        end
        vim.diagnostic.set(nss[args.buf], main_nr, diags, {})
      end
    end
  end

  local group = api.nvim_create_augroup("OtterDiagnostics" .. main_nr, {})
  api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = sync_diagnostics,
  })
  keeper.rafts[main_nr].diagnostics_group = group

  api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = main_nr,
    group = group,
    callback = function()
      api.nvim_del_augroup_by_id(group)
    end,
  })

  api.nvim_create_autocmd(OtterConfig.lsp.diagnostic_update_events, {
    buffer = main_nr,
    group = group,
    callback = function(_)
      keeper.sync_raft(main_nr)
    end,
  })
end

return M
