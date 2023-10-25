local M = {}
local lines = require("otter.tools.functions").lines
local empty_lines = require("otter.tools.functions").empty_lines
local path_to_otterpath = require("otter.tools.functions").path_to_otterpath
local otterpath_to_plain_path = require("otter.tools.functions").otterpath_to_plain_path
local concat = require("otter.tools.functions").concat
local contains = require("otter.tools.functions").contains
local extensions = require("otter.tools.extensions")
local api = vim.api
local ts = vim.treesitter

M._otters_attached = {}

local injectable_languages = {}
for key, _ in pairs(extensions) do
  table.insert(injectable_languages, key)
end

local function determine_language(main_nr, name, node, metadata, current_language)
  local injection_language = metadata["injection.language"]
  if injection_language ~= nil then
    -- chunks using the metadata to specify the injected language
    -- e.g. html script tags
    if injection_language ~= "comment" then
      -- don't use comment as language,
      -- comments with langue insiide are handled in injection.combined
      return injection_language
    end
  elseif metadata["injection.combined"] == true then
    -- chunks where the injected language is specified in the text of a comment
    local lang_capture = metadata[2]["text"]
    if lang_capture ~= nil then
      return lang_capture
    end
  elseif name == "_lang" or name == "injection.language" then
    -- chunks where the name of the injected language is dynamic
    -- e.g. markdown code chunks
    return ts.get_node_text(node, main_nr, metadata)
  else
    return current_language
  end
end

---Extract code chunks from the specified buffer.
---Updates M._otters_attached[main_nr].code_chunks
---@param main_nr integer The main buffer number
---@param lang string|nil language to extract. All languages if nil.
---@return table
local function extract_code_chunks(main_nr, lang, exclude_eval_false, row_from, row_to)
  local query = M._otters_attached[main_nr].query
  local parser = M._otters_attached[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  local code_chunks = {}
  local lang_capture = nil
  for id, node, metadata in query:iter_captures(root, main_nr) do
    local name = query.captures[id]
    local text

    lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)
    if
        lang_capture
        and (name == "content" or name == "injection.content")
        and (lang == nil or lang_capture == lang)
    then
      -- the actual code content
      text = ts.get_node_text(node, main_nr, metadata)
      if exclude_eval_false and string.find(text, "| *eval: *false") then
        text = ""
      end
      local row1, col1, row2, col2 = node:range()
      if row_from ~= nil and row_to ~= nil and ((row1 >= row_to and row_to > 0) or row2 < row_from) then
        goto continue
      end
      local result = {
        range = { from = { row1, col1 }, to = { row2, col2 } },
        lang = lang_capture,
        node = node,
        text = lines(text),
      }
      if code_chunks[lang_capture] == nil then
        code_chunks[lang_capture] = {}
      end
      table.insert(code_chunks[lang_capture], result)
      -- reset current language
      lang_capture = nil
    elseif contains(injectable_languages, name) then
      -- chunks where the name of the language is the name of the capture
      if lang == nil or name == lang then
        text = ts.get_node_text(node, main_nr, metadata)
        local row1, col1, row2, col2 = node:range()
        local result = {
          range = { from = { row1, col1 }, to = { row2, col2 } },
          lang = name,
          node = node,
          text = lines(text),
        }
        if code_chunks[name] == nil then
          code_chunks[name] = {}
        end
        table.insert(code_chunks[name], result)
      end
    end
    ::continue::
  end
  return code_chunks
end

M.get_current_language_context = function(main_nr)
  main_nr = main_nr or api.nvim_get_current_buf()
  if M._otters_attached[main_nr] == nil then
    return nil
  end
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  col = col

  local query = M._otters_attached[main_nr].query
  local parser = M._otters_attached[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()
  local lang_capture = nil
  for id, node, metadata in query:iter_captures(root, main_nr) do
    local name = query.captures[id]

    lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)

    if
        lang_capture
        and (name == "content" or name == "injection.content")
    then
      -- chunks where the name of the injected language is dynamic
      -- e.g. markdown code chunks
      if ts.is_in_node_range(node, row, col) then
        return lang_capture, node:range()
      end
      -- chunks where the name of the language is the name of the capture
    elseif contains(injectable_languages, name) then
      if ts.is_in_node_range(node, row, col) then
        return name, node:range()
      end
    end
  end
  return nil
end

--- Syncronize the raft of otters attached to a buffer
---@param main_nr integer bufnr of the parent buffer
---@param lang string|nil only sync one otter buffer matching a language
M.sync_raft = function(main_nr, lang)
  if M._otters_attached[main_nr] ~= nil then
    local all_code_chunks
    local changetick = api.nvim_buf_get_changedtick(main_nr)
    if M._otters_attached[main_nr].last_changetick == changetick then
      all_code_chunks = M._otters_attached[main_nr].code_chunks
    else
      all_code_chunks = extract_code_chunks(main_nr)
    end

    M._otters_attached[main_nr].last_changetick = changetick
    M._otters_attached[main_nr].code_chunks = all_code_chunks

    if next(all_code_chunks) == nil then
      return {}
    end
    local langs
    if lang == nil then
      langs = M._otters_attached[main_nr].languages
    else
      langs = { lang }
    end
    for _, lang in ipairs(langs) do
      local otter_nr = M._otters_attached[main_nr].buffers[lang]
      if otter_nr ~= nil then
        local code_chunks = all_code_chunks[lang]
        if code_chunks ~= nil then
          local nmax = code_chunks[#code_chunks].range["to"][1] -- last code line

          -- create list with empty lines the length of the buffer
          local ls = empty_lines(nmax)

          -- collect language lines
          for _, t in ipairs(code_chunks) do
            local start_index = t.range["from"][1]
            for i, l in ipairs(t.text) do
              local index = start_index + i
              table.remove(ls, index)
              table.insert(ls, index, l)
            end
          end

          -- clear buffer
          api.nvim_buf_set_lines(otter_nr, 0, -1, false, {})
          -- add language lines
          api.nvim_buf_set_lines(otter_nr, 0, nmax, false, ls)
        end
      end
    end
  end
end

--- Activate the current buffer by adding and syncronizing
--- otter buffers.
---@param languages table
---@param completion boolean|nil
---@param diagnostics boolean|nil
---@param tsquery string|nil
M.activate = function(languages, completion, diagnostics, tsquery)
  completion = completion or true
  diagnostics = diagnostics or true
  local main_nr = api.nvim_get_current_buf()
  local main_path = api.nvim_buf_get_name(main_nr)
  local parsername = vim.treesitter.language.get_lang(api.nvim_buf_get_option(main_nr, "filetype"))
  if not parsername then
    return
  end
  local query
  if tsquery ~= nil then
    query = ts.query.parse(parsername, tsquery)
  else
    query = ts.query.get(parsername, "injections")
  end
  M._otters_attached[main_nr] = {}
  M._otters_attached[main_nr].languages = languages
  M._otters_attached[main_nr].buffers = {}
  M._otters_attached[main_nr].otter_nr_to_lang = {}
  M._otters_attached[main_nr].tsquery = tsquery
  M._otters_attached[main_nr].query = query
  M._otters_attached[main_nr].parser = ts.get_parser(main_nr, parsername)
  M._otters_attached[main_nr].code_chunks = nil
  M._otters_attached[main_nr].last_changetick = nil

  local all_code_chunks = extract_code_chunks(main_nr)
  local found_languages = {}
  for _, lang in ipairs(languages) do
    if all_code_chunks[lang] ~= nil then
      table.insert(found_languages, lang)
    end
  end
  languages = found_languages
  M._otters_attached[main_nr].languages = languages

  -- create otter buffers
  for _, lang in ipairs(languages) do
    local extension = "." .. extensions[lang]
    if extension ~= nil then
      local otter_path = path_to_otterpath(main_path, extension)
      local otter_uri = "file://" .. otter_path
      local otter_nr = vim.uri_to_bufnr(otter_uri)
      api.nvim_buf_set_name(otter_nr, otter_path)
      api.nvim_buf_set_option(otter_nr, "swapfile", false)
      api.nvim_buf_set_option(otter_nr, "buftype", "nowrite")
      M._otters_attached[main_nr].buffers[lang] = otter_nr
      M._otters_attached[main_nr].otter_nr_to_lang[otter_nr] = lang
    end
  end

  M.sync_raft(main_nr)

  -- manually attach language server the corresponds to the fileytype
  -- without setting the filetype
  -- to prevent other plugins we don't need in the otter buffers
  -- from automatically attaching when ft is set
  for _, lang in ipairs(languages) do
    local otter_nr = M._otters_attached[main_nr].buffers[lang]

    local autocommands = api.nvim_get_autocmds({ group = "lspconfig", pattern = lang })
    for _, command in ipairs(autocommands) do
      local opt = { buf = otter_nr }
      command.callback(opt)
    end
  end

  if completion then
    require("otter.completion").setup_sources(main_nr, M._otters_attached[main_nr])
  end

  if diagnostics then
    local nss = {}
    for lang, bufnr in pairs(M._otters_attached[main_nr].buffers) do
      local ns = api.nvim_create_namespace("otter-lang-" .. lang)
      nss[bufnr] = ns
    end

    api.nvim_create_autocmd("BufWritePost", {
      buffer = main_nr,
      group = api.nvim_create_augroup("OtterLSPDiagnositcs", {}),
      callback = function(_, _)
        M.sync_raft(main_nr)
        for bufnr, ns in pairs(nss) do
          local diag = vim.diagnostic.get(bufnr)
          vim.diagnostic.reset(ns, main_nr)
          vim.diagnostic.set(ns, main_nr, diag, {})
        end
      end,
    })
  end
end

--- Send a request to the otter buffers and handle the response.
--- The response can optionally be filtered through a function.
---@param main_nr integer bufnr of main buffer
---@param request string lsp request
---@param filter function|nil function to process the response
---@param fallback function|nil optional funtion to call if not in an otter context
---@param handler function|nil optional funtion to handle the filtered lsp request for cases in which the default handler does not suffice
---@param conf table|nil optional config to pass to the handler.
M.send_request = function(main_nr, request, filter, fallback, handler, conf)
  fallback = fallback or nil
  filter = filter or function(x)
    return x
  end
  M.sync_raft(main_nr)

  local lang, start_row, start_col, end_row, end_col = M.get_current_language_context()

  if not contains(M._otters_attached[main_nr].languages, lang) then
    if fallback then
      fallback()
    end
    return
  end

  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  local otter_uri = vim.uri_from_bufnr(otter_nr)
  local params
  if request == "textDocument/documentSymbol" then
    params = vim.lsp.util.make_text_document_params()
    params.uri = otter_uri
  else
    params = vim.lsp.util.make_position_params()
  end
  -- general
  params.textDocument = {
    uri = otter_uri,
  }
  if request == "textDocument/references" then
    params.context = {
      includeDeclaration = true,
    }
  end
  -- for 'textDocument/rename'
  if request == "textDocument/rename" then
    local cword = vim.fn.expand("<cword>")
    local prompt_opts = {
      prompt = "New Name: ",
      default = cword,
    }
    vim.ui.input(prompt_opts, function(input)
      params.newName = input
    end)
  end
  if request == "textDocument/rangeFormatting" then
    params = vim.lsp.util.make_formatting_params()
    params.textDocument = {
      uri = otter_uri,
    }
    params.range = {
      start = { line = start_row, character = start_col },
      ["end"] = { line = end_row, character = end_col },
    }
  end

  vim.lsp.buf_request(otter_nr, request, params, function(err, response, ctx, ...)
    if response == nil then
      return
    end
    -- if response is a list of responses, filter every response
    if #response > 0 then
      local responses = {}
      for _, res in ipairs(response) do
        local filtered_res = filter(res)
        if filtered_res then
          table.insert(responses, filtered_res)
        end
      end
      response = responses
    else
      -- otherwise apply the filter to the one response
      response = filter(response)
    end
    if response == nil then
      return
    end
    if handler ~= nil then
      handler(err, response, ctx, conf)
    else
      vim.lsp.handlers[request](err, response, ctx, ...)
    end
  end)
end

--- Export the raft of otters as files.
--- Asks for filename for each language.
---@param force boolean
M.export_raft = function(force)
  local main_nr = api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  for _, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
    local path = api.nvim_buf_get_name(otter_nr)
    local lang = M._otters_attached[main_nr].otter_nr_to_lang[otter_nr]
    local extension = extensions[lang] or ""
    path = otterpath_to_plain_path(path) .. extension
    vim.notify("Exporting otter: " .. lang)
    local new_path = vim.fn.input({ prompt = "New path: ", default = path, completion = "file" })
    if new_path ~= "" then
      api.nvim_set_current_buf(otter_nr)
      vim.lsp.buf.format({ bufnr = otter_nr })
      vim.cmd.write({ new_path, bang = force })
    end
    api.nvim_set_current_buf(main_nr)
  end
end

--- Export only one language to a pre-specified filename
---@param language string
---@param fname string
---@param force boolean
M.export_otter_as = function(language, fname, force)
  local main_nr = api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  for _, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
    local path = api.nvim_buf_get_name(otter_nr)
    local lang = M._otters_attached[main_nr].otter_nr_to_lang[otter_nr]
    if lang ~= language then
      return
    end
    path = path:match("(.*[/\\])") .. fname
    api.nvim_set_current_buf(otter_nr)
    vim.lsp.buf.format()
    vim.cmd.write({ path, bang = force })
    api.nvim_set_current_buf(main_nr)
  end
end

M.get_curent_language_lines = function(exclude_eval_false, row_start, row_end)
  local main_nr = vim.api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  local lang = M.get_current_language_context()
  if lang == nil then
    return
  end

  local chunks = extract_code_chunks(main_nr, lang, exclude_eval_false, row_start, row_end)[lang]
  if not chunks or next(chunks) == nil then
    return
  end
  local code = {}
  for _, c in ipairs(chunks) do
    table.insert(code, concat(c.text))
  end
  return code
end

M.get_language_lines_around_cursor = function()
  local main_nr = vim.api.nvim_get_current_buf()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  col = col

  local query = M._otters_attached[main_nr].query
  local parser = M._otters_attached[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  for id, node, metadata in query:iter_captures(root, main_nr) do
    local name = query.captures[id]
    if name == "content" then
      if ts.is_in_node_range(node, row, col) then
        return ts.get_node_text(node, main_nr, metadata)
      end
      -- chunks where the name of the language is the name of the capture
    elseif contains(injectable_languages, name) then
      if ts.is_in_node_range(node, row, col) then
        return ts.get_node_text(node, main_nr, metadata)
      end
    end
  end
end

M.get_language_lines_to_cursor = function(exclude_eval_false)
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  row = row + 1
  return M.get_curent_language_lines(exclude_eval_false, 0, row)
end

M.get_language_lines_from_cursor = function(exclude_eval_false)
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  row = row + 1
  return M.get_curent_language_lines(exclude_eval_false, row, -1)
end

M.get_language_lines = function(exclude_eval_false)
  return M.get_curent_language_lines(exclude_eval_false)
end

M.get_language_lines_in_visual_selection = function(exclude_eval_false)
  local lang = M.get_current_language_context()
  if lang == nil then
    return
  end
  local row_start, _ = unpack(api.nvim_buf_get_mark(0, "<"))
  local row_end, _ = unpack(api.nvim_buf_get_mark(0, ">"))
  row_start = row_start - 1
  row_end = row_end - 1
  return M.get_curent_language_lines(exclude_eval_false, row_start, row_end)
end

return M
