local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

---@param plugin string
function M.load(plugin)
  local name = plugin:match(".*/(.*)")
  local package_root = M.root(".tests/site/pack/deps/start/")
  if not vim.uv.fs_stat(package_root .. name) then
    print("Installing " .. plugin)
    vim.fn.mkdir(package_root, "p")
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/" .. plugin .. ".git",
      package_root .. "/" .. name,
    })
  end
end

--- Install treesitter parsers needed for tests
function M.ensure_parsers()
  local parsers = {
    "markdown",
    "markdown_inline",
    "lua",
    "python",
    "r",
    "javascript",
    "html",
    "css",
    "org",
    "norg",
  }

  -- Check which parsers need to be installed
  local to_install = {}
  for _, parser in ipairs(parsers) do
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

  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(M.root())
  vim.opt.packpath = { M.root(".tests/site") }
  M.load("nvim-lua/plenary.nvim")
  M.load("nvim-treesitter/nvim-treesitter")
  vim.env.XDG_CONFIG_HOME = M.root(".tests/config")
  vim.env.XDG_DATA_HOME = M.root(".tests/data")
  vim.env.XDG_STATE_HOME = M.root(".tests/state")
  vim.env.XDG_CACHE_HOME = M.root(".tests/cache")

  -- Register markdown parser for quarto and rmd filetypes
  -- (normally done by quarto-nvim plugin)
  vim.treesitter.language.register("markdown", { "quarto", "rmd" })

  -- Ensure treesitter parsers are installed
  M.ensure_parsers()
end

M.setup()
