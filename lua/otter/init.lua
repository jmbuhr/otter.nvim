local M = {}

local api = vim.api
local ts = vim.treesitter

local config = require("otter.config")
local extensions = require("otter.tools.extensions")
local keeper = require("otter.keeper")
local otterls = require("otter.lsp")

local path_to_otterpath = require("otter.tools.functions").path_to_otterpath

M.setup = function(opts)
  if M.did_setup then
    return vim.notify("[otter] otter.nvim is already setup", vim.log.levels.ERROR)
  end
  M.did_setup = true

  if vim.fn.has("nvim-0.10.0") ~= 1 then
    return vim.notify("[otter] otter.nvim requires Neovim >= 0.10.0", vim.log.levels.ERROR)
  end

  config.cfg = vim.tbl_deep_extend("force", config.cfg, opts or {})

  extensions = vim.tbl_deep_extend("force", extensions, config.cfg.extensions or {})
end

-- expose some functions from the otter keeper directly
M.sync_raft = keeper.sync_raft
M.export = keeper.export_raft
M.export_otter_as = keeper.export_otter_as

--- Activate the current buffer by adding and synchronizing
--- otter buffers.
---@param languages string[]? List of languages to activate. If nil, all available languages will be activated.
---@param completion boolean? Enable completion for otter buffers. Default: true
---@param diagnostics boolean? Enable diagnostics for otter buffers. Default: true
---@param tsquery string? Explicitly provide a treesitter query. If nil, the injections query for the current filetyepe will be used. See :h treesitter-language-injections.
M.activate = function(languages, completion, diagnostics, tsquery)
  languages = languages or vim.tbl_keys(require("otter.tools.extensions"))
  completion = completion ~= false
  diagnostics = diagnostics ~= false
  local main_nr = api.nvim_get_current_buf()
  local main_path = api.nvim_buf_get_name(main_nr)
  local main_lang = api.nvim_get_option_value("filetype", { buf = main_nr })
  local parsername = vim.treesitter.language.get_lang(main_lang)
  if not parsername then
    vim.notify_once("[otter] No treesitter parser found for current buffer. Can't activate.", vim.log.levels.WARN, {})
    return
  end
  local query
  if tsquery ~= nil then
    query = ts.query.parse(parsername, tsquery)
  else
    query = ts.query.get(parsername, "injections")
  end
  if query == nil then
    vim.notify_once(
      "[otter] No explicit query provided and no injections found for current buffer. Can't activate.",
      vim.log.levels.WARN,
      {}
    )
    return
  end
  local parser = ts.get_parser(main_nr, parsername)
  if parser == nil then
    vim.notify_once("[otter] No parser found for current buffer. Can't activate.", vim.log.levels.WARN, {})
    return
  end
  keeper.rafts[main_nr] = {
    languages = {},
    buffers = {},
    paths = {},
    otter_nr_to_lang = {},
    tsquery = tsquery,
    query = query,
    parser = parser,
    code_chunks = {},
    last_changetick = nil,
    otterls = {
      client_id = nil,
    },
    diagnostics_namespaces = {},
    diagnostics_group = nil,
  }

  local all_code_chunks = keeper.extract_code_chunks(main_nr)

  ---@type string[]
  local found_languages = {}
  for _, lang in ipairs(languages) do
    if all_code_chunks[lang] ~= nil and lang ~= main_lang then
      table.insert(found_languages, lang)
    end
  end
  languages = found_languages
  if #languages == 0 then
    if config.cfg.verbose and config.cfg.verbose.no_code_found then
      vim.notify_once("[otter] No code chunks found. Not activating. You can activate after having added code chunks with require'otter'.activate(). You can turn of this message by setting the option verbose.no_code_found to false", vim.log.levels.INFO, {})
    end
    return
  end

  -- create otter buffers
  for _, lang in ipairs(languages) do
    if not extensions[lang] then
      vim.notify(
        ("[otter] %s is an unknown language. Please open an issue/PR to get it added"):format(lang),
        vim.log.levels.ERROR
      )
      goto continue
    end
    local extension = "." .. extensions[lang]
    if extension ~= nil then
      local otter_path = path_to_otterpath(main_path, extension)
      local otter_uri = "file://" .. otter_path
      local otter_nr = vim.uri_to_bufnr(otter_uri)
      api.nvim_buf_set_name(otter_nr, otter_path)
      api.nvim_set_option_value("swapfile", false, { buf = otter_nr })
      keeper.rafts[main_nr].buffers[lang] = otter_nr
      keeper.rafts[main_nr].paths[lang] = otter_path
      keeper.rafts[main_nr].otter_nr_to_lang[otter_nr] = lang
      table.insert(keeper.rafts[main_nr].languages, lang)

      if config.cfg.buffers.write_to_disk then
        -- remove otter buffer when main buffer is closed
        api.nvim_create_autocmd({ "QuitPre", "BufDelete" }, {
          buffer = main_nr,
          group = api.nvim_create_augroup("OtterAutoclose" .. otter_nr, {}),
          callback = function(_, _)
            if api.nvim_buf_is_loaded(otter_nr) then
              api.nvim_buf_delete(otter_nr, { force = true })
              vim.fn.delete(otter_path)
            end
          end,
        })
        -- write to disk when main buffer is written
        api.nvim_create_autocmd("BufWritePost", {
          buffer = main_nr,
          group = api.nvim_create_augroup("OtterAutowrite" .. otter_nr, {}),
          callback = function(_, _)
            if api.nvim_buf_is_loaded(otter_nr) then
              api.nvim_buf_call(otter_nr, function()
                vim.cmd("write! " .. otter_path)
              end)
            end
          end,
        })
      else
        api.nvim_set_option_value("buftype", "nowrite", { buf = otter_nr })
      end
    end
    ::continue::
  end

  -- this has to happen again after the
  -- otter buffers got their own lsps
  -- to really make sure the clients are
  -- attached to their otter buffers
  keeper.sync_raft(main_nr)

  -- manually attach language server that corresponds to the filetype
  -- without setting the filetype
  -- to prevent other plugins we don't need in the otter buffers
  -- from automatically attaching when ft is set
  for _, lang in ipairs(keeper.rafts[main_nr].languages) do
    local otter_nr = keeper.rafts[main_nr].buffers[lang]

    if config.cfg.buffers.write_to_disk then
      -- and also write out once before lsps can complain
      local otter_path = keeper.rafts[main_nr].paths[lang]
      api.nvim_buf_call(otter_nr, function()
        vim.cmd("write! " .. otter_path)
      end)
    end

    -- or if requested set the filetype
    if config.cfg.buffers.set_filetype then
      api.nvim_set_option_value("filetype", lang, { buf = otter_nr })
    else
      local autocommands = api.nvim_get_autocmds({ group = "lspconfig", pattern = lang })
      for _, command in ipairs(autocommands) do
        local opt = { buf = otter_nr }
        command.callback(opt)
      end
    end
  end

  -- see above.
  -- needs to happen here again
  keeper.sync_raft(main_nr)

  if diagnostics then
    require("otter.diagnostics").setup(main_nr)
  end

  -- check that we don't already have otter-ls running
  -- for main buffer
  local clients = vim.lsp.get_clients()
  for _, client in pairs(clients) do
    if client.name == "otter-ls" .. "[" .. main_nr .. "]" then
      if vim.lsp.buf_is_attached(main_nr, client.id) then
        -- already running otter-ls and attached to
        -- this buffer
        return
      else
        -- already running otter-ls but detached
        -- just re-attach it
        vim.lsp.buf_attach_client(main_nr, client.id)
        keeper.rafts[main_nr].otterls.client_id = client.id
        return
      end
    end
  end

  -- remove the need to use keybindings for otter ask_ functions
  -- by being our own lsp server-client combo
  local otterclient_id = otterls.start(main_nr, completion)
  if otterclient_id ~= nil then
    keeper.rafts[main_nr].otterls.client_id = otterclient_id
  else
    vim.notify_once("[otter] activation of otter-ls failed", vim.log.levels.WARN, {})
  end


  -- debugging
  if config.cfg.debug == true then
    -- listen to lsp requests and notifications
    vim.api.nvim_create_autocmd("LspNotify", {
      ---@param _ {buf: number, data: {client_id: number, method: string, params: any}}
      callback = function(_)
      end,
    })

    vim.api.nvim_create_autocmd("LspRequest", {
      callback = function(args)
        local bufnr = args.buf
        local client_id = args.data.client_id
        local method = args.data.method
        local request = args.data.request
        vim.print(bufnr .. "[" .. client_id .. "]" .. ": " .. method)
        vim.print(request)
      end,
    })
  end
end


---Deactivate the current buffer by removing otter buffers and clearing diagnostics
---@param completion boolean | nil
---@param diagnostics boolean | nil
M.deactivate = function(completion, diagnostics)
  completion = completion ~= false
  diagnostics = diagnostics ~= false

  local main_nr = api.nvim_get_current_buf()
  if keeper.rafts[main_nr] == nil then
    return
  end

  if diagnostics then
    for _, ns in pairs(keeper.rafts[main_nr].diagnostics_namespaces) do
      vim.diagnostic.reset(ns, main_nr)
    end
    -- remove diagnostics autocommands
    local id = keeper.rafts[main_nr].diagnostics_group
    if id ~= nil then
      vim.api.nvim_del_augroup_by_id(id)
    end
  end

  -- stop otter-ls
  local id = keeper.rafts[main_nr].otterls.client_id
  if id ~= nil then
    -- since our server is just a function
    -- we don't need it do anything special
    -- on exit
    -- but how to we actually stop it?
    vim.lsp.stop_client(id, true)
    -- it's still running

    -- at least detach it
    vim.lsp.buf_detach_client(main_nr, id)

    keeper.rafts[main_nr].otterls.client_id = nil
  end

  for _, otter_bufnr in pairs(keeper.rafts[main_nr].buffers) do
    -- Avoid 'textlock' with schedule
    vim.schedule(function()
      api.nvim_buf_delete(otter_bufnr, { force = true })
    end)
  end

  keeper.rafts[main_nr] = nil
end

M.ask_definition = function()
  vim.deprecate("otter.ask_definition", "vim.lsp.buf.definition", "2.0.0", "otter.nvim", true)
end

M.ask_type_definition = function()
  vim.deprecate("otter.ask_type_definition", "vim.lsp.buf.type_definition", "2.0.0", "otter.nvim", true)
end

M.ask_hover = function()
  vim.deprecate("otter.ask_hover", "vim.lsp.buf.hover", "2.0.0", "otter.nvim", true)
end

M.ask_references = function()
  vim.deprecate("otter.ask_references", "vim.lsp.buf.references", "2.0.0", "otter.nvim", true)
end

--- Open list of symbols of the current document
M.ask_document_symbols = function()
  vim.deprecate("otter.ask_document_symbols", "vim.lsp.buf.document_symbol", "2.0.0", "otter.nvim", true)
end

--- Rename symbol under cursor
M.ask_rename = function()
  vim.deprecate("otter.ask_rename", "vim.lsp.buf.rename", "2.0.0", "otter.nvim", true)
end

--- Reformat current otter context
M.ask_format = function()
  vim.deprecate("otter.ask_format", "vim.lsp.buf.format", "2.0.0", "otter.nvim", true)
end

return M
