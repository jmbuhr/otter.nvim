local M = {}

local fn = require("otter.tools.functions")
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
M.extract_code_chunks = function(main_nr, lang, exclude_eval_false, row_from, row_to)
  local query = M._otters_attached[main_nr].query
  local parser = M._otters_attached[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  local code_chunks = {}
  local lang_capture = nil
  for pattern, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      for _, node in ipairs(nodes) do
        local text
        local was_stripped
        lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)
        if
            lang_capture
            and (name == "content" or name == "injection.content")
            and (lang == nil or lang_capture == lang)
        then
          -- the actual code content
          text = ts.get_node_text(node, main_nr, { metadata = metadata[id] })

          -- remove surrounding quotes (workaround for treesitter offets
          -- not properly processed)
          -- TODO: evaluate if this is still necessary after the fix
          text, was_stripped = fn.strip_wrapping_quotes(text)
          if exclude_eval_false and string.find(text, "| *eval: *false") then
            text = ""
          end

          local row1, col1, row2, col2 = node:range()
          -- TODO: modify rows and cols accordingly
          -- requires more logic to test if the code
          -- and the wrapping quotes where on separate lines
          -- and how to handle inline-code.
          -- also for lsp request translation
          -- if was_stripped then
          --   col1 = col1 + 1
          --   col2 = col2 - 1
          -- end
          if row_from ~= nil and row_to ~= nil and ((row1 >= row_to and row_to > 0) or row2 < row_from) then
            goto continue
          end
          local result = {
            range = { from = { row1, col1 }, to = { row2, col2 } },
            lang = lang_capture,
            node = node,
            text = fn.lines(text),
          }
          if code_chunks[lang_capture] == nil then
            code_chunks[lang_capture] = {}
          end
          table.insert(code_chunks[lang_capture], result)
          -- reset current language
          lang_capture = nil
        elseif fn.contains(injectable_languages, name) then
          -- chunks where the name of the language is the name of the capture
          if lang == nil or name == lang then
            text = ts.get_node_text(node, main_nr, { metadata = metadata[id] })
            text, was_stripped = fn.strip_wrapping_quotes(text)
            local row1, col1, row2, col2 = node:range()
            -- if was_stripped then
            --   col1 = col1 + 1
            --   col2 = col2 - 1
            -- end
            local result = {
              range = { from = { row1, col1 }, to = { row2, col2 } },
              lang = name,
              node = node,
              text = fn.lines(text),
            }
            if code_chunks[name] == nil then
              code_chunks[name] = {}
            end
            table.insert(code_chunks[name], result)
          end
        end
        ::continue::
      end
    end
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
  for pattern, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      for _, node in ipairs(nodes) do
        lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)

        if lang_capture and (name == "content" or name == "injection.content") then
          -- chunks where the name of the injected language is dynamic
          -- e.g. markdown code chunks
          if ts.is_in_node_range(node, row, col) then
            return lang_capture, node:range()
          end
          -- chunks where the name of the language is the name of the capture
        elseif fn.contains(injectable_languages, name) then
          if ts.is_in_node_range(node, row, col) then
            return name, node:range()
          end
        end
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
      all_code_chunks = M.extract_code_chunks(main_nr)
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
          local ls = fn.empty_lines(nmax)

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

  if not fn.contains(M._otters_attached[main_nr].languages, lang) then
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
    local extension = extensions[lang] or lang
    path = fn.otterpath_to_plain_path(path) .. '.' .. extension
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

  local chunks = M.extract_code_chunks(main_nr, lang, exclude_eval_false, row_start, row_end)[lang]
  if not chunks or next(chunks) == nil then
    return
  end
  local code = {}
  for _, c in ipairs(chunks) do
    table.insert(code, fn.concat(c.text))
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

  for pattern, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      for _, node in ipairs(nodes) do
        if name == "content" then
          if ts.is_in_node_range(node, row, col) then
            return ts.get_node_text(node, main_nr, metadata)
          end
          -- chunks where the name of the language is the name of the capture
        elseif fn.contains(injectable_languages, name) then
          if ts.is_in_node_range(node, row, col) then
            return ts.get_node_text(node, main_nr, metadata)
          end
        end
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
