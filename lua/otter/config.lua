local M = {}

local default_config = {
  lsp = {
    diagnostic_update_events = { "BufWritePost" },
    root_dir = function(_, bufnr)
      return vim.fs.root(bufnr or 0, {
        ".git",
        "_quarto.yml",
        "package.json",
      }) or vim.fn.getcwd(0)
    end,
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
  debug = false,
  verbose = { -- set to false to disable all verbose messages
    no_code_found = true -- warn if otter.activate is called, but no injected code was found
  },
}

M.cfg = default_config

return M
