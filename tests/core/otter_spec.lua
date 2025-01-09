describe("otter", function()
  before_each(function() end)

  it("can be required", function()
    local otter = require("otter")
    assert(otter ~= nil)
  end)
end)
