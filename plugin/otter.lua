vim.api.nvim_create_user_command("OtterActivate", require("otter").activate, {})
vim.api.nvim_create_user_command("OtterDeactivate", require("otter").deactivate, {})
vim.api.nvim_create_user_command("OtterExport", function(opts)
  require("otter").export(opts.bang == true)
end, { bang = true })
vim.api.nvim_create_user_command("OtterExportAs", function(opts)
  local force = opts.bang == true
  local lang = opts.fargs[1]
  local fname = opts.fargs[2]
  if not lang or not fname then
    vim.notify("Usage: OtterExportAs <lang> <fname>", vim.log.levels.ERROR)
    return
  end
  require("otter").export_otter_as(lang, fname, force)
end, {
  bang = true,
  nargs = "*",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local main_nr = vim.api.nvim_get_current_buf()
    local langs = require("otter.keeper").rafts[main_nr].languages
    return vim.fn.filter(langs, function(lang)
      return vim.startswith(lang, arg_lead)
    end)
  end,
})
