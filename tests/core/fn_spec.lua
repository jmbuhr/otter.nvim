local assert = require("luassert")

describe("otter util functions", function()
  before_each(function() end)

  it("can split lines", function()
    local fn = require("otter.tools.functions")

    local str_result = {
      ["hello"] = { "hello" },
      ["hello\nworld"] = { "hello", "world" },
    }

    for str, result in pairs(str_result) do
      local lines = fn.lines(str)
      assert.are.same(result, lines)
    end

  end)
end)
