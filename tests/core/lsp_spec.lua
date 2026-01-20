-- Tests for LSP request/response position translation
-- Focuses on the leading whitespace offset handling for indented code blocks
local api = vim.api

-- Ensure otter is set up before tests run
require("otter").setup({
  handle_leading_whitespace = true,
})

local keeper = require("otter.keeper")
local handlers = require("otter.lsp.handlers")
local ms = vim.lsp.protocol.Methods

-- Helper to get the test examples directory
local function examples_dir()
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/examples/"
end

-- Helper to load a file into a buffer and activate otter
local function load_and_activate(filename, languages)
  local filepath = examples_dir() .. filename
  vim.cmd("edit! " .. filepath)
  local bufnr = api.nvim_get_current_buf()
  require("otter").activate(languages, false, false)
  return bufnr
end

-- Helper to cleanup buffer with proper handling of scheduled callbacks
local function cleanup(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    local raft = keeper.rafts[bufnr]
    local otter_buffers = {}
    if raft and raft.buffers then
      for _, otter_bufnr in pairs(raft.buffers) do
        table.insert(otter_buffers, otter_bufnr)
      end
    end
    require("otter").deactivate()
    api.nvim_buf_delete(bufnr, { force = true })
    if #otter_buffers > 0 then
      local timeout_ms = 100
      local interval_ms = 5
      local waited = 0
      while waited < timeout_ms do
        vim.wait(interval_ms, function() return false end)
        waited = waited + interval_ms
        local all_deleted = true
        for _, otter_bufnr in ipairs(otter_buffers) do
          if api.nvim_buf_is_valid(otter_bufnr) then
            all_deleted = false
            break
          end
        end
        if all_deleted then break end
      end
    end
  else
    vim.wait(10, function() return false end)
  end
end

-- Helper to find a line number with non-zero leading_offset in 03.md
-- Lines 34-37 are inside the indented <script> tag and have leading_offset = 4
-- This helper must be called AFTER sync_raft
local function find_line_with_offset(bufnr)
  for line = 34, 37 do
    local offset = keeper.get_leading_offset(line, bufnr)
    if offset > 0 then
      return line, offset
    end
  end
  return nil, 0
end

describe("LSP position translation", function()

  describe("modify_position function", function()
    it("adjusts range.start.character by leading_offset", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")
      assert.is_true(offset > 0, "offset should be > 0")

      -- Create a mock LSP range object (0-based line numbers)
      local obj = {
        range = {
          start = { line = line_nr, character = 0 },
          ["end"] = { line = line_nr, character = 7 }, -- "console"
        }
      }

      -- Apply position modification (otter -> main buffer)
      keeper.modify_position(obj, bufnr, false, false)

      -- Character positions should be increased by the offset
      assert.equals(offset, obj.range.start.character,
        "start character should be adjusted by leading_offset")
      assert.equals(7 + offset, obj.range["end"].character,
        "end character should be adjusted by leading_offset")

      cleanup(bufnr)
    end)

    it("adjusts position.character by leading_offset", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")

      local obj = {
        position = { line = line_nr, character = 5 }
      }

      keeper.modify_position(obj, bufnr, false, false)

      assert.equals(5 + offset, obj.position.character,
        "position character should be adjusted by leading_offset")

      cleanup(bufnr)
    end)

    it("handles invert=true for request translation (main -> otter)", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")

      -- Simulate a position from main buffer (with indentation)
      local obj = {
        position = { line = line_nr, character = offset + 5 }
      }

      -- Apply inverted position modification (main -> otter buffer)
      keeper.modify_position(obj, bufnr, true, false)

      assert.equals(5, obj.position.character,
        "inverted modification should subtract leading_offset")

      cleanup(bufnr)
    end)

    it("adds indentation to newText after newlines", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")

      local obj = {
        range = {
          start = { line = line_nr, character = 0 },
          ["end"] = { line = line_nr, character = 0 },
        },
        newText = "function test() {\n  return 42;\n}"
      }

      keeper.modify_position(obj, bufnr, false, false)

      -- newText should have indentation added after newlines
      local expected_indent = string.rep(" ", offset)
      assert.is_true(obj.newText:find("\n" .. expected_indent .. "  return") ~= nil,
        "newText should have indentation added after newlines")

      cleanup(bufnr)
    end)
  end)

  describe("completion handler position translation", function()
    -- This test verifies that the completion handler correctly adjusts textEdit ranges
    it("adjusts textEdit.range by leading_offset", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")
      assert.is_true(offset > 0, "offset should be > 0")

      -- Simulate a completion response from LSP
      -- The LSP thinks "console" is at column 0 (in the dedented otter buffer)
      local mock_response = {
        isIncomplete = false,
        items = {
          {
            label = "log",
            textEdit = {
              range = {
                start = { line = line_nr, character = 0 },
                ["end"] = { line = line_nr, character = 7 }, -- "console"
              },
              newText = "console.log"
            }
          }
        }
      }

      local mock_ctx = {
        params = {
          textDocument = { uri = "file:///test.md" },
          otter = {
            main_uri = "file:///test.md",
            main_nr = bufnr
          }
        },
        bufnr = bufnr
      }

      -- Call the completion handler
      local _, response, _ = handlers[ms.textDocument_completion](nil, mock_response, mock_ctx)

      -- textEdit.range should now be adjusted by leading_offset
      local item = response.items[1]
      assert.equals(offset, item.textEdit.range.start.character,
        "textEdit.range.start.character should be adjusted by leading_offset")
      assert.equals(7 + offset, item.textEdit.range["end"].character,
        "textEdit.range.end.character should be adjusted by leading_offset")

      cleanup(bufnr)
    end)

    -- This test verifies that modify_position is called correctly
    it("modify_position adjusts textEdit.range correctly", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")

      -- Direct test of modify_position on a textEdit-like structure
      local mock_response = {
        isIncomplete = false,
        items = {
          {
            label = "log",
            textEdit = {
              range = {
                start = { line = line_nr, character = 0 },
                ["end"] = { line = line_nr, character = 7 },
              },
              newText = "console.log"
            }
          }
        }
      }

      -- Manually apply the fix that should be in the handler
      for _, item in ipairs(mock_response.items) do
        if item.textEdit then
          keeper.modify_position(item.textEdit, bufnr, false, false)
        end
      end

      local item = mock_response.items[1]
      assert.equals(offset, item.textEdit.range.start.character,
        "textEdit.range.start.character should be offset")
      assert.equals(7 + offset, item.textEdit.range["end"].character,
        "textEdit.range.end.character should be offset + original")

      cleanup(bufnr)
    end)

    it("adjusts additionalTextEdits ranges", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")

      -- Simulate a completion with additionalTextEdits (e.g., auto-import)
      -- Note: additionalTextEdits for auto-imports are usually at line 0 which
      -- may have offset 0, so we test with an edit on a line with known offset
      local mock_response = {
        isIncomplete = false,
        items = {
          {
            label = "someFunction",
            additionalTextEdits = {
              {
                range = {
                  start = { line = line_nr, character = 0 },
                  ["end"] = { line = line_nr, character = 0 },
                },
                newText = "// inserted\n"
              }
            }
          }
        }
      }

      local mock_ctx = {
        params = {
          textDocument = { uri = "file:///test.md" },
          otter = {
            main_uri = "file:///test.md",
            main_nr = bufnr
          }
        },
        bufnr = bufnr
      }

      local _, response, _ = handlers[ms.textDocument_completion](nil, mock_response, mock_ctx)

      -- additionalTextEdits should be adjusted
      local item = response.items[1]
      assert.is_not_nil(item.additionalTextEdits, "additionalTextEdits should exist")
      assert.equals(offset, item.additionalTextEdits[1].range.start.character,
        "additionalTextEdits range should be adjusted")

      cleanup(bufnr)
    end)
  end)

  describe("InsertReplaceEdit handling", function()
    it("modify_position adjusts insert and replace ranges", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")
      assert.is_true(offset > 0, "offset should be > 0")

      -- InsertReplaceEdit format (used by some LSP servers)
      -- This format has "insert" and "replace" ranges instead of a single "range"
      local obj = {
        insert = {
          start = { line = line_nr, character = 8 },
          ["end"] = { line = line_nr, character = 8 },
        },
        replace = {
          start = { line = line_nr, character = 8 },
          ["end"] = { line = line_nr, character = 12 },
        },
        newText = ".log()"
      }

      -- modify_position should now handle InsertReplaceEdit format
      local success, err = pcall(function()
        keeper.modify_position(obj, bufnr, false, false)
      end)

      assert.is_true(success, "modify_position should not error on InsertReplaceEdit: " .. tostring(err))

      -- Both insert and replace ranges should be adjusted
      assert.equals(8 + offset, obj.insert.start.character,
        "insert.start.character should be adjusted by leading_offset")
      assert.equals(8 + offset, obj.insert["end"].character,
        "insert.end.character should be adjusted by leading_offset")
      assert.equals(8 + offset, obj.replace.start.character,
        "replace.start.character should be adjusted by leading_offset")
      assert.equals(12 + offset, obj.replace["end"].character,
        "replace.end.character should be adjusted by leading_offset")

      cleanup(bufnr)
    end)
  end)

  describe("hover handler position translation", function()
    it("adjusts response.range for highlighting", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")
      assert.is_true(offset > 0, "offset should be > 0")

      -- Simulate a hover response with a range for highlighting
      local mock_response = {
        contents = {
          kind = "markdown",
          value = "```typescript\nconsole: Console\n```"
        },
        range = {
          start = { line = line_nr, character = 0 },
          ["end"] = { line = line_nr, character = 7 },
        }
      }

      local mock_ctx = {
        params = {
          textDocument = { uri = "file:///test.md" },
          otter = {
            main_uri = "file:///test.md",
            main_nr = bufnr
          }
        },
        bufnr = bufnr
      }

      local _, response, _ = handlers[ms.textDocument_hover](nil, mock_response, mock_ctx)

      -- range should now be adjusted by leading_offset
      assert.equals(offset, response.range.start.character,
        "hover range.start.character should be adjusted by leading_offset")
      assert.equals(7 + offset, response.range["end"].character,
        "hover range.end.character should be adjusted by leading_offset")

      cleanup(bufnr)
    end)
  end)

  describe("get_leading_offset", function()
    it("returns correct offset for lines inside indented code chunks", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      local line_nr, offset = find_line_with_offset(bufnr)
      assert.is_not_nil(line_nr, "should find a line with leading_offset > 0")
      assert.is_true(offset > 0, "offset should be greater than 0 for indented code")

      -- Verify get_leading_offset returns the expected value
      local fetched_offset = keeper.get_leading_offset(line_nr, bufnr)
      assert.equals(offset, fetched_offset,
        "get_leading_offset should return the correct offset")

      cleanup(bufnr)
    end)

    it("returns 0 for lines outside code chunks", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")
      keeper.sync_raft(bufnr)

      -- Line 0 is the YAML frontmatter, not inside any code chunk
      local offset = keeper.get_leading_offset(0, bufnr)
      assert.equals(0, offset, "offset should be 0 for lines outside code chunks")

      cleanup(bufnr)
    end)
  end)
end)

describe("blink.cmp integration", function()
  -- These tests require blink.cmp to be loaded
  local blink_ok, blink = pcall(require, "blink.cmp")

  it("blink.cmp is available in test environment", function()
    -- This test documents whether blink.cmp loaded successfully
    -- If it fails, we need to ensure blink.cmp is properly installed
    if not blink_ok then
      print("NOTE: blink.cmp not available - skipping integration tests")
      print("Error: " .. tostring(blink))
    end
    -- Don't assert - just document availability
  end)

  if blink_ok then
    describe("completion application", function()
      it("documents the completion flow that causes the bug", function()
        -- This test documents the problematic flow:
        -- 1. User is in main buffer at indented code position
        -- 2. Completion is triggered
        -- 3. LSP returns textEdit with otter buffer coordinates
        -- 4. blink.cmp applies textEdit to main buffer
        -- 5. Wrong text is replaced due to column offset mismatch

        -- The actual fix needs to be in otter's completion handler
        -- to adjust textEdit.range before blink.cmp sees it

        pending("Integration test requires LSP server - manual testing recommended")
      end)
    end)
  end
end)
