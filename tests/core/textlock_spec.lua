-- Tests for sync_raft while textlock is active (E565), as in <C-x><C-o> with vim.lsp.omnifunc
local api = vim.api

require("otter").setup({})

local keeper = require("otter.keeper")

describe("sync_raft under textlock", function()
  local path, main_nr, otter_nr
  local scheduled = {}

  -- Call sync_raft from an <expr> mapping, where textlock blocks writing the otter buffer.
  -- Hold back what it schedules, so each test decides what happens before the retry runs.
  local function sync_in_textlock()
    local result
    vim.keymap.set("n", "<Plug>(otter-test-textlock)", function()
      result = keeper.sync_raft(main_nr, "lua")
      return ""
    end, { expr = true, buffer = main_nr })
    local schedule = vim.schedule
    vim.schedule = function(fn)
      table.insert(scheduled, fn)
    end
    local ok, err = pcall(api.nvim_feedkeys, vim.keycode("<Plug>(otter-test-textlock)"), "x", false)
    vim.schedule = schedule
    assert(ok, err)
    return result
  end

  local function run_scheduled()
    local fns = scheduled
    scheduled = {}
    for _, fn in ipairs(fns) do
      fn()
    end
  end

  local function set_line(text)
    api.nvim_buf_set_lines(main_nr, 4, 5, false, { text })
  end

  local function otter_line()
    return api.nvim_buf_get_lines(otter_nr, 4, 5, false)[1]
  end

  before_each(function()
    scheduled = {}
    path = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ "# Title", "", "```lua", "local alpha_value = 1", "print(alpha_value)", "```" }, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    main_nr = api.nvim_get_current_buf()
    require("otter").activate({ "lua" }, false, false)
    otter_nr = keeper.rafts[main_nr].buffers.lua
    assert.are.equal("print(alpha_value)", otter_line())
  end)

  after_each(function()
    if api.nvim_buf_is_valid(main_nr) then
      api.nvim_set_current_buf(main_nr)
      require("otter").deactivate()
      api.nvim_buf_delete(main_nr, { force = true })
    end
    vim.fn.delete(path)
  end)

  it("syncs the current text once textlock is lifted", function()
    set_line("print(alpha_valu)")
    assert.are.equal("textlock_active", sync_in_textlock())
    -- Edited again, without a sync, before the retry runs
    set_line("print(alpha_val)")
    run_scheduled()
    assert.are.equal("print(alpha_val)", otter_line())
  end)

  it("does not overwrite a newer sync with the text from the textlock", function()
    set_line("print(alpha_valu)")
    assert.are.equal("textlock_active", sync_in_textlock())
    set_line("print(alpha_val)")
    assert.are.equal("success", keeper.sync_raft(main_nr, "lua"))
    run_scheduled()
    assert.are.equal("print(alpha_val)", otter_line())
    assert.are.equal("success", keeper.sync_raft(main_nr, "lua"))
    assert.are.equal("print(alpha_val)", otter_line())
  end)

  it("does nothing once the main buffer is wiped", function()
    set_line("print(alpha_valu)")
    assert.are.equal("textlock_active", sync_in_textlock())
    vim.cmd("bwipeout! " .. main_nr)
    assert.is_false(api.nvim_buf_is_valid(otter_nr))
    assert.has_no.errors(run_scheduled)
  end)
end)
