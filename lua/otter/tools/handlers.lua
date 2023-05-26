local util = require('vim.lsp.util')
local api = vim.api
local validate = vim.validate
local apply_workspace_edit = require('vim.lsp.util').apply_workspace_edit

local M = {}
function M.hover(_, result, ctx, config)
  config = config or {}
  config.focus_id = ctx.method
  -- don't ignore hover responses from other buffers
  if not (result and result.contents) then
    vim.notify('No information available')
    return
  end
  local markdown_lines = util.convert_input_to_markdown_lines(result.contents)
  markdown_lines = util.trim_empty_lines(markdown_lines)
  if vim.tbl_isempty(markdown_lines) then
    vim.notify('No information available')
    return
  end

  -- returns bufnr,winnr buffer and window number of the newly created floating
  local bufnr, _ = util.open_floating_preview(markdown_lines, 'markdown', config)

  -- local bufnr, _ = util.open_floating_preview(markdown_lines, '', config)
  -- vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')

  return result
end

--- Applies a list of text edits to a buffer.
---@param text_edits table list of `TextEdit` objects
---@param bufnr number Buffer id
---@param offset_encoding string utf-8|utf-16|utf-32
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textEdit
function M.apply_text_edits(text_edits, bufnr, offset_encoding)
  validate({
    text_edits = { text_edits, 't', false },
    bufnr = { bufnr, 'number', false },
    offset_encoding = { offset_encoding, 'string', false },
  })
  if not next(text_edits) then
    return
  end
  if not api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end
  api.nvim_buf_set_option(bufnr, 'buflisted', true)

  -- Fix reversed range and indexing each text_edits
  local index = 0
  text_edits = vim.tbl_map(function(text_edit)
    index = index + 1
    text_edit._index = index

    if
        text_edit.range.start.line > text_edit.range['end'].line
        or text_edit.range.start.line == text_edit.range['end'].line
        and text_edit.range.start.character > text_edit.range['end'].character
    then
      local start = text_edit.range.start
      text_edit.range.start = text_edit.range['end']
      text_edit.range['end'] = start
    end
    return text_edit
  end, text_edits)

  -- Sort text_edits
  table.sort(text_edits, function(a, b)
    if a.range.start.line ~= b.range.start.line then
      return a.range.start.line > b.range.start.line
    end
    if a.range.start.character ~= b.range.start.character then
      return a.range.start.character > b.range.start.character
    end
    if a._index ~= b._index then
      return a._index > b._index
    end
  end)

  -- Some LSP servers are depending on the VSCode behavior.
  -- The VSCode will re-locate the cursor position after applying TextEdit so we also do it.
  local is_current_buf = api.nvim_get_current_buf() == bufnr
  local cursor = (function()
    if not is_current_buf then
      return {
        row = -1,
        col = -1,
      }
    end
    local cursor = api.nvim_win_get_cursor(0)
    return {
      row = cursor[1] - 1,
      col = cursor[2],
    }
  end)()

  -- Apply text edits.
  local is_cursor_fixed = false
  local has_eol_text_edit = false
  for _, text_edit in ipairs(text_edits) do
    -- Normalize line ending
    text_edit.newText, _ = string.gsub(text_edit.newText, '\r\n?', '\n')

    -- Convert from LSP style ranges to Neovim style ranges.
    local e = {
      start_row = text_edit.range.start.line,
      start_col = get_line_byte_from_position(bufnr, text_edit.range.start, offset_encoding),
      end_row = text_edit.range['end'].line,
      end_col = get_line_byte_from_position(bufnr, text_edit.range['end'], offset_encoding),
      text = split(text_edit.newText, '\n', true),
    }

    local max = api.nvim_buf_line_count(bufnr)
    -- If the whole edit is after the lines in the buffer we can simply add the new text to the end
    -- of the buffer.
    if max <= e.start_row then
      api.nvim_buf_set_lines(bufnr, max, max, false, e.text)
    else
      local last_line_len = #(get_line(bufnr, math.min(e.end_row, max - 1)) or '')
      -- Some LSP servers may return +1 range of the buffer content but nvim_buf_set_text can't
      -- accept it so we should fix it here.
      if max <= e.end_row then
        e.end_row = max - 1
        e.end_col = last_line_len
        has_eol_text_edit = true
      else
        -- If the replacement is over the end of a line (i.e. e.end_col is out of bounds and the
        -- replacement text ends with a newline We can likely assume that the replacement is assumed
        -- to be meant to replace the newline with another newline and we need to make sure this
        -- doesn't add an extra empty line. E.g. when the last line to be replaced contains a '\r'
        -- in the file some servers (clangd on windows) will include that character in the line
        -- while nvim_buf_set_text doesn't count it as part of the line.
        if
            e.end_col > last_line_len
            and #text_edit.newText > 0
            and string.sub(text_edit.newText, -1) == '\n'
        then
          table.remove(e.text, #e.text)
        end
      end
      -- Make sure we don't go out of bounds for e.end_col
      e.end_col = math.min(last_line_len, e.end_col)

      api.nvim_buf_set_text(bufnr, e.start_row, e.start_col, e.end_row, e.end_col, e.text)

      -- Fix cursor position.
      local row_count = (e.end_row - e.start_row) + 1
      if e.end_row < cursor.row then
        cursor.row = cursor.row + (#e.text - row_count)
        is_cursor_fixed = true
      elseif e.end_row == cursor.row and e.end_col <= cursor.col then
        cursor.row = cursor.row + (#e.text - row_count)
        cursor.col = #e.text[#e.text] + (cursor.col - e.end_col)
        if #e.text == 1 then
          cursor.col = cursor.col + e.start_col
        end
        is_cursor_fixed = true
      end
    end
  end

  local max = api.nvim_buf_line_count(bufnr)

  -- Apply fixed cursor position.
  if is_cursor_fixed then
    local is_valid_cursor = true
    is_valid_cursor = is_valid_cursor and cursor.row < max
    is_valid_cursor = is_valid_cursor and cursor.col <= #(get_line(bufnr, max - 1) or '')
    if is_valid_cursor then
      api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
    end
  end

  -- Remove final line if needed
  local fix_eol = has_eol_text_edit
  fix_eol = fix_eol
      and (
      api.nvim_buf_get_option(bufnr, 'eol')
      or (api.nvim_buf_get_option(bufnr, 'fixeol') and not api.nvim_buf_get_option(bufnr, 'binary'))
      )
  fix_eol = fix_eol and get_line(bufnr, max - 1) == ''
  if fix_eol then
    api.nvim_buf_set_lines(bufnr, -2, -1, false, {})
  end
end

--- Applies a `TextDocumentEdit`, which is a list of changes to a single
--- document.
---
---@param text_document_edit table: a `TextDocumentEdit` object
---@param index number: Optional index of the edit, if from a list of edits (or nil, if not from a list)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentEdit
function M.apply_text_document_edit(text_document_edit, index, offset_encoding)
  local text_document = text_document_edit.textDocument
  local bufnr = vim.uri_to_bufnr(text_document.uri)
  if offset_encoding == nil then
    vim.notify_once(
      'apply_text_document_edit must be called with valid offset encoding',
      vim.log.levels.WARN
    )
  end

  -- For lists of text document edits,
  -- do not check the version after the first edit.
  local should_check_version = true
  if index and index > 1 then
    should_check_version = false
  end

  -- `VersionedTextDocumentIdentifier`s version may be null
  --  https://microsoft.github.io/language-server-protocol/specification#versionedTextDocumentIdentifier
  if
      should_check_version
      and (
      text_document.version
      and text_document.version > 0
      and M.buf_versions[bufnr]
      and M.buf_versions[bufnr] > text_document.version
      )
  then
    print('Buffer ', text_document.uri, ' newer than edits.')
    return
  end

  M.apply_text_edits(text_document_edit.edits, bufnr, offset_encoding)
end

M.rename = function(_, result, ctx, _)
  P('hi')
  P(result)
  if not result then
    vim.notify("Language server couldn't provide rename result", vim.log.levels.INFO)
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  apply_workspace_edit(result, client.offset_encoding)
end


return M
