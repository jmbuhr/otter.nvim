local M = {}

-- Guard to prevent multiple setup calls in the same nvim session
local setup_done = false

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
  -- Check if parsers were already installed by a previous nvim instance.
  -- This prevents race conditions when plenary runs tests in parallel,
  -- where multiple nvim processes would try to install parsers concurrently.
  local marker_file = M.root(".tests/parsers_installed")
  if vim.uv.fs_stat(marker_file) then
    return
  end

  local parsers_to_install = {
    "markdown",
    "markdown_inline",
    "lua",
    "python",
    "r",
    "javascript",
    "typescript",
    "html",
    "css",
    "rust",
    "nix",
    "vim",
    -- norg parser is provided by tree-sitter-norg plugin, not nvim-treesitter
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
    print("[test-init] Installing treesitter parsers: " .. table.concat(to_install, ", "))
    -- Log where nvim-treesitter thinks it's installing
    local ts_config = require('nvim-treesitter.config')
    print("[test-init] TS will install to: " .. ts_config.get_install_dir('parser'))
    print("[test-init] Calling nvim-treesitter.install()...")
    local install_result = require("nvim-treesitter").install(to_install)
    print("[test-init] Waiting for install to complete...")
    install_result:wait(300000)
    print("[test-init] Install wait() returned")
    -- Log the directory contents after install
    local install_dir = ts_config.get_install_dir('parser')
    local stat = vim.uv.fs_stat(install_dir)
    if stat then
      local handle = vim.uv.fs_scandir(install_dir)
      local files = {}
      if handle then
        while true do
          local name = vim.uv.fs_scandir_next(handle)
          if not name then break end
          table.insert(files, name)
        end
      end
      print("[test-init] After install, " .. install_dir .. " contains: " .. table.concat(files, ", "))
    else
      print("[test-init] After install, " .. install_dir .. " DOES NOT EXIST!")
    end
  else
    print("[test-init] No parsers to install, all already available")
  end

  -- Mark installation complete so parallel test workers skip this step
  local f = io.open(marker_file, "w")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S"))
    f:close()
  end
end

function M.setup()
  -- Prevent multiple setup calls in the same nvim session
  if setup_done then
    return
  end
  setup_done = true

  print("[test-init] Starting setup...")
  print("[test-init] M.root() = " .. M.root())
  print("[test-init] cwd = " .. vim.uv.cwd())
  print("[test-init] stdpath('data') BEFORE env = " .. vim.fn.stdpath('data'))
  print("[test-init] stdpath('cache') BEFORE env = " .. vim.fn.stdpath('cache'))

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
  M.load("nvim-treesitter/nvim-treesitter", "main")
  M.load("Saghen/blink.cmp")
  M.load("nvim-orgmode/orgmode")
  M.load("nvim-neorg/tree-sitter-norg")

  -- Load all plugins from the packpath (required for fresh CI installs)
  vim.cmd([[packloadall]])

  -- Register markdown parser for quarto and rmd filetypes
  -- (normally done by quarto-nvim plugin)
  vim.treesitter.language.register("markdown", { "quarto", "rmd" })

  require('orgmode').setup()

  -- Use explicit path for parser installation directory.
  -- We can't rely on stdpath('data') because XDG_DATA_HOME set via vim.env
  -- doesn't affect stdpath() - it's determined at nvim startup.
  local parser_install_dir = M.root(".tests/data/nvim/site")
  print("[test-init] parser_install_dir = " .. parser_install_dir)
  print("[test-init] stdpath('data') = " .. vim.fn.stdpath('data'))
  
  require'nvim-treesitter'.setup {
    install_dir = parser_install_dir
  }

  -- Log runtimepath after nvim-treesitter setup
  print("[test-init] runtimepath after TS setup = " .. vim.o.runtimepath)
  
  -- Check if parser directory exists and list contents
  local parser_dir = parser_install_dir .. "/parser"
  print("[test-init] parser_dir = " .. parser_dir)
  local stat = vim.uv.fs_stat(parser_dir)
  if stat then
    print("[test-init] parser_dir exists, type = " .. stat.type)
    local handle = vim.uv.fs_scandir(parser_dir)
    if handle then
      local files = {}
      while true do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then break end
        table.insert(files, name)
      end
      print("[test-init] parser files: " .. table.concat(files, ", "))
    end
  else
    print("[test-init] parser_dir DOES NOT EXIST!")
  end

  M.ensure_parsers()
  
  -- Check multiple possible parser locations
  print("[test-init] Checking possible parser locations...")
  local possible_locations = {
    parser_install_dir .. "/parser",
    vim.fn.stdpath('data') .. "/site/parser",
    vim.fn.stdpath('data') .. "/parser",
    M.root(".tests/site/parser"),
  }
  for _, loc in ipairs(possible_locations) do
    local loc_stat = vim.uv.fs_stat(loc)
    if loc_stat then
      local handle = vim.uv.fs_scandir(loc)
      local files = {}
      if handle then
        while true do
          local name = vim.uv.fs_scandir_next(handle)
          if not name then break end
          table.insert(files, name)
        end
      end
      print("[test-init] " .. loc .. " -> " .. #files .. " files: " .. table.concat(files, ", "))
    else
      print("[test-init] " .. loc .. " -> does not exist")
    end
  end
  
  -- Also check nvim-treesitter's actual config
  local ts_config = require('nvim-treesitter.config')
  print("[test-init] TS get_install_dir('parser') = " .. ts_config.get_install_dir('parser'))

  -- Test if markdown parser is available after setup
  local ok, result = pcall(vim.treesitter.language.inspect, "markdown")
  print("[test-init] markdown parser available: " .. tostring(ok))
  if not ok then
    print("[test-init] markdown parser error: " .. tostring(result))
  end

  print("[test-init] Setup complete")
end

M.setup()

return M
