describe("otter", function()
  before_each(function() end)

  it("can be required", function()
    local otter = require("otter")
    -- otter.activate({ 'r', 'python', 'lua' }, true)
    assert(otter ~= nil)
  end)
end)
