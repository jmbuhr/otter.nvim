M = {}

M.iter_captures = function (node, source, query)
  if type(source) == "number" and source == 0 then
    source = vim.api.nvim_get_current_buf()
  end

  local raw_iter = node:_rawquery(query.query, true, 0, -1)
  local metadata = {}
  local function iter(end_line)
    local capture, captured_node, match = raw_iter()

    if match ~= nil then
      local active = query:match_preds(match, match.pattern, source)
      match.active = active
      if not active then
        return iter(end_line) -- tail call: try next match
      else
        -- if it has an active match, reset the metadata.
        -- then hopefully apply_directives can fill the metadata
        metadata = {}
      end
      query:apply_directives(match, match.pattern, source, metadata)
    end
    return capture, captured_node, metadata
  end
  return iter
end


return M
