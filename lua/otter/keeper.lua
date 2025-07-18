--- The otter.keeep takes care of all the otters
--- attached to the main buffers.
--- Each main buffer is associated with a raft of
--- otter buffers and their respective languages
--- and code chunks
local keeper = {}

local fn = require("otter.tools.functions")
local api = vim.api
local ts = vim.treesitter

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


---@class CodeChunk
---@field range Range4
---@field lang string
---@field node TSNode
---@field lines string[]
---@field leading_offset number

---Extract code chunks from the specified buffer.
---@param main_nr integer The main buffer number
---@param lang string? language to extract. All languages if nil.
---@param exclude_eval_false boolean? Exclude code chunks with eval: false
---@param range_start_row integer? Row to start from, inclusive, 1-indexed.
---@param range_end_row integer? Row to end at, inclusive, 1-indexed.
---@return table<string, CodeChunk[]>
keeper.extract_code_chunks = function(main_nr, lang, exclude_eval_false, range_start_row, range_end_row)
  local parser = keeper.rafts[main_nr].parser

  -- parse everythion to include injections
  ---@type Range2|boolean
  local parse_range = range_start_row == nil or range_end_row == nil or { range_start_row, range_end_row }

  local tree = parser:parse(parse_range)[1]
  assert(tree, "[otter] Treesitter failed to parse buffer " .. main_nr)

  ---@type table<string, vim.treesitter.LanguageTree>
  local trees = {}
  local lang_to_tree = parser:children()
  for l, t in pairs(lang_to_tree) do
    if l ~= "markdown_inline" and (lang == nil or l == lang) then
      -- we don't need the markdown_inline chunks
      -- that's more like a helper language to markdown
      trees[l] = t
      -- TODO: check if that also has children
    end
  end

  if trees == {} then
    return {}
  end

  ---@type table<string, CodeChunk[]>
  local code_chunks = {}
  -- get all top level nodes for each language
  -- no need for a query here,
  -- since injections are already parsed
  for l, langtree in pairs(trees) do
    code_chunks[l] = {}

    local subtrees = langtree:trees()
    for _, subtree in ipairs(subtrees) do
      local root = subtree:root()
      local text = ts.get_node_text(root, main_nr)
      if exclude_eval_false and string.find(text, "#%| *eval: *false") then
        goto continue
      end
      local start_row, start_col, end_row, end_col = root:range()
      local range = { start_row, start_col, end_row, end_col }
      local lines = fn.lines(text)
      local first_line = lines[1]
      if first_line == nil then
        goto continue
      end

      local offset = start_col
      local leading_whitespace = first_line:match("^%s*")

      if #leading_whitespace > 0 then
        offset = #leading_whitespace
        lines[1] = lines[1]:sub(offset + 1)
      end

      if offset > 0 then
        local new_lines = {}
        table.insert(new_lines, lines[1])
        for i = 2, #lines do
          lines[i] = lines[i]:sub(offset + 1)
        end
      end

      ---@type CodeChunk
      local chunk = {
        range = range,
        lang = l,
        node = root,
        lines = lines,
        leading_offset = offset,
      }
      table.insert(code_chunks[l], chunk)
      ::continue::
    end
  end

  return code_chunks
end

--- Get the language context of a position
--- @param main_nr integer? bufnr of the parent buffer. Default is 0
--- @param position table? position (row, col). Default is the current cursor position (1,0)-based
--- @return string? language nil if no language context is found
keeper.get_current_language_context = function(main_nr, position)
  main_nr = main_nr or api.nvim_get_current_buf()
  position = position or api.nvim_win_get_cursor(0)
  if keeper.rafts[main_nr] == nil then
    return nil
  end
  local row, col = unpack(position)
  row = row - 1
  col = col
  local range = { row, col, row, col }

  local lang = keeper.rafts[main_nr].parser:language_for_range(range):lang()
  if lang == "" then
    return nil
  end
  return lang
end

---find the leading_offset of the given line number, and buffer number. Returns 0 if the line number
---isn't in a chunk.
---@param line_nr number
---@param main_nr number
keeper.get_leading_offset = function(line_nr, main_nr)
  local lang_chunks = keeper.rafts[main_nr].code_chunks
  for _, chunks in pairs(lang_chunks) do
    for _, chunk in ipairs(chunks) do
      if line_nr >= chunk.range[1] and line_nr <= chunk.range[3] then
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
  if known_offset == 0 then
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
        local nmax = code_chunks[#code_chunks].range[3] -- last code line

        -- create list with empty lines the length of the buffer
        local ls = fn.empty_lines(nmax)

        -- set preamble lines
        local preamble = keeper.rafts[main_nr].preambles[lang]
        for i, l in ipairs(preamble) do
          table.remove(ls, i)
          table.insert(ls, i, l)
        end

        -- collect language lines
        -- are allowed to overwrite the preamble
        -- apply ignore_pattern filtering on read
        local pattern = keeper.rafts[main_nr].ignore_pattern[lang]
        for _, t in ipairs(code_chunks) do
          local start_index = t.range[1]
          for i, l in ipairs(t.lines) do
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

  local chunks = keeper.rafts[main_nr].code_chunks[lang]
  if not chunks or next(chunks) == nil then
    return
  end
  local code = {}
  for _, c in ipairs(chunks) do
    table.insert(code, fn.concat(c.lines))
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
  local trees = parser:parse()
  assert(trees, "[otter] Treesitter failed to parse buffer " .. main_nr)
  local tree = trees[1]
  local root = tree:root()

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
