local M = {}

local api = vim.api
local ts = vim.treesitter
local extensions = require("otter.tools.extensions")
local handlers = require("otter.tools.handlers")
local keeper = require("otter.keeper")
local path_to_otterpath = require("otter.tools.functions").path_to_otterpath
local config = require("otter.config")

M.setup = function(opts)
  config.cfg = vim.tbl_deep_extend("force", config.cfg, opts or {})
end

M.sync_raft = keeper.sync_raft
M.send_request = keeper.send_request
M.export = keeper.export_raft
M.export_otter_as = keeper.export_otter_as

M.debug = function()
  local main_nr = api.nvim_get_current_buf()
  M.send_request(main_nr, "textDocument/hover", function(response)
    return response
  end)
end

--- Activate otter for the current buffer and set up keymaps.
--- Only for development purposes
M.dev_setup = function()
  M.activate({ "r", "python", "lua", "html", "css" }, true)
  vim.api.nvim_buf_set_keymap(0, "n", "gS", ":lua require'otter'.ask_document_symbols()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "gd", ":lua require'otter'.ask_definition()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "gD", ":lua require'otter'.ask_type_definition()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "K", ":lua require'otter'.ask_hover()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "gr", ":lua require'otter'.ask_references()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>lR", ":lua require'otter'.ask_rename()<cr>", { silent = true })
  vim.api.nvim_buf_set_keymap(0, "n", "<leader>lf", ":lua require'otter'.ask_format()<cr>", { silent = true })
end

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
  local main_path = api.nvim_buf_get_name(main_nr)
  local parsername = vim.treesitter.language.get_lang(api.nvim_get_option_value("filetype", { buf = main_nr }))
  if not parsername then
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
        ("[Otter] %s is an unknown language. Please open an issue/PR to get it added"):format(lang),
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
    require("otter.completion").setup_sources(main_nr, keeper._otters_attached[main_nr])
  end

  if diagnostics then
    local nss = {}
    for lang, bufnr in pairs(keeper._otters_attached[main_nr].buffers) do
      local ns = api.nvim_create_namespace("otter-lang-" .. lang)
      nss[bufnr] = ns
    end
    keeper._otters_attached[main_nr].nss = nss

    local sync_diagnostics = function(_, _)
      M.sync_raft(main_nr)
      for bufnr, ns in pairs(nss) do
        local diags = vim.diagnostic.get(bufnr)
        vim.diagnostic.reset(ns, main_nr)
        if config.cfg.handle_leading_whitespace then
          for _, diag in ipairs(diags) do
            local offset = keeper.get_leading_offset(diag.lnum, main_nr)
            diag.col = diag.col + offset
            diag.end_col = diag.end_col + offset
          end
        end
        vim.diagnostic.set(ns, main_nr, diags, {})
      end
    end

    api.nvim_create_autocmd("BufWritePost", {
      buffer = main_nr,
      group = api.nvim_create_augroup("OtterDiagnostics" .. main_nr, {}),
      callback = sync_diagnostics,
    })
    sync_diagnostics(nil, nil)
  end
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

--- Got to definition of the symbol under the cursor
M.ask_definition = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect_definition(res)
    if res.uri ~= nil then
      if require("otter.tools.functions").is_otterpath(res.uri) then
        res.uri = main_uri
      end
    end
    if res.targetUri ~= nil then
      if require("otter.tools.functions").is_otterpath(res.targetUri) then
        res.targetUri = main_uri
      end
    end
    return res
  end

  M.send_request(main_nr, "textDocument/definition", function(response)
    if #response == 0 then
      return redirect_definition(response)
    end

    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect_definition(res))
    end
    return modified_response
  end, vim.lsp.buf.definition)
end

--- Got to type definition of the symbol under the cursor
M.ask_type_definition = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect_definition(res)
    if res.uri ~= nil then
      if require("otter.tools.functions").is_otterpath(res.uri) then
        res.uri = main_uri
      end
    end
    if res.targetUri ~= nil then
      if require("otter.tools.functions").is_otterpath(res.targetUri) then
        res.targetUri = main_uri
      end
    end
    return res
  end

  M.send_request(main_nr, "textDocument/typeDefinition", function(response)
    if #response == 0 then
      return redirect_definition(response)
    end

    local modified_response = {}
    for _, res in ipairs(response) do
      table.insert(modified_response, redirect_definition(res))
    end
    return modified_response
  end, vim.lsp.buf.type_definition)
end

local function replace_header_div(response)
  response.contents = response.contents:gsub('<div class="container">', "")
  -- response.contents = response.contents:gsub('``` R', '```r')
  return response
end

--- Open hover documentation of symbol under the cursor
-- See <https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/buf.lua>
M.ask_hover = function()
  local main_nr = api.nvim_get_current_buf()
  M.send_request(main_nr, "textDocument/hover", function(response)
    local ok, filtered_response = pcall(replace_header_div, response)
    if ok then
      return filtered_response
    else
      return response
    end
  end, vim.lsp.buf.hover, handlers.hover, config.cfg.lsp.hover)
end

--- Open quickfix list of references of the symbol under the cursor
M.ask_references = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local uri = res.uri
    if not res.uri then
      return
    end
    if require("otter.tools.functions").is_otterpath(uri) then
      res.uri = main_uri
    end
    return res
  end

  M.send_request(main_nr, "textDocument/references", redirect, vim.lsp.buf.references)
end

--- Open list of symbols of the current document
M.ask_document_symbols = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    if not res.location or not res.location.uri then
      return
    end
    local uri = res.location.uri
    if require("otter.tools.functions").is_otterpath(uri) then
      res.location.uri = main_uri
    end
    return res
  end

  M.send_request(
    main_nr,
    "textDocument/documentSymbol",
    redirect,
    vim.lsp.buf.document_symbol,
    handlers.document_symbol
  )
end

--- Rename symbol under cursor
M.ask_rename = function()
  local main_nr = api.nvim_get_current_buf()
  local main_uri = vim.uri_from_bufnr(main_nr)

  local function redirect(res)
    local changes = res.changes
    if changes ~= nil then
      local new_changes = {}
      for uri, change in pairs(changes) do
        if require("otter.tools.functions").is_otterpath(uri) then
          uri = main_uri
        end
        new_changes[uri] = change
      end
      res.changes = new_changes
      return res
    else
      changes = res.documentChanges
      local new_changes = {}
      for _, change in ipairs(changes) do
        local uri = change.textDocument.uri
        if require("otter.tools.functions").is_otterpath(uri) then
          change.textDocument.uri = main_uri
        end
        table.insert(new_changes, change)
      end
      res.documentChanges = new_changes
      return res
    end
  end

  M.send_request(main_nr, "textDocument/rename", redirect, vim.lsp.buf.rename)
end

--- Reformat current otter context
M.ask_format = function()
  local main_nr = api.nvim_get_current_buf()

  -- redirection has to happen in the handler instead,
  -- because the response doesn't contain a mention
  -- of the buffer.
  local function redirect(res)
    return res
  end

  M.send_request(
    main_nr,
    "textDocument/rangeFormatting",
    redirect,
    vim.lsp.buf.format,
    handlers.format,
    { main_nr = main_nr }
  )
end

return M
