local M = {}

local api = vim.api
local ts = vim.treesitter
local extensions = require("otter.tools.extensions")
local handlers = require("otter.tools.handlers")
local keeper = require("otter.keeper")
local path_to_otterpath = require("otter.tools.functions").path_to_otterpath
local config = require("otter.config")
local replace_header_div = require("otter.tools.functions").replace_header_div
local fn = require("otter.tools.functions")
local ms = vim.lsp.protocol.Methods

M.setup = function(opts)
  config.cfg = vim.tbl_deep_extend("force", config.cfg, opts or {})
end

M.sync_raft = keeper.sync_raft
M.send_request = keeper.send_request
M.export = keeper.export_raft
M.export_otter_as = keeper.export_otter_as

--- Activate the current buffer by adding and synchronizing
--- otter buffers.
---@param languages table|nil List of languages to activate. If nil, all available languages will be activated.
---@param completion boolean|nil Enable completion for otter buffers. Default: true
---@param diagnostics boolean|nil Enable diagnostics for otter buffers. Default: true
---@param tsquery string|nil Explicitly provide a treesitter query. If nil, the injections query for the current filetyepe will be used. See :h treesitter-language-injections.
M.activate = function(languages, completion, diagnostics, tsquery)
  languages = languages or vim.tbl_keys(require("otter.tools.extensions"))
  completion = completion ~= false
  diagnostics = diagnostics ~= false
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)
  local main_path = api.nvim_buf_get_name(main_nr)
  local parsername = vim.treesitter.language.get_lang(api.nvim_get_option_value("filetype", { buf = main_nr }))
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
  keeper._otters_attached[main_nr] = {}
  keeper._otters_attached[main_nr].languages = {}
  keeper._otters_attached[main_nr].buffers = {}
  keeper._otters_attached[main_nr].paths = {}
  keeper._otters_attached[main_nr].otter_nr_to_lang = {}
  keeper._otters_attached[main_nr].tsquery = tsquery
  keeper._otters_attached[main_nr].query = query
  keeper._otters_attached[main_nr].parser = ts.get_parser(main_nr, parsername)
  keeper._otters_attached[main_nr].code_chunks = nil
  keeper._otters_attached[main_nr].last_changetick = nil

  local all_code_chunks = keeper.extract_code_chunks(main_nr)
  local found_languages = {}
  for _, lang in ipairs(languages) do
    if all_code_chunks[lang] ~= nil then
      table.insert(found_languages, lang)
    end
  end
  languages = found_languages

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
      keeper._otters_attached[main_nr].buffers[lang] = otter_nr
      keeper._otters_attached[main_nr].paths[lang] = otter_path
      keeper._otters_attached[main_nr].otter_nr_to_lang[otter_nr] = lang
      table.insert(keeper._otters_attached[main_nr].languages, lang)

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

  keeper.sync_raft(main_nr)

  -- manually attach language server the corresponds to the filetype
  -- without setting the filetype
  -- to prevent other plugins we don't need in the otter buffers
  -- from automatically attaching when ft is set
  for _, lang in ipairs(keeper._otters_attached[main_nr].languages) do
    local otter_nr = keeper._otters_attached[main_nr].buffers[lang]

    if config.cfg.buffers.write_to_disk then
      -- and also write out once before lsps can complain
      local otter_path = keeper._otters_attached[main_nr].paths[lang]
      vim.print(otter_path)
      api.nvim_buf_call(otter_nr, function()
        vim.cmd("write! " .. otter_path)
      end)
    end

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

  if completion then
    require("otter.completion").setup_sources(main_nr)
  end

  if diagnostics then
    require("otter.diagnostics").setup(main_nr)
  end

  -- remove the need to use keybindings for otter ask_ functions
  -- by being our own lsp server-client combo
  local otterclient_id = vim.lsp.start({
    name = "otter-ls",
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    handlers = handlers,
    cmd = function(dispatchers)
      local members = {
        request = function(method, params, handler, notify_reply_callback)
          -- params are created when vim.lsp.buf.<method> is called
          -- and modified here to be used with the otter buffers
          --
          -- handler is a callback function that should be called with the result
          -- depending on the method it is either our custom handler
          -- (e.g. for retargeting got-to-definition results)
          -- or the default vim.lsp.handlers[method] handler
          -- TODO: since otter-ls has to bring (some of) its own handlers
          -- to handle redirects etc.
          -- those have preference over handlers configured by the user
          -- with vim.lsp.with()
          -- additional entry points for configuring the otter handlers should
          -- be provided eventually

          if method == ms.initialize then
            local initializeResult = {
              capabilities = {
                hoverProvider = true,
                definitionProvider = true,
                typeDefinitionProvider = true,
                renameProvider = true,
                rangeFormattingProvider = true,
                referencesProvider = true,
                documentSymbolProvider = true,
              },
              serverInfo = {
                name = "otter-ls",
                version = "2.0.0",
              },
            }
            -- default handler for initialize
            handler(nil, initializeResult)
            return
          end

          -- all methods need to know the current language and
          -- otter responsible for that language
          local lang, start_row, start_col, end_row, end_col = keeper.get_current_language_context(main_nr)
          if not fn.contains(keeper._otters_attached[main_nr].languages, lang) then
            return
          end
          local otter_nr = keeper._otters_attached[main_nr].buffers[lang]
          local otter_uri = vim.uri_from_bufnr(otter_nr)
          -- general modifications to params for all methods
          params.textDocument = {
            uri = otter_uri,
          }
          -- container to pass additional information to the handlers
          params.otter = {}
          params.otter.main_uri = main_uri

          if method == ms.textDocument_documentSymbol then
            params.uri = otter_uri
          elseif method == ms.textDocument_references then
            params.context = {
              includeDeclaration = true,
            }
          elseif method == ms.textDocument_rangeFormatting then
            params.textDocument = {
              uri = otter_uri,
            }
            params.range = {
              start = { line = start_row, character = start_col },
              ["end"] = { line = end_row, character = end_col },
            }
            assert(end_row)
            local line = vim.api.nvim_buf_get_lines(otter_nr, end_row, end_row + 1, false)[1]
            if line then
              params.range["end"].character = #line
            end
            keeper.modify_position(params, main_nr, true, true)
          end
          -- send the request to the otter buffer
          vim.lsp.buf_request(otter_nr, method, params, handler)
        end,
        notify = function(method, params) end,
        is_closing = function() end,
        terminate = function() end,
      }
      return members
    end,
    before_init = function(_, _) end,
    on_init = function(client, init_result) end,
    root_dir = config.cfg.lsp.root_dir(),
  })
end

---Deactivate the current buffer by removing otter buffers and clearing diagnostics
---@param completion boolean | nil
---@param diagnostics boolean | nil
M.deactivate = function(completion, diagnostics)
  completion = completion ~= false
  diagnostics = diagnostics ~= false

  local main_nr = api.nvim_get_current_buf()
  if keeper._otters_attached[main_nr] == nil then
    return
  end

  if diagnostics then
    for _, ns in pairs(keeper._otters_attached[main_nr].nss) do
      vim.diagnostic.reset(ns, main_nr)
    end
  end

  if completion then
    api.nvim_del_augroup_by_name("cmp_otter" .. main_nr)
  end

  for _, otter_bufnr in pairs(keeper._otters_attached[main_nr].buffers) do
    -- Avoid 'textlock' with schedule
    vim.schedule(function()
      api.nvim_buf_delete(otter_bufnr, { force = true })
    end)
  end

  keeper._otters_attached[main_nr] = nil
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
---@param fallback function|nil
M.ask_rename = function(fallback)
  vim.deprecate("otter.ask_rename", "vim.lsp.buf.rename", "2.0.0", "otter.nvim", true)
end

--- Reformat current otter context
---@param fallback function|nil
M.ask_format = function(fallback)
  vim.deprecate("otter.ask_format", "vim.lsp.buf.format", "2.0.0", "otter.nvim", true)
end

return M
