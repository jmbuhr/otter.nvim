local api = vim.api
local config = require("otter.config")
local keeper = require("otter.keeper")

M = {}
M.setup = function(main_nr)
  ---@type integer[]
  keeper.rafts[main_nr].diagnostics_namespaces = {}
  for lang, bufnr in pairs(keeper.rafts[main_nr].buffers) do
    local ns = api.nvim_create_namespace("otter-lang-" .. lang)
    keeper.rafts[main_nr].diagnostics_namespaces[bufnr] = ns
  end

  local sync_diagnostics = function(args)
    local otter_nr = args.buf
    if not vim.tbl_contains(vim.tbl_values(keeper.rafts[main_nr].buffers), otter_nr) then
      -- diagnostics are not from an otter buffer
      return
    end
    vim.print(args.buf)
    vim.print(args.data.diagnostics)
    -- reset the diagnostics of the otter buffer in the main buffer
    vim.diagnostic.reset(keeper.rafts[main_nr].diagnostics_namespaces[otter_nr], main_nr)

    ---@type vim.Diagnostic[]
    local diags = args.data.diagnostics
    if config.cfg.handle_leading_whitespace then
      for _, diag in ipairs(diags) do
        local offset = keeper.get_leading_offset(diag.lnum, main_nr)
        diag.col = diag.col + offset
        diag.end_col = diag.end_col + offset
      end
    end
    vim.diagnostic.set(keeper.rafts[main_nr].diagnostics_namespaces[otter_nr], main_nr, diags, {})
  end

  local diagnostics_augroup = api.nvim_create_augroup("OtterDiagnostics" .. main_nr, {})
  keeper.rafts[main_nr].diagnostics_group = diagnostics_augroup

  api.nvim_create_autocmd("DiagnosticChanged", {
    group = diagnostics_augroup,
    callback = sync_diagnostics,
  })

  api.nvim_create_autocmd(config.cfg.lsp.diagnostic_update_events, {
    buffer = main_nr,
    group = diagnostics_augroup,
    callback = function(_)
      -- syncing the contents of the otter buffers will
      -- trigger the diagnostic update events afterwards
      keeper.sync_raft(main_nr)
    end,
  })
end

return M
