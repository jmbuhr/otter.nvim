describe("otter", function()
  describe("module loading", function()
    it("can be required", function()
      local otter = require("otter")
      assert.is_not_nil(otter)
    end)

    it("exposes setup function", function()
      local otter = require("otter")
      assert.is_function(otter.setup)
    end)

    it("exposes activate function", function()
      local otter = require("otter")
      assert.is_function(otter.activate)
    end)

    it("exposes deactivate function", function()
      local otter = require("otter")
      assert.is_function(otter.deactivate)
    end)

    it("exposes sync_raft function", function()
      local otter = require("otter")
      assert.is_function(otter.sync_raft)
    end)

    it("exposes export function", function()
      local otter = require("otter")
      assert.is_function(otter.export)
    end)
  end)

  describe("keeper module", function()
    it("can be required", function()
      local keeper = require("otter.keeper")
      assert.is_not_nil(keeper)
    end)

    it("has rafts table", function()
      local keeper = require("otter.keeper")
      assert.is_table(keeper.rafts)
    end)

    it("exposes extract_code_chunks function", function()
      local keeper = require("otter.keeper")
      assert.is_function(keeper.extract_code_chunks)
    end)

    it("exposes get_current_language_context function", function()
      local keeper = require("otter.keeper")
      assert.is_function(keeper.get_current_language_context)
    end)

    it("exposes sync_raft function", function()
      local keeper = require("otter.keeper")
      assert.is_function(keeper.sync_raft)
    end)

    it("exposes has_raft function", function()
      local keeper = require("otter.keeper")
      assert.is_function(keeper.has_raft)
    end)
  end)

  describe("config", function()
    it("OtterConfig is available after requiring otter", function()
      require("otter")
      assert.is_not_nil(OtterConfig)
    end)

    it("has extensions table", function()
      require("otter")
      assert.is_table(OtterConfig.extensions)
    end)

    it("has common language extensions", function()
      require("otter")
      assert.equals("py", OtterConfig.extensions.python)
      assert.equals("lua", OtterConfig.extensions.lua)
      assert.equals("js", OtterConfig.extensions.javascript)
      assert.equals("R", OtterConfig.extensions.r)
    end)

    it("setup merges user config", function()
      local otter = require("otter")
      -- Reset did_setup to allow setup to run again
      otter.did_setup = nil
      otter.setup({
        extensions = {
          custom_lang = "cust",
        },
      })
      assert.equals("cust", OtterConfig.extensions.custom_lang)
    end)
  end)

  describe("tools/functions", function()
    local fn = require("otter.tools.functions")

    it("contains helper returns correct result", function()
      assert.is_true(fn.contains({ "a", "b", "c" }, "b"))
      assert.is_false(fn.contains({ "a", "b", "c" }, "d"))
    end)

    it("lines splits string correctly", function()
      local result = fn.lines("line1\nline2\nline3")
      assert.equals(3, #result)
      assert.equals("line1", result[1])
      assert.equals("line2", result[2])
      assert.equals("line3", result[3])
    end)

    it("empty_lines creates correct number of empty lines", function()
      local result = fn.empty_lines(5)
      assert.equals(5, #result)
      for _, line in ipairs(result) do
        assert.equals("", line)
      end
    end)

    it("path_to_otterpath creates correct path", function()
      local result = fn.path_to_otterpath("/path/to/file.md", ".py")
      assert.equals("/path/to/file.md.otter.py", result)
    end)

    it("is_otterpath identifies otter paths", function()
      assert.is_true(fn.is_otterpath("/path/file.md.otter.py"))
      assert.is_false(fn.is_otterpath("/path/file.md"))
    end)
  end)
end)
