local M = {}
local lines = require 'otter.tools.functions'.lines
local spaces = require 'otter.tools.functions'.spaces
local path_to_otterpath = require 'otter.tools.functions'.path_to_otterpath
local otterpath_to_plain_path = require 'otter.tools.functions'.otterpath_to_plain_path
local is_otter_context = require 'otter.tools.functions'.is_otter_context
local queries = require 'otter.tools.queries'
local extensions = require 'otter.tools.extensions'
local api = vim.api
local ts = vim.treesitter
local handlers = require 'otter.tools.handlers'
local config = require 'otter.config'.config


M._otters_attached = {}

---Extract code chunks from the specified buffer.
---@param main_nr integer The main buffer number
---@param lang string|nil
---@return table
local function extract_code_chunks(main_nr, lang)
  -- get and parse AST
  local ft = api.nvim_buf_get_option(main_nr, 'filetype')
  local tsquery = queries[ft]
  local parsername = vim.treesitter.language.get_lang(ft)
  local language_tree = ts.get_parser(main_nr, parsername)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  -- create capture
  local query = vim.treesitter.query.parse(parsername, tsquery)

  -- get text ranges
  local code_chunks = {}
  for pattern, match, metadata in query:iter_matches(root, main_nr) do
    local lang_capture
    for id, node in pairs(match) do
      local name = query.captures[id]
      local text = vim.treesitter.get_node_text(node, 0)
      if name == 'lang' then
        lang_capture = text
      end
      if name == 'code' and (lang == nil or lang_capture == lang) then
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
      end
    end
  end

  return code_chunks
end

--- Syncronize the raft of otters attached to a buffer
---@param main_nr integer
M.sync_raft = function(main_nr)
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

        -- fill buffer with spaces
        api.nvim_buf_set_lines(otter_nr, 0, -1, false, {})
        api.nvim_buf_set_lines(otter_nr, 0, nmax, false, spaces(nmax))

        -- write language lines
        for _, t in ipairs(code_chunks) do
          api.nvim_buf_set_lines(otter_nr, t.range['from'][1], t.range['to'][1], false, t.text)
        end
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
    api.nvim_buf_set_option(otter_nr, 'filetype', lang)
    api.nvim_buf_set_option(otter_nr, 'swapfile', false)
    M._otters_attached[main_nr].buffers[lang] = otter_nr
    ::continue::
  end

  M.sync_raft(main_nr)

  -- auto-close language files on qmd file close
  api.nvim_create_autocmd({ "QuitPre", "BufDelete" }, {
    buffer = 0,
    group = api.nvim_create_augroup("OtterAutoclose", {}),
    callback = function(_, _)
      for _, bufnr in pairs(M._otters_attached[main_nr].buffers) do
        if api.nvim_buf_is_valid(bufnr) then
          -- delete otter buffer file
          local path = api.nvim_buf_get_name(bufnr)
          vim.fn.delete(path)
          -- remove otter buffer
          api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end
  })

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
---@param filter function function to process the response
---@param fallback function|nil optional funtion to call if not in an otter context
M.send_request = function(main_nr, request, filter, fallback)
  fallback = fallback or nil
  M.sync_raft(main_nr)
  local ft = api.nvim_buf_get_option(main_nr, 'filetype')
  local tsquery = queries[ft]

  if not is_otter_context(main_nr, tsquery) and fallback then
    fallback()
    return
  end

  for _, otter_nr in pairs(M._otters_attached[main_nr].buffers) do
    local uri = vim.uri_from_bufnr(otter_nr)
    local position_params = vim.lsp.util.make_position_params(0)
    position_params.textDocument = {
      uri = uri
    }
    vim.lsp.buf_request(otter_nr, request, position_params, function(err, response, method, ...)
      if response == nil then return nil end
      if filter == nil then
        vim.lsp.handlers[request](err, response, method, ...)
      else
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
        if request == 'textDocument/hover' or request == 'textDocument/signatureHelp' then
          handlers.hover(err, response, method, config.lsp.hover)
        else
          vim.lsp.handlers[request](err, response, method, ...)
        end
      end
    end
    )
  end
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
      vim.lsp.buf.format()
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

return M
