local M = {}
local lines = require 'otter.tools.functions'.lines
local empty_lines = require 'otter.tools.functions'.empty_lines
local path_to_otterpath = require 'otter.tools.functions'.path_to_otterpath
local otterpath_to_plain_path = require 'otter.tools.functions'.otterpath_to_plain_path
local get_current_language_context = require 'otter.tools.functions'.get_current_language_context
local contains = require'otter.tools.functions'.contains
local queries = require 'otter.tools.queries'
local extensions = require 'otter.tools.extensions'
local api = vim.api
local ts = vim.treesitter
local tsq = require'nvim-treesitter.query'

local injectable_languages = {
  'html', 'js', 'css'
}


M._otters_attached = {}


---Extract code chunks from the specified buffer.
---@param main_nr integer The main buffer number
---@param lang string|nil language to extract. All languages if nil.
---@return table
local function extract_code_chunks(main_nr, lang, injectable)
  injectable = injectable or injectable_languages
  local main_ft = api.nvim_buf_get_option(main_nr, 'filetype')
  local parsername = vim.treesitter.language.get_lang(main_ft)
  if parsername == nil then return {} end
  local parser = ts.get_parser(main_nr, parsername)
  local query = tsq.get_query(parsername, 'injections')
  local tree = parser:parse()
  local root = tree[1]:root()

  local code_chunks = {}
  local found_chunk = false
  local lang_capture
  for id, node, metadata in query:iter_captures(root, main_nr) do
    local name = query.captures[id]
    local text

    -- chunks where the name of the injected language is dynamic
    -- e.g. markdown code chunks
    if name == '_lang' then
      text = ts.get_node_text(node, main_nr, metadata)
      lang_capture = text
      found_chunk = true
    end
    if name == 'content' and found_chunk and (lang == nil or lang_capture == lang) then
      text = ts.get_node_text(node, main_nr, metadata)
      local row1, col1, row2, col2 = node:range()
      local result = {
        range = { from = { row1, col1 }, to = { row2, col2 } },
        lang = lang_capture,
        text = lines(text)
      }
      if code_chunks[lang_capture] == nil then
        code_chunks[lang_capture] = {}
      end
      table.insert(code_chunks[lang_capture], result)
      found_chunk = false
    end

    -- chunks where the name of the language is the name of the capture
    if contains(injectable, name) then
      if (lang == nil or name == lang) then
        text = ts.get_node_text(node, main_nr, metadata)
        local row1, col1, row2, col2 = node:range()
        local result = {
          range = { from = { row1, col1 }, to = { row2, col2 } },
          lang = name,
          text = lines(text)
        }
        if code_chunks[name] == nil then
          code_chunks[name] = {}
        end
        table.insert(code_chunks[name], result)
      end
    end

  end

  return code_chunks
end

--- Syncronize the raft of otters attached to a buffer
---@param main_nr integer
M.sync_raft = function(main_nr)
  -- return early if buffer content has not changed

  local tick = vim.api.nvim_buf_get_changedtick(main_nr)
  local ottertick = vim.api.nvim_buf_get_var(main_nr, 'ottertick')
  if ottertick == tick then
    return
  end
  vim.api.nvim_buf_set_var(main_nr, 'ottertick', tick)


  local all_code_chunks = extract_code_chunks(main_nr)
  if next(all_code_chunks) == nil then
    return {}
  end
  if M._otters_attached[main_nr] ~= nil then
    local languages = M._otters_attached[main_nr].languages
    for _, lang in ipairs(languages) do
      local otter_nr = M._otters_attached[main_nr].buffers[lang]
      local code_chunks = all_code_chunks[lang]
      if code_chunks ~= nil then
        local nmax = code_chunks[#code_chunks].range['to'][1] -- last code line

        -- create list with empty lines the lenght of the buffer
        local ls = empty_lines(nmax)

        -- write language lines
        for _, t in ipairs(code_chunks) do
          local start_index = t.range['from'][1]
          for i, l in ipairs(t.text) do
            local index = start_index + i
            table.remove(ls, index)
            table.insert(ls, index, l)
          end
        end

        -- vim.print(ls)

        -- clear buffer
        api.nvim_buf_set_lines(otter_nr, 0, -1, false, {})

        -- add language lines
        api.nvim_buf_set_lines(otter_nr, 0, nmax, false, ls)
      end
    end
  end
end

--- Syncronize the raft for the current buffer.
M.sync_this_raft = function()
  M.sync_raft(api.nvim_get_current_buf())
end


--- Activate the current buffer by adding and syncronizing
--- otter buffers.
---@param languages table
---@param completion boolean
---@param tsqueries table|nil
M.activate = function(languages, completion, tsqueries)
  local main_nr = api.nvim_get_current_buf()
  local main_path = api.nvim_buf_get_name(main_nr)

  -- merge supplied queries with pre-installed ones
  queries = vim.tbl_deep_extend('force', queries, tsqueries or {})

  -- test if we have a query for the main language
  assert(queries[vim.bo[main_nr].filetype] ~= nil, 'No query found for this file type')
  M._otters_attached[main_nr] = {}

  local all_code_chunks = extract_code_chunks(main_nr)
  M._otters_attached[main_nr].languages = languages
  M._otters_attached[main_nr].buffers = {}

  -- create otter buffers
  for _, lang in ipairs(languages) do
    local extension = extensions[lang]
    if extension == nil then goto continue end
    local code_chunks = all_code_chunks[lang]
    if code_chunks == nil then goto continue end
    local otter_path = path_to_otterpath(main_path, extension)
    local otter_uri = 'file://' .. otter_path
    local otter_nr = vim.uri_to_bufnr(otter_uri)
    api.nvim_buf_set_name(otter_nr, otter_path)
    api.nvim_buf_set_option(otter_nr, 'swapfile', false)
    api.nvim_buf_set_option(otter_nr, 'buftype', 'nowrite')
    M._otters_attached[main_nr].buffers[lang] = otter_nr
    ::continue::
  end

  vim.api.nvim_buf_set_var(main_nr, 'ottertick', 0)
  M.sync_raft(main_nr)

  for lang, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
    api.nvim_buf_set_option(otter_nr, 'filetype', lang)
  end

  if completion then
    for _, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
      require 'otter.completion'.setup_source(main_nr, otter_nr, queries)
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
  filter = filter or function(x) return x end
  M.sync_raft(main_nr)

  local lang = get_current_language_context()
  if lang == nil and fallback then
    fallback()
    return
  end

  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  local otter_uri = vim.uri_from_bufnr(otter_nr)
  local params = vim.lsp.util.make_position_params()
  -- general
  params.textDocument = {
    uri = otter_uri
  }
  if request == 'textDocument/references' then
    params.context =  {
      includeDeclaration = true,
    }
  end
  -- for 'textDocument/rename'
  if request == 'textDocument/rename' then
    local cword = vim.fn.expand('<cword>')
    local prompt_opts = {
      prompt = 'New Name: ',
      default = cword
    }
    vim.ui.input(prompt_opts, function (input)
      params.newName = input
    end)
  end

  vim.lsp.buf_request(otter_nr, request, params, function(err, response, method, ...)
    if response == nil then return nil end
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
    if handler ~= nil then
      handler(err, response, method, conf)
    else
      vim.lsp.handlers[request](err, response, method, ...)
    end
  end
  )
end


--- Export the raft of otters as files.
--- Asks for filename for each language.
---@param force boolean
M.export_raft = function(force)
  local main_nr = api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  for _, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
    local path = api.nvim_buf_get_name(otter_nr)
    local lang = api.nvim_buf_get_option(otter_nr, 'filetype')
    local extension = extensions[lang] or ''
    path = otterpath_to_plain_path(path) .. extension
    print('Exporting otter: ' .. lang)
    local new_path = vim.fn.input('New path: ', path, 'file')
    if new_path ~= '' then
      api.nvim_set_current_buf(otter_nr)
      vim.lsp.buf.format({ bufnr = otter_nr })
      vim.cmd.write { new_path, bang = force }
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
    local lang = api.nvim_buf_get_option(otter_nr, 'filetype')
    if lang ~= language then return end
    path = path:match("(.*[/\\])") .. fname
    api.nvim_set_current_buf(otter_nr)
    vim.lsp.buf.format()
    vim.cmd.write { path, bang = force }
    api.nvim_set_current_buf(main_nr)
  end
end


local function get_code_chunks_with_eval_true(main_nr, lang, row_from, row_to)
  local ft = api.nvim_buf_get_option(main_nr, 'filetype')
  local tsquery = queries[ft]
  local parsername = vim.treesitter.language.get_lang(ft)
  local language_tree = ts.get_parser(main_nr, parsername)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  -- create capture
  local query = vim.treesitter.query.parse(parsername, tsquery)

  -- get text ranges
  local code = {}
  for pattern, match, metadata in query:iter_matches(root, main_nr) do
    local lang_capture
    for id, node in pairs(match) do
      local name = query.captures[id]
      local text = vim.treesitter.get_node_text(node, 0)
      if name == 'lang' then
        lang_capture = text
      end
      if name == 'code' and lang_capture == lang then
        local row_start, col1, row_end, col2 = node:range()
        if row_from ~= nil and row_to ~= nil then
          if (row_start >= row_to and row_to > 0) or row_end < row_from then
            goto continue
          end
        end
        if string.find(text, '#| *eval: *false') then
          goto continue
        end
        table.insert(code, text)
      end
      ::continue::
    end
  end

  return code
end


M.get_language_lines_to_cursor = function(include_eval_false)
  local main_nr = vim.api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  local lang = get_current_language_context()
  if lang == nil then
    return
  end
  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  if include_eval_false then
    return vim.api.nvim_buf_get_lines(otter_nr, 0, row + 2, false)
  end
  return get_code_chunks_with_eval_true(main_nr, lang, 0, row + 2)
end

M.get_language_lines_from_cursor = function(include_eval_false)
  local main_nr = vim.api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  local lang = get_current_language_context()
  if lang == nil then
    return
  end
  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  if include_eval_false then
    return vim.api.nvim_buf_get_lines(otter_nr, row, -1, false)
  end
  return get_code_chunks_with_eval_true(main_nr, lang, row, -1)
end


M.get_language_lines = function(include_eval_false)
  local main_nr = vim.api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  local lang = get_current_language_context()
  if lang == nil then
    return
  end
  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  if include_eval_false then
    return vim.api.nvim_buf_get_lines(otter_nr, 0, -1, false)
  end
  return get_code_chunks_with_eval_true(main_nr, lang)
end

M.get_language_lines_in_visual_selection = function(include_eval_false)
  local main_nr = vim.api.nvim_get_current_buf()
  M.sync_raft(main_nr)
  local lang = get_current_language_context()
  if lang == nil then
    return
  end
  local otter_nr = M._otters_attached[main_nr].buffers[lang]
  local row_start, _ = unpack(api.nvim_buf_get_mark(main_nr, '<'))
  local row_end, _ = unpack(api.nvim_buf_get_mark(main_nr, '>'))
  row_start = row_start - 1
  row_end = row_end - 1
  if include_eval_false then
    return vim.api.nvim_buf_get_lines(otter_nr, row_start, row_end + 2, false)
  end
  return get_code_chunks_with_eval_true(main_nr, lang, row_start, row_end + 2)
end

return M
