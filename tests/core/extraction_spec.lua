-- Tests for code extraction from various document formats
local api = vim.api

-- Ensure otter is set up before tests run
require("otter").setup({})

-- Helper to get the test examples directory
local function examples_dir()
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/examples/"
end

-- Helper to load a file into a buffer and activate otter
local function load_and_activate(filename, languages)
  local filepath = examples_dir() .. filename
  -- Create a new buffer with the file
  vim.cmd("edit " .. filepath)
  local bufnr = api.nvim_get_current_buf()

  -- Activate with specific languages if provided
  require("otter").activate(languages, false, false)

  return bufnr
end

-- Helper to cleanup buffer
local function cleanup(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    require("otter").deactivate()
    api.nvim_buf_delete(bufnr, { force = true })
  end
end

describe("code extraction", function()
  local keeper = require("otter.keeper")

  describe("from markdown files", function()
    it("extracts lua code from minimal.md", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)
      assert.is_not_nil(code_chunks.lua, "should have lua chunks")
      assert.is_true(#code_chunks.lua > 0, "should have at least one lua chunk")

      -- Collect all extracted lua text
      local all_lua_text = ""
      for _, chunk in ipairs(code_chunks.lua) do
        all_lua_text = all_lua_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_lua_text:find("greet") ~= nil, "should contain 'greet' function")
      assert.is_true(all_lua_text:find("Hello") ~= nil, "should contain 'Hello'")

      cleanup(bufnr)
    end)

    it("extracts multiple language chunks from 03.md", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have lua chunks
      assert.is_not_nil(code_chunks.lua, "should have lua chunks")
      assert.is_true(#code_chunks.lua >= 2, "should have at least 2 lua chunks")

      -- Should have python chunks
      assert.is_not_nil(code_chunks.python, "should have python chunks")
      assert.is_true(#code_chunks.python > 0, "should have at least one python chunk")

      -- Check lua content
      local all_lua_text = ""
      for _, chunk in ipairs(code_chunks.lua) do
        all_lua_text = all_lua_text .. table.concat(chunk.text, "\n") .. "\n"
      end
      assert.is_true(all_lua_text:find("print") ~= nil, "lua should contain 'print'")

      -- Check python content
      local all_python_text = ""
      for _, chunk in ipairs(code_chunks.python) do
        all_python_text = all_python_text .. table.concat(chunk.text, "\n") .. "\n"
      end
      assert.is_true(all_python_text:find("numpy") ~= nil or all_python_text:find("print") ~= nil,
        "python should contain numpy or print")

      cleanup(bufnr)
    end)
  end)

  describe("from quarto markdown files", function()
    it("extracts code from 01.qmd", function()
      local bufnr = load_and_activate("01.qmd")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have r chunks
      assert.is_not_nil(code_chunks.r, "should have r chunks")

      -- Should have python chunks
      assert.is_not_nil(code_chunks.python, "should have python chunks")
      assert.is_true(#code_chunks.python >= 3, "should have multiple python chunks")

      -- Should have javascript chunks
      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")

      -- Check R content
      local all_r_text = ""
      for _, chunk in ipairs(code_chunks.r) do
        all_r_text = all_r_text .. table.concat(chunk.text, "\n") .. "\n"
      end
      assert.is_true(all_r_text:find("print") ~= nil or all_r_text:find("plot") ~= nil, "r should contain print or plot")

      -- Check Python content
      local all_python_text = ""
      for _, chunk in ipairs(code_chunks.python) do
        all_python_text = all_python_text .. table.concat(chunk.text, "\n") .. "\n"
      end
      assert.is_true(all_python_text:find("def hello") ~= nil, "python should contain 'def hello'")

      cleanup(bufnr)
    end)
  end)

  describe("from org files", function()
    it("extracts python code from 02.org", function()
      local bufnr = load_and_activate("02.org")

      -- org might not have a parser, check gracefully
      if keeper.rafts[bufnr] then
        local code_chunks = keeper.extract_code_chunks(bufnr)

        if code_chunks.python then
          assert.is_true(#code_chunks.python > 0, "should have at least one python chunk")

          -- Check content
          local python_text = table.concat(code_chunks.python[1].text, "\n")
          assert.is_true(python_text:find("Path") ~= nil or python_text:find("pathlib") ~= nil,
            "python should contain pathlib usage")
        end
      end

      cleanup(bufnr)
    end)
  end)

  describe("code chunk properties", function()
    it("has correct range information", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)
      assert.is_not_nil(code_chunks.lua, "should have lua chunks")

      local chunk = code_chunks.lua[1]
      assert.is_not_nil(chunk.range, "chunk should have range")
      assert.is_not_nil(chunk.range.from, "chunk should have from range")
      assert.is_not_nil(chunk.range.to, "chunk should have to range")
      assert.is_true(chunk.range.from[1] >= 0, "from row should be non-negative")
      assert.is_true(chunk.range.to[1] >= chunk.range.from[1], "to row should be >= from row")
      assert.equals("lua", chunk.lang, "chunk lang should be lua")

      cleanup(bufnr)
    end)

    it("text array matches content", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)
      local chunk = code_chunks.lua[1]

      assert.is_table(chunk.text, "text should be a table")
      assert.is_true(#chunk.text > 0, "text should have lines")

      -- Each element should be a string
      for i, line in ipairs(chunk.text) do
        assert.is_string(line, "line " .. i .. " should be a string")
      end

      cleanup(bufnr)
    end)
  end)

  describe("language context detection", function()
    it("detects language at cursor position", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      -- Move cursor to inside the lua code block (line 9 in minimal.md: "local greet = function(s)")
      api.nvim_win_set_cursor(0, { 9, 5 })

      local lang = keeper.get_current_language_context(bufnr)
      assert.equals("lua", lang, "should detect lua context")

      -- Move cursor outside code block (line 3)
      api.nvim_win_set_cursor(0, { 3, 0 })
      lang = keeper.get_current_language_context(bufnr)
      assert.is_nil(lang, "should not detect language outside code block")

      cleanup(bufnr)
    end)
  end)

  describe("otter buffer synchronization", function()
    it("creates otter buffers for detected languages", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers, "raft should have buffers")
      assert.is_not_nil(raft.buffers.lua, "should have lua buffer")
      assert.is_true(api.nvim_buf_is_valid(raft.buffers.lua), "lua buffer should be valid")

      cleanup(bufnr)
    end)

    it("syncs code to otter buffers", function()
      local bufnr = load_and_activate("minimal.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local result = keeper.sync_raft(bufnr)
      assert.equals("success", result, "sync should succeed")

      local raft = keeper.rafts[bufnr]
      local otter_bufnr = raft.buffers.lua
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Find a non-empty line that contains our lua code
      local has_greet = false
      for _, line in ipairs(lines) do
        if line:find("greet") then
          has_greet = true
          break
        end
      end
      assert.is_true(has_greet, "otter buffer should contain 'greet'")

      cleanup(bufnr)
    end)
  end)
end)
