local M = {}


---@class OtterConfig
local default_config = {
  lsp = {
    -- event to trigger diagnostics update
    diagnostic_update_events = { "BufWritePost" },
    root_dir = function(_, bufnr)
      return vim.fs.root(bufnr or 0, {
        ".git",
        "_quarto.yml",
        "package.json",
      }) or vim.fn.getcwd(0)
    end,
  },
  -- options related to the otter buffers
  buffers = {
    -- if set to true, the filetype of the otterbuffers will be set.
    -- otherwise only the autocommand of lspconfig that attaches
    -- the language server will be executed without setting the filetype
    set_filetype = false,
    -- write otter buffers as temporary files to disk
    write_to_disk = false,
  },
  -- list of characters that should be stripped from the beginning and end of the code chunks
  strip_wrapping_quote_characters = { "'", '"', "`" },
  -- remove whitespace from the beginning of the code chunks when writing to the ottter buffers
  -- and calculate it back in when handling lsp requests
  handle_leading_whitespace = true,
  -- mapping of filetypes to extensions for those not already included in otter.tools.extensions
  -- e.g. ["bash"] = "sh"
  extensions = {
  },
  -- add event listeners for LSP events for debugging
  debug = false,
  verbose = { -- set to false to disable all verbose messages
    no_code_found = true -- warn if otter.activate is called, but no injected code was found
  },
}

M.cfg = default_config

return M
