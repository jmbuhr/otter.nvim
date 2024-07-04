local buf = 1

local ls = {
  'import math'
}

vim.api.nvim_buf_set_lines(buf, 2, -1, false, ls)

