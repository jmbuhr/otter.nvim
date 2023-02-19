
M = {}

M.config = {
  lsp = {
    hover = {
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
    }
  }
}

M.setup = function(opt)
  M.config = vim.tbl_deep_extend('force', M.config, opt or {})
end

return M

