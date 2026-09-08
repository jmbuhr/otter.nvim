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

    describe("deactivate lsp shutdown", function()
      it("uses client:stop and avoids detach when already detached", function()
        local otter = require("otter")
        local keeper = require("otter.keeper")
        local api = vim.api

        local bufnr = api.nvim_create_buf(false, true)
        api.nvim_set_current_buf(bufnr)
        keeper.rafts[bufnr] = {
          buffers = {},
          diagnostics_namespaces = {},
          diagnostics_group = nil,
          otterls = { client_id = 42 },
        }

        local orig_get_client_by_id = vim.lsp.get_client_by_id
        local orig_stop_client = vim.lsp.stop_client
        local orig_buf_is_attached = vim.lsp.buf_is_attached
        local orig_buf_detach_client = vim.lsp.buf_detach_client

        local stop_called = false
        local deprecated_called = false
        local detach_called = false

        vim.lsp.get_client_by_id = function(id)
          if id ~= 42 then
            return nil
          end
          return {
            stop = function(_, force)
              stop_called = force == true
            end,
          }
        end
        vim.lsp.stop_client = function()
          deprecated_called = true
        end
        vim.lsp.buf_is_attached = function(_, _)
          return false
        end
        vim.lsp.buf_detach_client = function(_, _)
          detach_called = true
        end

        local ok, err = pcall(function()
          otter.deactivate(false, false)
        end)

        vim.lsp.get_client_by_id = orig_get_client_by_id
        vim.lsp.stop_client = orig_stop_client
        vim.lsp.buf_is_attached = orig_buf_is_attached
        vim.lsp.buf_detach_client = orig_buf_detach_client

        if api.nvim_buf_is_valid(bufnr) then
          api.nvim_buf_delete(bufnr, { force = true })
        end

        assert.is_true(ok, tostring(err))
        assert.is_true(stop_called, "client:stop should be used")
        assert.is_false(deprecated_called, "deprecated vim.lsp.stop_client should not be used")
        assert.is_false(detach_called, "buf_detach_client should not be called if not attached")
      end)
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
