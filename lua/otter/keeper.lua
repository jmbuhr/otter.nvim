local M = {}

local extensions = require("otter.tools.extensions")
local fn = require("otter.tools.functions")
local api = vim.api
local ts = vim.treesitter
local config = require("otter.config")

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
      -- comments with language inside are handled in injection.combined
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

---trims the leading whitespace from text
---@param text string
---@param bufnr number host buffer number
---@param starting_ln number
---@return string, number
local function trim_leading_witespace(text, bufnr, starting_ln)
  if not config.cfg.handle_leading_whitespace then
    return text, 0
  end

  -- Assume the first line is least indented
  -- the first line in the capture doesn't have its leading indent, so we grab from the buffer
  local split = vim.split(text, "\n", { trimempty = false })
  if #split == 0 then
    return text, 0
  end
  local first_line = vim.api.nvim_buf_get_lines(bufnr, starting_ln, starting_ln + 1, false)
  local leading = first_line[1]:match("^%s+")
  if not leading then
    return text, 0
  end
  for i, line in ipairs(split) do
    split[i] = line:gsub("^" .. leading, "")
  end
  return table.concat(split, "\n"), #leading
end

---@class CodeChunk
---@field range table
---@field lang string
---@field node any
---@field text string
---@field leading_offset number

---Extract code chunks from the specified buffer.
---Updates M._otters_attached[main_nr].code_chunks
---@param main_nr integer The main buffer number
---@param lang string|nil language to extract. All languages if nil.
---@return CodeChunk[]
M.extract_code_chunks = function(main_nr, lang, exclude_eval_false, row_from, row_to)
  local query = M._otters_attached[main_nr].query
  local parser = M._otters_attached[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  local code_chunks = {}
  local lang_capture = nil
  for _, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do

      -- TODO: maybe can be removed with nvim v0.10
      if type(nodes) ~= "table" then
        nodes = { nodes }
      end

      for _, node in ipairs(nodes) do
        local name = query.captures[id]
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
          -- remove surrounding quotes (workaround for treesitter offsets
          -- not properly processed)
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
          local leading_offset
          text, leading_offset = trim_leading_witespace(text, main_nr, row1)
          local result = {
            range = { from = { row1, col1 }, to = { row2, col2 } },
            lang = lang_capture,
            node = node,
            text = fn.lines(text),
            leading_offset = leading_offset,
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
            local leading_offset
            text, leading_offset = trim_leading_witespace(text, main_nr, row1)
            local result = {
              range = { from = { row1, col1 }, to = { row2, col2 } },
              lang = name,
              node = node,
              text = fn.lines(text),
              leading_offset = leading_offset,
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
  P(code_chunks)
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
  for _, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]

      -- TODO: maybe can be removed with nvim v0.10
      if type(nodes) ~= "table" then
        nodes = { nodes }
      end

      for _, node in ipairs(nodes) do
        lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)
        local start_row, start_col, end_row, end_col = node:range()
        end_row = end_row - 1

        local language = nil
        if lang_capture and (name == "content" or name == "injection.content") then
          -- chunks where the name of the injected language is dynamic
          -- e.g. markdown code chunks
          if ts.is_in_node_range(node, row, col) then
            language = lang_capture
          end
          -- chunks where the name of the language is the name of the capture
        elseif fn.contains(injectable_languages, name) then
          if ts.is_in_node_range(node, row, col) then
            language = name
          end
        end

        if language then
          if config.cfg.handle_leading_whitespace then
            local buf = M._otters_attached[main_nr].buffers[language]
            if buf then
              local lines = vim.api.nvim_buf_get_lines(buf, end_row - 1, end_row, false)
              if lines[1] then
                end_col = #lines[1]
              end
            end
          end
          return language, start_row, start_col, end_row, end_col
        end
      end
    end
  end
  return nil
end

---find the leading_offset of the given line number, and buffer number. Returns 0 if the line number
---isn't in a chunk.
---@param line_nr number
---@param main_nr number
M.get_leading_offset = function(line_nr, main_nr)
  if not config.cfg.handle_leading_whitespace then
    return 0
  end

  local lang_chunks = M._otters_attached[main_nr].code_chunks
  for _, chunks in pairs(lang_chunks) do
    for _, chunk in ipairs(chunks) do
      if line_nr >= chunk.range.from[1] and line_nr <= chunk.range.to[1] then
        return chunk.leading_offset
      end
    end
  end
  return 0
end

---adjusts IN PLACE the position to include the start and end
---@param obj table
---@param main_nr number
---@param invert boolean?
---@param exclude_end boolean?
---@param known_offset number?
M.modify_position = function(obj, main_nr, invert, exclude_end, known_offset)
  if not config.cfg.handle_leading_whitespace or known_offset == 0 then
    return
  end

  local sign = invert and -1 or 1
  local offset = known_offset

  -- there are apparently a lot of ranges that different language servers can use
  local ranges = { "range", "targetSelectionRange", "targetRange", "originSelectionRange" }
  for _, range in ipairs(ranges) do
    if obj[range] then
      local start = obj[range].start
      local end_ = obj[range]["end"]
      offset = offset or M.get_leading_offset(start.line, main_nr) * sign
      obj[range].start.character = start.character + offset
      if not exclude_end then
        obj[range]["end"].character = end_.character + offset
      end
    end
  end

  if obj.position then
    local pos = obj.position
    offset = offset or M.get_leading_offset(pos.line, main_nr) * sign
    obj.position.character = pos.character + offset
  end

  if obj.documentChanges then
    for _, change in ipairs(obj.documentChanges) do
      if change.edits then
        for _, edit in ipairs(change.edits) do
          M.modify_position(edit, main_nr, invert, exclude_end, offset)
        end
      end
    end
  end

  if obj.changes then
    for _, change in pairs(obj.changes) do
      for _, edit in ipairs(change) do
        M.modify_position(edit, main_nr, invert, exclude_end, offset)
      end
    end
  end

  if obj.newText then
    offset = offset or M.get_leading_offset(obj.range.start, main_nr) * sign
    local str = ""
    for _ = 1, offset, 1 do
      str = str .. " "
    end
    -- Put indents in front of newline, but ignore newlines that are followed by newlines
    obj.newText = string.gsub(obj.newText, "(\n)([^\n])", "%1" .. str .. "%2")
    obj.newText = string.gsub(obj.newText, "\n$", "\n" .. str) -- match a potential newline at the end
  end
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
---@param fallback function|nil optional function to call if not in an otter context
---@param handler function|nil optional function to handle the filtered lsp request for cases in which the default handler does not suffice
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
    assert(end_row)
    local line = vim.api.nvim_buf_get_lines(otter_nr, end_row, end_row + 1, false)[1]
    if line then
      params.range["end"].character = #line
    end
    M.modify_position(params, main_nr, true, true)
  else
    -- formatting gets its own special treatment, everything else gets the same
    M.modify_position(params, main_nr, true)
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
          M.modify_position(filtered_res, main_nr)
          table.insert(responses, filtered_res)
        end
      end
      response = responses
    else
      -- otherwise apply the filter to the one response
      response = filter(response)
      M.modify_position(response, main_nr)
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
    path = fn.otterpath_to_plain_path(path) .. "." .. extension
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

      -- TODO: maybe can be removed with nvim v0.10
      if type(nodes) ~= "table" then
        nodes = { nodes }
      end

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
