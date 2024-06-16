local M = {}

local default_config = {
  lsp = {
    hover = {
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    },
    diagnostic_update_events = { "BufWritePost" },
    hijack = true, -- hijack lsp requests and responses via lsp-events
  },
  buffers = {
    -- if set to true, the filetype of the otterbuffers will be set.
    -- otherwise only the autocommand of lspconfig that attaches
    -- the language server will be executed without setting the filetype
    set_filetype = false,
    write_to_disk = false,
  },
  strip_wrapping_quote_characters = { "'", '"', "`" },
  handle_leading_whitespace = false,
}

M.cfg = default_config

return M
