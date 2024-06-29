local M = {}

local default_config = {
  lsp = {
    diagnostic_update_events = { "BufWritePost" },
    root_dir = require("lspconfig").util.root_pattern({ ".git", "_quarto.yml", "package.json" }),
  },
  buffers = {
    -- if set to true, the filetype of the otterbuffers will be set.
    -- otherwise only the autocommand of lspconfig that attaches
    -- the language server will be executed without setting the filetype
    set_filetype = false,
    write_to_disk = false,
  },
  strip_wrapping_quote_characters = { "'", '"', "`" },
  handle_leading_whitespace = true,
}

M.cfg = default_config

return M
