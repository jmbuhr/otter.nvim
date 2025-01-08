--- The otter.keeep takes care of all the otters
--- attached to the main buffers.
--- Each main buffer is associated with a raft of
--- otter buffers and their respective languages
--- and code chunks
local keeper = {}

local extensions = require("otter.tools.extensions")
local fn = require("otter.tools.functions")
local api = vim.api
local ts = vim.treesitter
local cfg = require("otter.config").cfg

---@class Raft
---@field languages string[]
---@field buffers table<string, integer>
---@field paths table<string, string>
---@field otter_nr_to_lang table<integer, string>
---@field tsquery string?
---@field query vim.treesitter.Query
---@field parser vim.treesitter.LanguageTree
---@field otterls OtterLSInfo
---@field diagnostics_namespaces integer[]
---@field diagnostics_group integer?
---@field last_changetick integer?
---@field code_chunks table<string, CodeChunk[]>

---@class OtterLSInfo
---@field client_id integer?

---@class Rafts
---@field [number] Raft
---One raft per main buffer
---stored in the rafts table
keeper.rafts = {}

--- table of languages that can be injected
--- generated from the lanaguages
--- for which we have extensions
local injectable_languages = {}
for key, _ in pairs(extensions) do
  table.insert(injectable_languages, key)
end

---determine the language of the current node
---@param main_nr integer bufnr of the main buffer
---@param name string name of the capture
---@param node table node of the current capture
---@param metadata table metadata of the current capture
---@param current_language string? current language
---@return string?
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
---@param bufnr integer host buffer number
---@param starting_ln integer
---@return string, integer
local function trim_leading_witespace(text, bufnr, starting_ln)
  if not cfg.handle_leading_whitespace then
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
---@field range { from: [integer, integer], to: [integer, integer] }
---@field lang string
---@field node TSNode
---@field text string[]
---@field leading_offset number

---Extract code chunks from the specified buffer.
---Updates M.rafts[main_nr].code_chunks
---@param main_nr integer The main buffer number
---@param lang string? language to extract. All languages if nil.
---@param exclude_eval_false boolean? Exclude code chunks with eval: false
---@param range_start_row integer? Row to start from, inclusive, 1-indexed.
---@param range_end_row integer? Row to end at, inclusive, 1-indexed.
---@return table<string, CodeChunk[]>
keeper.extract_code_chunks = function(main_nr, lang, exclude_eval_false, range_start_row, range_end_row)
  local query = keeper.rafts[main_nr].query
  local parser = keeper.rafts[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  ---@type table<string, CodeChunk[]>
  local code_chunks = {}
  local lang_capture = nil
  for _, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]

      for _, node in ipairs(nodes) do
        local text
        lang_capture = determine_language(main_nr, name, node, metadata, lang_capture)
        if
            lang_capture
            and (name == "content" or name == "injection.content")
            and (lang == nil or lang_capture == lang)
        then
          -- the actual code content
          text = ts.get_node_text(node, main_nr, { metadata = metadata[id] })
          -- remove surrounding quotes
          -- (workaround for treesitter offsets not properly processed)
          text, _ = fn.strip_wrapping_quotes(text)
          if exclude_eval_false and string.find(text, "| *eval: *false") then
            text = ""
          end

          ---@type integer
          ---@diagnostic disable-next-line: assign-type-mismatch
          local start_row, start_col, end_row, end_col = node:range()
          if range_start_row ~= nil and range_end_row ~= nil and ((start_row >= range_end_row and range_end_row > 0) or end_row < range_start_row) then
            goto continue
          end
          local leading_offset
          text, leading_offset = trim_leading_witespace(text, main_nr, start_row)
          local result = {
            range = { from = { start_row, start_col }, to = { end_row, end_col } },
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
            text, _ = fn.strip_wrapping_quotes(text)

            ---@type integer
            ---@diagnostic disable-next-line: assign-type-mismatch
            local start_row, start_col, end_row, end_col = node:range()
            local leading_offset
            text, leading_offset = trim_leading_witespace(text, main_nr, start_row)
            local result = {
              range = { from = { start_row, start_col }, to = { end_row, end_col } },
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
  return code_chunks
end

--- Get the language context of a position
--- @param main_nr integer? bufnr of the parent buffer. Default is 0
--- @param position table? position (row, col). Default is the current cursor position
--- @return string? language nil if no language context is found
--- @return integer? start_row
--- @return integer? start_col
--- @return integer? end_row
--- @return integer? end_col
keeper.get_current_language_context = function(main_nr, position)
  main_nr = main_nr or api.nvim_get_current_buf()
  position = position or api.nvim_win_get_cursor(0)
  if keeper.rafts[main_nr] == nil then
    return nil
  end
  local row, col = unpack(position)
  row = row - 1
  col = col

  local query = keeper.rafts[main_nr].query
  local parser = keeper.rafts[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()
  local lang_capture = nil
  for _, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]

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
          if cfg.handle_leading_whitespace then
            local buf = keeper.rafts[main_nr].buffers[language]
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
keeper.get_leading_offset = function(line_nr, main_nr)
  if not cfg.handle_leading_whitespace then
    return 0
  end

  local lang_chunks = keeper.rafts[main_nr].code_chunks
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
keeper.modify_position = function(obj, main_nr, invert, exclude_end, known_offset)
  if not cfg.handle_leading_whitespace or known_offset == 0 then
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
      offset = offset or keeper.get_leading_offset(start.line, main_nr) * sign
      obj[range].start.character = start.character + offset
      if not exclude_end then
        obj[range]["end"].character = end_.character + offset
      end
    end
  end

  if obj.position then
    local pos = obj.position
    offset = offset or keeper.get_leading_offset(pos.line, main_nr) * sign
    obj.position.character = pos.character + offset
  end

  if obj.documentChanges then
    for _, change in ipairs(obj.documentChanges) do
      if change.edits then
        for _, edit in ipairs(change.edits) do
          keeper.modify_position(edit, main_nr, invert, exclude_end, offset)
        end
      end
    end
  end

  if obj.changes then
    for _, change in pairs(obj.changes) do
      for _, edit in ipairs(change) do
        keeper.modify_position(edit, main_nr, invert, exclude_end, offset)
      end
    end
  end

  if obj.newText then
    offset = offset or keeper.get_leading_offset(obj.range.start, main_nr) * sign
    local str = ""
    for _ = 1, offset, 1 do
      str = str .. " "
    end
    -- Put indents in front of newline, but ignore newlines that are followed by newlines
    obj.newText = string.gsub(obj.newText, "(\n)([^\n])", "%1" .. str .. "%2")
    obj.newText = string.gsub(obj.newText, "\n$", "\n" .. str) -- match a potential newline at the end
  end
end

---@param main_nr integer bufnr of the parent buffer
---@return boolean has_raft true if the buffer has otters attached
keeper.has_raft = function(main_nr)
  return keeper.rafts[main_nr] ~= nil
end

---@alias SyncResult
---| '"success"' -- The sync was successful
---| '"no_raft"' -- The buffer has no raft
---| '"textlock_active"' -- The buffer is currently locked
---| '"error"' -- Some other error occurred

--- Synchronize the raft of otters attached to a buffer
---@param main_nr integer bufnr of the parent buffer
---@param language string|nil only sync one otter buffer matching a language
---@return SyncResult result
keeper.sync_raft = function(main_nr, language)
  if not keeper.has_raft(main_nr) then
    return "no_raft"
  end
  local all_code_chunks
  local changetick = api.nvim_buf_get_changedtick(main_nr)
  if keeper.rafts[main_nr].last_changetick == changetick then
    all_code_chunks = keeper.rafts[main_nr].code_chunks
    return "success"
  end


  ---@param callback function
  ---@return SyncResult
  ---
  --- Assumption: If textlock is currently active,
  --- we can't sync, but those are also the cases
  --- in which it is not necessary to sync
  --- and can be delayed until the textlock is released.
  --- The lsp request should still be valid
  local function do_with_maybe_texlock(callback)
    local texlock_err_msg = 'Vim(normal):E5556: API call: E565: Not allowed to change text or change window'
    local success, result = pcall(callback)
    if success then
      return "success"
    end

    vim.notify_once("[otter.nvim] Hi there! You triggered an LSP request that is routed through otter.nvim while textlock is active. We would like to fix this, but need to find the exact form of the error message to match against. Please be so kind and open an issue with how you triggered this and the error object below:", vim.log.levels.WARN)
    vim.notify_once(vim.inspect(result), vim.log.levels.WARN)

    if result == texlock_err_msg then
      vim.schedule(callback)
      return "textlock_active"
    else
      error(result)
      return "error"
    end
  end

  all_code_chunks = keeper.extract_code_chunks(main_nr)

  keeper.rafts[main_nr].last_changetick = changetick
  keeper.rafts[main_nr].code_chunks = all_code_chunks

  local result
  local langs
  if language == nil then
    langs = keeper.rafts[main_nr].languages
  else
    langs = { language }
  end
  for _, lang in ipairs(langs) do
    local otter_nr = keeper.rafts[main_nr].buffers[lang]
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

        -- replace language lines
        result = do_with_maybe_texlock(function()
          api.nvim_buf_set_lines(otter_nr, 0, -1, false, ls)
        end)
      else
        -- no code chunks so we wipe the otter buffer
        result = do_with_maybe_texlock(function()
          api.nvim_buf_set_lines(otter_nr, 0, -1, false, {})
        end)
      end
    end
  end

  return result
end

--- Export the raft of otters as files.
--- Asks for filename for each language.
---@param force boolean
keeper.export_raft = function(force)
  local main_nr = api.nvim_get_current_buf()
  keeper.sync_raft(main_nr)
  for _, otter_nr in pairs(keeper.rafts[main_nr].buffers) do
    local path = api.nvim_buf_get_name(otter_nr)
    local lang = keeper.rafts[main_nr].otter_nr_to_lang[otter_nr]
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

---Export only one language to a pre-specified filename
---@param language string
---@param fname string
---@param force boolean
keeper.export_otter_as = function(language, fname, force)
  local main_nr = api.nvim_get_current_buf()
  keeper.sync_raft(main_nr)
  for _, otter_nr in pairs(keeper.rafts[main_nr].buffers) do
    local path = api.nvim_buf_get_name(otter_nr)
    local lang = keeper.rafts[main_nr].otter_nr_to_lang[otter_nr]
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

---Get lines of code chunks managed by otter in a range of the current buffer.
---@param exclude_eval_false boolean | nil Exclude code chunks with eval: false
---@param row_start integer Row to start from, inclusive, 1-indexed.
---@param row_end integer Row to end at, inclusive, 1-indexed.
---@return string[]|nil Lines of code
keeper.get_language_lines = function(exclude_eval_false, row_start, row_end)
  local main_nr = vim.api.nvim_get_current_buf()
  keeper.sync_raft(main_nr)
  local lang = keeper.get_current_language_context()
  if lang == nil then
    return
  end

  local chunks = keeper.extract_code_chunks(main_nr, lang, exclude_eval_false, row_start, row_end)[lang]
  if not chunks or next(chunks) == nil then
    return
  end
  local code = {}
  for _, c in ipairs(chunks) do
    table.insert(code, fn.concat(c.text))
  end
  return code
end

---Get lines of code chunks managed by otter around the cursor in the current buffer.
---@return string|nil Lines of code
keeper.get_language_lines_around_cursor = function()
  local main_nr = vim.api.nvim_get_current_buf()
  local row, col = unpack(api.nvim_win_get_cursor(0))
  row = row - 1
  col = col

  local query = keeper.rafts[main_nr].query
  local parser = keeper.rafts[main_nr].parser
  local tree = parser:parse()
  local root = tree[1]:root()

  for _, match, metadata in query:iter_matches(root, main_nr, 0, -1, { all = true }) do
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

---Get lines of code chunks managed by otter in the current buffer up to the cursor.
---@param exclude_eval_false boolean|nil Exclude code chunks with eval: false
keeper.get_language_lines_to_cursor = function(exclude_eval_false)
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  row = row + 1
  return keeper.get_language_lines(exclude_eval_false, 0, row)
end

---Get lines of code chunks managed by otter in the current buffer from the cursor to the end.
---@param exclude_eval_false boolean|nil Exclude code chunks with eval: false
keeper.get_language_lines_from_cursor = function(exclude_eval_false)
  local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
  row = row + 1
  return keeper.get_language_lines(exclude_eval_false, row, -1)
end

---Get lines of code chunks managed by otter in the current buffer from the cursor to the end.
---@param exclude_eval_false boolean|nil Exclude code chunks with eval: false
keeper.get_language_lines_in_visual_selection = function(exclude_eval_false)
  local lang = keeper.get_current_language_context()
  if lang == nil then
    return
  end
  local row_start, _ = unpack(api.nvim_buf_get_mark(0, "<"))
  local row_end, _ = unpack(api.nvim_buf_get_mark(0, ">"))
  return keeper.get_language_lines(exclude_eval_false, row_start, row_end)
end

return keeper
