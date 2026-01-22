--- The otter.keeep takes care of all the otters
--- attached to the main buffers.
--- Each main buffer is associated with a raft of
--- otter buffers and their respective languages
--- and code chunks
local keeper = {}

local fn = require("otter.tools.functions")
local api = vim.api

---@class Raft
---@field languages string[]
---@field buffers table<string, integer>
---@field paths table<string, string>
---@field preambles table<string, string[]>
---@field postambles table<string, string[]>
---@field ignore_pattern table<string, string>
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
for key, _ in pairs(OtterConfig.extensions) do
  table.insert(injectable_languages, key)
end

---trims the leading whitespace from text
---Only removes whitespace that is common to ALL non-empty lines (minimum indentation).
---This preserves relative indentation within code blocks while handling
---entirely-indented code blocks (e.g., in norg nested structures).
---@param text string
---@return string, integer
local function trim_leading_whitespace(text)
  if not OtterConfig.handle_leading_whitespace then
    return text, 0
  end

  local split = vim.split(text, "\n", { trimempty = false })
  if #split == 0 then
    return text, 0
  end

  -- Count non-empty lines
  local non_empty_count = 0
  for _, line in ipairs(split) do
    if line ~= "" and not line:match("^%s*$") then
      non_empty_count = non_empty_count + 1
    end
  end

  -- Only strip leading whitespace if we have multiple non-empty lines
  -- Single-line regions can't distinguish between document-level and code-level indentation
  if non_empty_count <= 1 then
    return text, 0
  end

  -- Find minimum indentation across all non-empty lines in the text
  local min_indent = nil
  for _, line in ipairs(split) do
    if line ~= "" and not line:match("^%s*$") then
      local leading = line:match("^(%s*)")
      local indent_len = leading and #leading or 0
      if min_indent == nil or indent_len < min_indent then
        min_indent = indent_len
      end
    end
  end

  -- If no indentation found or min is 0, return as-is
  if not min_indent or min_indent == 0 then
    return text, 0
  end

  -- Strip the common minimum indentation from each line
  for i, line in ipairs(split) do
    if #line >= min_indent then
      split[i] = line:sub(min_indent + 1)
    end
  end

  return table.concat(split, "\n"), min_indent
end

---Recursively collect all injected language trees.
---This collects ALL trees in a list to handle cases where the same language
---appears at multiple levels (e.g., JS in fenced code blocks AND in HTML <script> tags)
---@param lang_tree vim.treesitter.LanguageTree
---@param trees table<string, vim.treesitter.LanguageTree[]>
local function collect_injected_trees(lang_tree, trees)
  for lang, child_tree in pairs(lang_tree:children()) do
    if trees[lang] == nil then
      trees[lang] = {}
    end
    table.insert(trees[lang], child_tree)
    -- Recurse to find nested injections (e.g., JS inside HTML inside markdown)
    collect_injected_trees(child_tree, trees)
  end
end

---@class CodeChunk
---@field range { from: [integer, integer], to: [integer, integer] }
---@field lang string
---@field text string[]
---@field leading_offset number

---Extract code chunks from the specified buffer using treesitter language injection metadata.
---This uses the LanguageTree's built-in injection handling which automatically parses
---all injected languages after a full parse, including nested injections.
---@param main_nr integer The main buffer number
---@param target_lang string? language to extract. All languages if nil.
---@param exclude_eval_false boolean? Exclude code chunks with eval: false
---@param range_start_row integer? Row to start from, inclusive, 0-indexed.
---@param range_end_row integer? Row to end at, inclusive, 0-indexed.
---@return table<string, CodeChunk[]>
keeper.extract_code_chunks = function(main_nr, target_lang, exclude_eval_false, range_start_row, range_end_row)
  local parser = keeper.rafts[main_nr].parser
  -- Full parse to ensure all injections are processed
  parser:parse(true)

  ---@type table<string, CodeChunk[]>
  local code_chunks = {}

  ---@type table<string, vim.treesitter.LanguageTree[]>
  local lang_trees = {}
  collect_injected_trees(parser, lang_trees)

  -- Process each injected language
  for lang, tree in pairs(lang_trees) do
    -- Skip if we're filtering for a specific language and this isn't it
    if target_lang ~= nil and lang ~= target_lang then
      goto continue_lang
    end

    -- Skip if this language isn't in our injectable languages list
    if not fn.contains(injectable_languages, lang) then
      goto continue_lang
    end

    -- Process all trees for this language
    for _, lang_tree in ipairs(tree) do
      -- Get the regions where this language is injected
      -- included_regions returns a table mapping tree index to list of Range6
      -- Each Range6 is: { start_row, start_col, start_bytes, end_row, end_col, end_bytes }
      local regions = lang_tree:included_regions()

      -- Get buffer line count for bounds checking
      local line_count = api.nvim_buf_line_count(main_nr)

      for _, region_list in pairs(regions) do
        for _, region in ipairs(region_list) do
          local start_row, start_col, _, end_row, end_col, _ = unpack(region)

          -- Bounds checking: skip regions that are out of bounds
          -- This can happen when the parser has stale data during incomplete edits
          if start_row < 0 or end_row < 0 or start_row >= line_count or end_row >= line_count then
            goto continue_region
          end

          -- Clamp columns to valid ranges for the respective lines
          local start_line = api.nvim_buf_get_lines(main_nr, start_row, start_row + 1, false)[1] or ""
          local end_line = api.nvim_buf_get_lines(main_nr, end_row, end_row + 1, false)[1] or ""
          start_col = math.max(0, math.min(start_col, #start_line))
          end_col = math.max(0, math.min(end_col, #end_line))

          -- Get the text for this region from the main buffer
          local ok, lines = pcall(api.nvim_buf_get_text, main_nr, start_row, start_col, end_row, end_col, {})
          if not ok then
            -- Skip this region if we still can't get the text
            goto continue_region
          end
          if end_col == 0 and #lines > 0 and lines[#lines] == "" then
            table.remove(lines, #lines)
          end

          local result = {
            range = { from = { start_row, start_col }, to = { end_row, end_col } },
            lang = lang,
            text = lines,
          }

          if code_chunks[lang] == nil then
            code_chunks[lang] = {}
          end
          table.insert(code_chunks[lang], result)

          ::continue_region::
        end
      end
    end

    ::continue_lang::
  end

  -- Sort, merge, and normalize chunks by start position for each language
  for lang, chunks in pairs(code_chunks) do
    table.sort(chunks, function(a, b)
      if a.range.from[1] == b.range.from[1] then
        return a.range.from[2] < b.range.from[2]
      end
      return a.range.from[1] < b.range.from[1]
    end)

    local merged = {}
    for _, chunk in ipairs(chunks) do
      local last = merged[#merged]
      if last and chunk.range.from[1] == last.range.to[1] and chunk.range.from[2] == last.range.to[2] then
        if chunk.range.from[2] > 0 and #chunk.text > 0 and #last.text > 0 then
          last.text[#last.text] = last.text[#last.text] .. chunk.text[1]
          for i = 2, #chunk.text do
            table.insert(last.text, chunk.text[i])
          end
        else
          for _, line in ipairs(chunk.text) do
            table.insert(last.text, line)
          end
        end
        last.range.to = { chunk.range.to[1], chunk.range.to[2] }
      else
        table.insert(merged, chunk)
      end
    end

    local normalized = {}
    for _, chunk in ipairs(merged) do
      if range_start_row ~= nil and range_end_row ~= nil then
        if (chunk.range.from[1] >= range_end_row and range_end_row > 0) or chunk.range.to[1] < range_start_row then
          goto continue_chunk
        end
      end

      local text = table.concat(chunk.text, "\n")
      if exclude_eval_false and string.find(text, "| *eval: *false") then
        text = ""
      end

      local leading_offset
      text, leading_offset = trim_leading_whitespace(text)

      chunk.text = fn.lines(text)
      chunk.leading_offset = leading_offset
      table.insert(normalized, chunk)

      ::continue_chunk::
    end

    if #normalized > 0 then
      code_chunks[lang] = normalized
    else
      code_chunks[lang] = nil
    end
  end

  return code_chunks
end

--- Get the language context of a position using LanguageTree's built-in
--- language_for_range functionality which handles nested injections.
--- @param main_nr integer? bufnr of the parent buffer. Default is 0
--- @param position table? position (row, col). Default is the current cursor position (1,0)-based
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
  row = row - 1 -- Convert to 0-indexed

  local parser = keeper.rafts[main_nr].parser
  -- Ensure the tree is fully parsed including injections
  parser:parse(true)

  -- Use language_for_range to find the language at the cursor position
  -- This handles nested injections automatically
  local lang_tree = parser:language_for_range({ row, col, row, col })
  local lang = lang_tree:lang()

  -- Get the main buffer's language to check if we're in an injected region
  local main_lang = parser:lang()
  if lang == main_lang then
    -- We're in the main document, not in an injected region
    return nil
  end

  -- Check if this language is in our injectable languages list
  if not fn.contains(injectable_languages, lang) then
    return nil
  end

  -- Find the specific region containing this position
  local regions = lang_tree:included_regions()
  for _, region_list in pairs(regions) do
    for _, region in ipairs(region_list) do
      local start_row, start_col, _, end_row, end_col, _ = unpack(region)
      -- Check if position is within this region
      if row >= start_row and row <= end_row then
        local in_region = false
        if row == start_row and row == end_row then
          in_region = col >= start_col and col <= end_col
        elseif row == start_row then
          in_region = col >= start_col
        elseif row == end_row then
          in_region = col <= end_col
        else
          in_region = true
        end

        if in_region then
          -- Adjust end_col for leading whitespace handling if needed
          if OtterConfig.handle_leading_whitespace then
            local buf = keeper.rafts[main_nr].buffers[lang]
            if buf then
              local lines = vim.api.nvim_buf_get_lines(buf, end_row - 1, end_row, false)
              if lines[1] then
                end_col = #lines[1]
              end
            end
          end
          return lang, start_row, start_col, end_row - 1, end_col
        end
      end
    end
  end

  return nil
end

---find the leading_offset of the given line number, and buffer number. Returns 0 if the line number
---isn't in a chunk. When multiple chunks contain the line (nested injections), returns the offset
---of the innermost (smallest) chunk.
---@param line_nr number
---@param main_nr number
keeper.get_leading_offset = function(line_nr, main_nr)
  if not OtterConfig.handle_leading_whitespace then
    return 0
  end

  local lang_chunks = keeper.rafts[main_nr].code_chunks
  local best_match = nil
  local best_size = math.huge -- Size of the smallest matching chunk

  for _, chunks in pairs(lang_chunks) do
    for _, chunk in ipairs(chunks) do
      if line_nr >= chunk.range.from[1] and line_nr <= chunk.range.to[1] then
        -- Calculate chunk size (number of lines)
        local size = chunk.range.to[1] - chunk.range.from[1]
        if size < best_size then
          best_size = size
          best_match = chunk
        end
      end
    end
  end

  return best_match and best_match.leading_offset or 0
end

---adjusts IN PLACE the position to include the start and end
---@param obj table LSP request or response table
---@param main_nr number bufnr of the parent buffer
---@param invert boolean? whether to invert the offset (for requests vs responses)
---@param exclude_end boolean? whether to exclude adjusting the end position
---@param known_offset number? known offset to use instead of calculating it
keeper.modify_position = function(obj, main_nr, invert, exclude_end, known_offset)
  if not OtterConfig.handle_leading_whitespace or known_offset == 0 then
    return
  end

  local sign = invert and -1 or 1
  local offset = known_offset

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

  -- Handle InsertReplaceEdit format used by some LSP servers for completions
  -- InsertReplaceEdit has `insert` and `replace` ranges instead of `range`
  if obj.insert then
    offset = offset or keeper.get_leading_offset(obj.insert.start.line, main_nr) * sign
    obj.insert.start.character = obj.insert.start.character + offset
    if not exclude_end then
      obj.insert["end"].character = obj.insert["end"].character + offset
    end
  end

  if obj.replace then
    offset = offset or keeper.get_leading_offset(obj.replace.start.line, main_nr) * sign
    obj.replace.start.character = obj.replace.start.character + offset
    if not exclude_end then
      obj.replace["end"].character = obj.replace["end"].character + offset
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
    -- Get offset from range, insert, or replace (for InsertReplaceEdit compatibility)
    local range_for_offset = obj.range or obj.insert or obj.replace
    if range_for_offset then
      offset = offset or keeper.get_leading_offset(range_for_offset.start.line, main_nr) * sign
    end
    if offset and offset > 0 then
      local str = string.rep(" ", offset)
      -- Put indents in front of newline, but ignore newlines that are followed by newlines
      obj.newText = string.gsub(obj.newText, "(\n)([^\n])", "%1" .. str .. "%2")
      obj.newText = string.gsub(obj.newText, "\n$", "\n" .. str) -- match a potential newline at the end
    end
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
  --- NOTE: We may be able to get rid of this entirely in nvim v0.11
  local function do_with_maybe_texlock(callback)
    local texlock_err_msg = "E565: Not allowed to change text or change window"
    local success, result = pcall(callback)
    if success then
      return "success"
    end

    result = tostring(result)
    if result:match(texlock_err_msg) then
      vim.schedule(callback)
      return "textlock_active"
    else
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

        -- set preamble lines
        local preamble = keeper.rafts[main_nr].preambles[lang]
        for i, l in ipairs(preamble) do
          table.remove(ls, i)
          table.insert(ls, i, l)
        end

        -- Collect language lines.
        -- They are allowed to overwrite the preamble.
        -- Apply ignore_pattern filtering on read
        local pattern = keeper.rafts[main_nr].ignore_pattern[lang]
        for _, t in ipairs(code_chunks) do
          local start_index = t.range["from"][1]
          for i, l in ipairs(t.text) do
            local index = start_index + i
            if pattern == nil or not string.match(l, pattern) then
              ls[index] = l
            end
          end
        end

        -- set postamble lines
        local postamble = keeper.rafts[main_nr].postambles[lang]
        for _, l in ipairs(postamble) do
          table.insert(ls, l)
        end

        -- set code lines
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
    local extension = OtterConfig.extensions[lang] or lang
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
  row = row - 1 -- Convert to 0-indexed

  if keeper.rafts[main_nr] == nil then
    return nil
  end

  local parser = keeper.rafts[main_nr].parser
  -- Ensure the tree is fully parsed including injections
  parser:parse(true)

  -- Use language_for_range to find the language at the cursor position
  local lang_tree = parser:language_for_range({ row, col, row, col })
  local lang = lang_tree:lang()

  -- Get the main buffer's language to check if we're in an injected region
  local main_lang = parser:lang()
  if lang == main_lang then
    return nil
  end

  -- Check if this language is in our injectable languages list
  if not fn.contains(injectable_languages, lang) then
    return nil
  end

  -- Find the specific region containing this position and return its text
  local regions = lang_tree:included_regions()
  for _, region_list in pairs(regions) do
    for _, region in ipairs(region_list) do
      local start_row, start_col, _, end_row, end_col, _ = unpack(region)
      -- Check if position is within this region
      if row >= start_row and row <= end_row then
        local in_region = false
        if row == start_row and row == end_row then
          in_region = col >= start_col and col <= end_col
        elseif row == start_row then
          in_region = col >= start_col
        elseif row == end_row then
          in_region = col <= end_col
        else
          in_region = true
        end

        if in_region then
          local lines = api.nvim_buf_get_text(main_nr, start_row, start_col, end_row, end_col, {})
          return table.concat(lines, "\n")
        end
      end
    end
  end

  return nil
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
