local M = {}

M.setup = function(_)
  vim.deprecate("otter.config.setup", "otter.setup or lazy.nvim opts = {...}", "v0.18.0", "otter.nvim", false)
end

return M
