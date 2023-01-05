describe("otter", function()
  before_each(function()
  end)

  it("can be required", function()
    local otter = require("otter")
    -- otter.activate({ 'r', 'python', 'lua' }, true)
    assert(otter ~= nil)
    assert(otter.debug ~= nil)
  end)
  it("fails gracefully when it can't be activated", function()
    local otter = require("otter")
    assert.has_error(
      function() otter.activate({ 'r', 'python', 'lua' }, true) end,
      'No query found for this file type'
    )
  end)
  -- it("can activate on example markdown document", function()
  --   require'nvim-treesitter'.setup()
  --   vim.cmd.TSInstall 'markdown'
  --   print('hi')
  --
  --   vim.cmd.edit 'tests/examples/01.md'
  --   local otter = require("otter")
  --   otter.activate({ 'r', 'python', 'lua' }, true)
  -- end
  -- )
end)
