local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

---@param plugin string
---@param ref string|nil Git ref (branch or tag) to checkout
function M.load(plugin, ref)
  local name = plugin:match(".*/(.*)")
  local package_root = M.root(".tests/site/pack/deps/start/")
  if not vim.uv.fs_stat(package_root .. name) then
    print("Installing " .. plugin .. (ref and (" @ " .. ref) or ""))
    vim.fn.mkdir(package_root, "p")
    local clone_cmd = {
      "git",
      "clone",
      "--depth=1",
    }
    if ref then
      table.insert(clone_cmd, "--branch")
      table.insert(clone_cmd, ref)
    end
    table.insert(clone_cmd, "https://github.com/" .. plugin .. ".git")
    table.insert(clone_cmd, package_root .. "/" .. name)
    vim.fn.system(clone_cmd)
  end
end

--- Install treesitter parsers needed for tests
function M.ensure_parsers()
  local parsers_to_install = {
    "markdown",
    "markdown_inline",
    "lua",
    "python",
    "r",
    "javascript",
    "html",
    "css",
  }

  -- Check which parsers need to be installed
  local to_install = {}
  for _, parser in ipairs(parsers_to_install) do
    local ok = pcall(vim.treesitter.language.inspect, parser)
    if not ok then
      table.insert(to_install, parser)
    end
  end

  if #to_install > 0 then
    print("Installing treesitter parsers: " .. table.concat(to_install, ", "))
    require("nvim-treesitter.install").ensure_installed_sync(to_install)
  end
end

function M.setup()
  -- Disable netrw before it loads (avoids E919 error about missing packpath)
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  -- Disable swap files for tests to avoid conflicts in CI
  vim.opt.swapfile = false

  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(M.root())
  vim.opt.packpath = { M.root(".tests/site") }

  -- Set XDG paths BEFORE loading plugins so stdpath() returns correct values
  vim.env.XDG_CONFIG_HOME = M.root(".tests/config")
  vim.env.XDG_DATA_HOME = M.root(".tests/data")
  vim.env.XDG_STATE_HOME = M.root(".tests/state")
  vim.env.XDG_CACHE_HOME = M.root(".tests/cache")

  M.load("nvim-lua/plenary.nvim")
  -- Pin nvim-treesitter to v0.9.3 for stable API (v0.10+ has breaking changes)
  M.load("nvim-treesitter/nvim-treesitter", "v0.9.3")
  M.load("Saghen/blink.cmp")
  M.load("nvim-orgmode/orgmode")

  -- Load all plugins from the packpath (required for fresh CI installs)
  vim.cmd([[packloadall]])

  -- Register markdown parser for quarto and rmd filetypes
  -- (normally done by quarto-nvim plugin)
  vim.treesitter.language.register("markdown", { "quarto", "rmd" })

  -- Ensure treesitter parsers are installed
  M.ensure_parsers()
  require('orgmode').setup()

end

M.setup()

return M
