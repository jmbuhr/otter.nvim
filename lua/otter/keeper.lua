local M = {}
local lines = require 'otter.tools.functions'.lines
local spaces = require 'otter.tools.functions'.spaces
local path_to_otterpath = require 'otter.tools.functions'.path_to_otterpath
local otterpath_to_path = require 'otter.tools.functions'.otterpath_to_path
local otterpath_to_plain_path = require 'otter.tools.functions'.otterpath_to_plain_path
local queries = require 'otter.tools.queries'
local extensions = require 'otter.tools.extensions'
local api = vim.api
local ts = vim.treesitter


M._otters_attached = {}


local function extract_code_chunks(bufnr)
  -- get and parse AST
  local ft = api.nvim_buf_get_option(bufnr, 'filetype')
  local tsquery = queries[ft]
  local language_tree = ts.get_parser(bufnr, ft)
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()

  -- create capture
  local query = ts.parse_query(ft, tsquery)

  -- get text ranges
  local code_chunks = {}
  for pattern, match, metadata in query:iter_matches(root, bufnr) do
    local lang
    for id, node in pairs(match) do
      local name = query.captures[id]
      local text = ts.query.get_node_text(node, 0)
      if name == 'lang' then
        lang = text
      end
      if name == 'code' then
        local row1, col1, row2, col2 = node:range() -- range of the capture
        local result = {
          range = { from = { row1, col1 }, to = { row2, col2 } },
          lang = lang,
          text = lines(text)
        }
        if code_chunks[lang] == nil then
          code_chunks[lang] = {}
        end
        table.insert(code_chunks[lang], result)
      end
    end
  end

  return code_chunks
end

M.sync_raft = function(main_nr)
  local all_code_chunks = extract_code_chunks(main_nr)
  local otter_nrs = {}
  if M._otters_attached[main_nr] ~= nil then
    local languages = M._otters_attached[main_nr].languages
    for _, lang in ipairs(languages) do
      local code_chunks = all_code_chunks[lang]
      if code_chunks ~= nil then
        local nmax = code_chunks[#code_chunks].range['to'][1] -- last code line
        local main_path = api.nvim_buf_get_name(main_nr)

        -- create buffer filled with spaces
        local extension = extensions[lang]
        if extension ~= nil then
          local otter_path = path_to_otterpath(main_path, extension)
          local otter_uri = 'file://' .. otter_path
          local otter_nr = vim.uri_to_bufnr(otter_uri)
          table.insert(otter_nrs, otter_nr)
          api.nvim_buf_set_name(otter_nr, otter_path)
          api.nvim_buf_set_option(otter_nr, 'filetype', lang)
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
  return otter_nrs
end

M.sync_this_raft = function()
  M.sync_raft(api.nvim_get_current_buf())
end


M.activate = function(languages, completion)
  local main_bufnr = api.nvim_get_current_buf()

  M._otters_attached[main_bufnr] = {}
  M._otters_attached[main_bufnr].languages = languages
  local otter_nrs = M.sync_raft(main_bufnr)

  -- auto-close language files on qmd file close
  api.nvim_create_autocmd({ "QuitPre", "WinClosed" }, {
    buffer = 0,
    group = api.nvim_create_augroup("OtterAutoclose", {}),
    callback = function(_, _)
      for _, bufnr in ipairs(otter_nrs) do
        if api.nvim_buf_is_loaded(bufnr) then
          -- delete tmp file
          local path = api.nvim_buf_get_name(bufnr)
          vim.fn.delete(path)
          -- remove buffer
          api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end
  })

  if completion then
    for _, otter_nr in ipairs(otter_nrs) do
      require 'otter.completion'.setup_source(main_bufnr, otter_nr)
    end
  end
end




M.send_request = function(main_nr, request, filter)
  local otter_nrs = M.sync_raft(main_nr)
  for _, otter_nr in ipairs(otter_nrs) do
    local uri = vim.uri_from_bufnr(otter_nr)
    local position_params = vim.lsp.util.make_position_params(0)
    position_params.textDocument = {
      uri = uri
    }
    vim.lsp.buf_request(otter_nr, request, position_params, function(err, response, method, ...)
      if response ~= nil then
        if filter == nil then
          vim.lsp.handlers[request](err, response, method, ...)
        else
          -- if response is a list of responses, filter every response
          if #response > 0 then
            local responses = {}
            for _, res in ipairs(response) do
              table.insert(responses, filter(res))
            end
            response = responses
          else
            -- otherwise apply the filter to the one response
            response = filter(response)
          end
          vim.lsp.handlers[request](err, response, method, ...)
        end
      end
    end)
  end
end


M.export_raft = function(force)
  local main_nr = api.nvim_get_current_buf()
  local otter_nrs = M.sync_raft(main_nr)
  for _, otter_nr in ipairs(otter_nrs) do
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

return M
