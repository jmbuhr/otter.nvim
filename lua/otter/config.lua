local M = {}


---@class OtterConfig
local default_config = {
  lsp = {
    -- `:h events` that cause the diagnostics to update. Set to:
    -- { "BufWritePost", "InsertLeave", "TextChanged" } for less performant
    -- but more instant diagnostic updates
    diagnostic_update_events = { "BufWritePost" },
    -- function to find the root dir where the otter-ls is started
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
    set_filetype = true,
    -- write <path>.otter.<embedded language extension> files
    -- to disk on save of main buffer.
    -- usefule for some linters that require actual files.
    -- otter files are deleted on quit or main buffer close
    write_to_disk = false,
    -- a table of preambles for each language. The key is the language and the value is a table of strings that will be written to the otter buffer starting on the first line.
    preambles = {},
    -- a table of postambles for each language. The key is the language and the value is a table of strings that will be written to the end of the otter buffer.
    postambles = {},
    -- A table of patterns to ignore for each language. The key is the language and the value is a lua match pattern to ignore.
    -- lua patterns: https://www.lua.org/pil/20.2.html
    ignore_pattern = {
      -- ipython cell magic (lines starting with %) and shell commands (lines starting with !)
      python = "^(%s*[%%!].*)",
    },
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
    no_code_found = false -- warn if otter.activate is called, but no injected code was found
  },
}

M.cfg = default_config

return M
