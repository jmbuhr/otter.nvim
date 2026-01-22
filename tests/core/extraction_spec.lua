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
  -- Use :edit! to ensure a fresh load even if file was previously opened
  vim.cmd("edit! " .. filepath)
  local bufnr = api.nvim_get_current_buf()

  -- Activate with specific languages if provided
  require("otter").activate(languages, false, false)

  return bufnr
end

-- Helper to cleanup buffer with proper handling of scheduled callbacks
local function cleanup(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    local keeper = require("otter.keeper")
    local raft = keeper.rafts[bufnr]
    local otter_buffers = {}

    -- Collect otter buffer references before deactivation
    if raft and raft.buffers then
      for _, otter_bufnr in pairs(raft.buffers) do
        table.insert(otter_buffers, otter_bufnr)
      end
    end

    require("otter").deactivate()
    api.nvim_buf_delete(bufnr, { force = true })

    -- Wait for scheduled otter buffer deletions to complete
    -- The deactivate() function schedules buffer deletions with vim.schedule()
    -- We need to wait until all otter buffers are actually deleted
    if #otter_buffers > 0 then
      local timeout_ms = 100 -- Max wait time
      local interval_ms = 5 -- Check interval
      local waited = 0

      while waited < timeout_ms do
        -- Process pending scheduled callbacks
        vim.wait(interval_ms, function()
          return false
        end)
        waited = waited + interval_ms

        -- Check if all otter buffers are now invalid (deleted)
        local all_deleted = true
        for _, otter_bufnr in ipairs(otter_buffers) do
          if api.nvim_buf_is_valid(otter_bufnr) then
            all_deleted = false
            break
          end
        end

        if all_deleted then
          break
        end
      end
    end
  else
    -- Even if no buffer to clean, allow pending callbacks to complete
    vim.wait(10, function()
      return false
    end)
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
      assert.is_true(
        all_python_text:find("numpy") ~= nil or all_python_text:find("print") ~= nil,
        "python should contain numpy or print"
      )

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
      assert.is_true(
        all_r_text:find("print") ~= nil or all_r_text:find("plot") ~= nil,
        "r should contain print or plot"
      )

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

      local code_chunks = keeper.extract_code_chunks(bufnr)

      if code_chunks.python then
        assert.is_true(#code_chunks.python > 0, "should have at least one python chunk")

        -- Check content
        local python_text = table.concat(code_chunks.python[1].text, "\n")
        assert.is_true(
          python_text:find("Path") ~= nil or python_text:find("pathlib") ~= nil,
          "python should contain pathlib usage"
        )
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

  describe("indentation preservation", function()
    it("preserves indentation in otter buffers", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.python, "should have python buffer")

      local otter_bufnr = raft.buffers.python
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Find the line with 'print('hello world')' that's inside 'def hello():'
      -- In 03.md, the function is at lines 43-44 (0-indexed: 42-43)
      -- Line 43 should be "def hello():" and line 44 should be "    print('hello world')"
      local found_indented_print = false
      for i, line in ipairs(lines) do
        -- Look for the indented print statement (should have leading spaces)
        if line:match("^%s+print%('hello world'%)") then
          found_indented_print = true
          break
        end
      end

      assert.is_true(
        found_indented_print,
        "indented 'print('hello world')' should preserve its leading whitespace in otter buffer"
      )

      cleanup(bufnr)
    end)

    it("preserves indentation in nested code structures", function()
      -- Create a test buffer with nested indentation
      local test_content = [[
# Test

```python
def outer():
    def inner():
        return 42
    return inner()
```
]]
      -- Create a scratch buffer with the content
      local bufnr = api.nvim_create_buf(false, true)
      api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(test_content, "\n"))
      api.nvim_set_option_value("filetype", "markdown", {buf = bufnr})
      api.nvim_set_current_buf(bufnr)

      require("otter").activate(nil, false, false)

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      if raft.buffers.python then
        local otter_bufnr = raft.buffers.python
        local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

        -- Check that nested indentation is preserved
        local found_8_space_indent = false
        for _, line in ipairs(lines) do
          if line:match("^        return 42") then
            found_8_space_indent = true
            break
          end
        end

        assert.is_true(found_8_space_indent, "8-space indentation should be preserved for nested function")
      end

      require("otter").deactivate()
      api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe("HTML and embedded JS extraction from 03.md", function()
    it("extracts html code from 03.md", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have html chunks
      assert.is_not_nil(code_chunks.html, "should have html chunks")
      assert.is_true(#code_chunks.html > 0, "should have at least one html chunk")

      -- Check html content contains the expected elements
      local all_html_text = ""
      for _, chunk in ipairs(code_chunks.html) do
        all_html_text = all_html_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_html_text:find("<body>") ~= nil, "html should contain '<body>'")
      assert.is_true(all_html_text:find("<p>Hello</p>") ~= nil, "html should contain '<p>Hello</p>'")
      assert.is_true(
        all_html_text:find('<div class="hello">world</div>') ~= nil,
        "html should contain '<div class=\"hello\">world</div>'"
      )

      cleanup(bufnr)
    end)

    it("extracts javascript from script tags within html in 03.md", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have javascript chunks (from <script> tags within HTML or fenced code blocks)
      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")
      assert.is_true(#code_chunks.javascript > 0, "should have at least one javascript chunk")

      -- Check javascript content
      local all_js_text = ""
      for _, chunk in ipairs(code_chunks.javascript) do
        all_js_text = all_js_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_js_text:find("console%.log") ~= nil, "javascript should contain 'console.log'")
      assert.is_true(all_js_text:find("hello world") ~= nil, "javascript should contain 'hello world'")

      cleanup(bufnr)
    end)

    it("extracts css from style tags within html in 03.md", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have css chunks (from <style> tags within HTML)
      assert.is_not_nil(code_chunks.css, "should have css chunks")
      assert.is_true(#code_chunks.css > 0, "should have at least one css chunk")

      -- Check css content
      local all_css_text = ""
      for _, chunk in ipairs(code_chunks.css) do
        all_css_text = all_css_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_css_text:find("%.hello") ~= nil, "css should contain '.hello' selector")
      assert.is_true(all_css_text:find("color") ~= nil, "css should contain 'color'")
      assert.is_true(all_css_text:find("orange") ~= nil, "css should contain 'orange'")

      cleanup(bufnr)
    end)

    it("syncs html to otter buffer with correct content", function()
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.html, "should have html buffer")

      local otter_bufnr = raft.buffers.html
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Combine all lines to check for content
      local all_text = table.concat(lines, "\n")

      assert.is_true(all_text:find("<body>") ~= nil, "otter buffer should contain '<body>'")
      assert.is_true(all_text:find("<p>Hello</p>") ~= nil, "otter buffer should contain '<p>Hello</p>'")

      cleanup(bufnr)
    end)

    it("combines javascript from fenced blocks and script tags in same otter buffer", function()
      -- This test verifies that JavaScript from both fenced code blocks (```{javascript})
      -- AND <script> tags within HTML all end up in the same otter buffer
      local bufnr = load_and_activate("03.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      -- Verify we have all 3 JavaScript chunks (2 from <script> tags, 1 from fenced block)
      local code_chunks = keeper.extract_code_chunks(bufnr)
      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")
      assert.is_true(
        #code_chunks.javascript >= 3,
        "should have at least 3 javascript chunks (2 from <script> tags + 1 from fenced block)"
      )

      -- Sync to otter buffer
      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.javascript, "should have javascript buffer")

      local otter_bufnr = raft.buffers.javascript
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Check for content from <script> tags (indented with 4 spaces)
      local has_script_tag_js = false
      for _, line in ipairs(lines) do
        if line:match("^    console%.log") then
          has_script_tag_js = true
          break
        end
      end
      assert.is_true(has_script_tag_js, "otter buffer should contain indented console.log from <script> tags")

      -- Check for content from fenced code block (not indented, starts at column 0)
      -- This is distinct from <script> tag content which has 4-space indentation
      local has_fenced_js = false
      for _, line in ipairs(lines) do
        if line:match("^console%.log") then
          has_fenced_js = true
          break
        end
      end
      assert.is_true(has_fenced_js, "otter buffer should contain non-indented console.log from fenced code block")

      cleanup(bufnr)
    end)
  end)

  -- Tests using 03_html_only.md for reliable HTML-embedded JS/CSS extraction
  -- This file contains only HTML with embedded script/style tags (no fenced code blocks)
  -- to avoid treesitter injection collection non-determinism
  describe("HTML embedded language extraction from 03_html_only.md", function()
    it("extracts javascript from script tags with correct indentation", function()
      local bufnr = load_and_activate("03_html_only.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")
      assert.is_true(#code_chunks.javascript >= 2, "should have at least 2 javascript chunks from <script> tags")

      -- Verify javascript content and indentation
      local found_indented_console = false
      for _, chunk in ipairs(code_chunks.javascript) do
        for _, line in ipairs(chunk.text) do
          -- Check for indented console.log (4 spaces)
          if line:match("^    console%.log") then
            found_indented_console = true
            break
          end
        end
        if found_indented_console then
          break
        end
      end

      assert.is_true(found_indented_console, "should find console.log with 4-space indentation from <script> tag")

      cleanup(bufnr)
    end)

    it("extracts css from style tags with correct indentation", function()
      local bufnr = load_and_activate("03_html_only.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      assert.is_not_nil(code_chunks.css, "should have css chunks")
      assert.is_true(#code_chunks.css > 0, "should have at least one css chunk")

      local all_css_text = ""
      for _, chunk in ipairs(code_chunks.css) do
        all_css_text = all_css_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_css_text:find("%.greeting") ~= nil, "css should contain '.greeting' selector")
      assert.is_true(all_css_text:find("color") ~= nil, "css should contain 'color' property")
      assert.is_true(all_css_text:find("blue") ~= nil, "css should contain 'blue' value")

      -- Verify indentation is preserved (2 spaces for properties inside selector)
      local found_indented_property = false
      for _, chunk in ipairs(code_chunks.css) do
        for _, line in ipairs(chunk.text) do
          if line:match("^  color") then
            found_indented_property = true
            break
          end
        end
      end
      assert.is_true(found_indented_property, "css properties should preserve their 2-space indentation")

      cleanup(bufnr)
    end)

    it("preserves javascript indentation in otter buffer", function()
      local bufnr = load_and_activate("03_html_only.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.javascript, "should have javascript buffer")

      local otter_bufnr = raft.buffers.javascript
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Find indented console.log lines in the otter buffer
      local found_indented_console = false
      for _, line in ipairs(lines) do
        if line:match("^    console%.log") then
          found_indented_console = true
          break
        end
      end

      assert.is_true(
        found_indented_console,
        "javascript otter buffer should contain console.log with 4-space indentation"
      )

      cleanup(bufnr)
    end)

    it("preserves css indentation in otter buffer", function()
      local bufnr = load_and_activate("03_html_only.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.css, "should have css buffer")

      local otter_bufnr = raft.buffers.css
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)

      -- Find indented css property lines in the otter buffer
      local found_indented_property = false
      for _, line in ipairs(lines) do
        if line:match("^  color") then
          found_indented_property = true
          break
        end
      end

      assert.is_true(found_indented_property, "css otter buffer should contain properties with 2-space indentation")

      cleanup(bufnr)
    end)
  end)

  -- Tests for deeply nested injections and multiple HTML blocks
  -- Verifies that code from multiple separate HTML blocks combines correctly
  describe("deeply nested and multiple HTML blocks from 04_nested.md", function()
    it("extracts HTML from multiple separate code blocks", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have html chunks from all 4 HTML blocks
      assert.is_not_nil(code_chunks.html, "should have html chunks")
      assert.is_true(#code_chunks.html >= 3, "should have 3 html chunks")

      -- Verify content from different blocks
      local all_html_text = ""
      for _, chunk in ipairs(code_chunks.html) do
        all_html_text = all_html_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      -- Check for content from each block
      assert.is_true(all_html_text:find("block1") ~= nil, "should contain content from first HTML block")
      assert.is_true(all_html_text:find("block2") ~= nil, "should contain content from second HTML block")
      assert.is_true(all_html_text:find("block3") ~= nil, "should contain content from third HTML block")

      cleanup(bufnr)
    end)

    it("combines JavaScript from multiple HTML blocks and fenced blocks", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have javascript chunks from:
      -- - 3 <script> tags across 3 HTML blocks (block1, block2, block3 has 2 scripts)
      -- - 1 fenced javascript code block
      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")
      assert.is_true(
        #code_chunks.javascript >= 5,
        "should have at least 5 javascript chunks (4 from <script> tags + 1 from fenced block)"
      )

      -- Verify content from different sources
      local all_js_text = ""
      for _, chunk in ipairs(code_chunks.javascript) do
        all_js_text = all_js_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      -- Check for content from script tags in HTML blocks
      assert.is_true(all_js_text:find('block1 = "first"') ~= nil, "should contain JS from first HTML block script tag")
      assert.is_true(
        all_js_text:find('block2 = "second"') ~= nil,
        "should contain JS from second HTML block script tag"
      )
      assert.is_true(all_js_text:find("first = 1") ~= nil, "should contain JS from first script in third HTML block")
      assert.is_true(all_js_text:find("second = 2") ~= nil, "should contain JS from second script in third HTML block")

      -- Check for content from standalone fenced code block
      assert.is_true(all_js_text:find('standalone = "standalone"') ~= nil, "should contain JS from fenced code block")
      assert.is_true(all_js_text:find("function doSomething") ~= nil, "should contain function from fenced code block")

      cleanup(bufnr)
    end)

    it("combines CSS from multiple HTML blocks and fenced blocks", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have css chunks from:
      -- - 2 <style> tags in HTML blocks (block1, block2)
      -- - 1 fenced css code block
      assert.is_not_nil(code_chunks.css, "should have css chunks")
      assert.is_true(
        #code_chunks.css >= 3,
        "should have at least 3 css chunks (2 from <style> tags + 1 from fenced block)"
      )

      -- Verify content from different sources
      local all_css_text = ""
      for _, chunk in ipairs(code_chunks.css) do
        all_css_text = all_css_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      -- Check for content from style tags in HTML blocks
      assert.is_true(all_css_text:find("#block1") ~= nil, "should contain CSS from first HTML block style tag")
      assert.is_true(all_css_text:find("red") ~= nil, "should contain 'red' color from first block")
      assert.is_true(all_css_text:find("#block2") ~= nil, "should contain CSS from second HTML block style tag")
      assert.is_true(all_css_text:find("blue") ~= nil, "should contain 'blue' color from second block")

      -- Check for content from standalone fenced code block
      assert.is_true(all_css_text:find("body") ~= nil, "should contain CSS from fenced code block")
      assert.is_true(all_css_text:find("margin") ~= nil, "should contain 'margin' from fenced code block")

      cleanup(bufnr)
    end)

    it("syncs all JavaScript sources to same otter buffer", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.javascript, "should have javascript buffer")

      local otter_bufnr = raft.buffers.javascript
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)
      local all_text = table.concat(lines, "\n")

      -- Verify all JavaScript from all sources is in the same buffer
      assert.is_true(all_text:find("block1") ~= nil, "otter buffer should contain JS from first HTML block")
      assert.is_true(all_text:find("block2") ~= nil, "otter buffer should contain JS from second HTML block")
      assert.is_true(all_text:find("standalone") ~= nil, "otter buffer should contain JS from fenced code block")

      cleanup(bufnr)
    end)

    it("syncs all CSS sources to same otter buffer", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      keeper.sync_raft(bufnr)

      local raft = keeper.rafts[bufnr]
      assert.is_not_nil(raft.buffers.css, "should have css buffer")

      local otter_bufnr = raft.buffers.css
      local lines = api.nvim_buf_get_lines(otter_bufnr, 0, -1, false)
      local all_text = table.concat(lines, "\n")

      -- Verify all CSS from all sources is in the same buffer
      assert.is_true(all_text:find("#block1") ~= nil, "otter buffer should contain CSS from first HTML block")
      assert.is_true(all_text:find("#block2") ~= nil, "otter buffer should contain CSS from second HTML block")
      assert.is_true(all_text:find("body") ~= nil, "otter buffer should contain CSS from fenced code block")

      cleanup(bufnr)
    end)

    it("handles HTML block with multiple script tags", function()
      local bufnr = load_and_activate("04_nested.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)
      assert.is_not_nil(code_chunks.javascript, "should have javascript chunks")

      -- Find javascript chunks from block3 (which has two <script> tags)
      local all_js_text = ""
      for _, chunk in ipairs(code_chunks.javascript) do
        all_js_text = all_js_text .. table.concat(chunk.text, "\n") .. "\n"
      end

      -- Both script tags from block3 should be extracted
      assert.is_true(all_js_text:find("First script in block3") ~= nil, "should extract first script tag from block3")
      assert.is_true(all_js_text:find("Second script in block3") ~= nil, "should extract second script tag from block3")

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

  -- Tests for TypeScript template literal injections (Issue #72)
  -- Verifies that extracted code from tagged template literals does NOT include surrounding backticks
  describe("TypeScript template literal injections from 06.ts", function()
    it("extracts code from template literals without surrounding backticks", function()
      local bufnr = load_and_activate("06.ts")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for TypeScript file")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Check all injected languages (html, css, lua from template literals)
      for lang, chunks in pairs(code_chunks) do
        for _, chunk in ipairs(chunks) do
          local text = table.concat(chunk.text, "\n")

          -- Text should NOT start or end with backtick
          assert.is_false(
            text:match("^`") ~= nil,
            "Extracted " .. lang .. " code should not start with backtick, got: " .. text:sub(1, 30)
          )
          assert.is_false(
            text:match("`$") ~= nil,
            "Extracted " .. lang .. " code should not end with backtick, got: " .. text:sub(-30)
          )
        end
      end

      cleanup(bufnr)
    end)

    it("extracts HTML from template literal with correct content", function()
      local bufnr = load_and_activate("06.ts")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      if code_chunks.html then
        local all_html = ""
        for _, chunk in ipairs(code_chunks.html) do
          all_html = all_html .. table.concat(chunk.text, "\n") .. "\n"
        end

        -- Should contain the actual HTML content, not backticks
        assert.is_true(all_html:find("<div>") ~= nil, "HTML should contain '<div>'")
        assert.is_true(all_html:find("<p>hello</p>") ~= nil, "HTML should contain '<p>hello</p>'")
        -- Should NOT contain backticks as part of the content
        assert.is_false(all_html:match("^%s*`") ~= nil, "HTML should not start with backtick")
      end

      cleanup(bufnr)
    end)

    it("extracts CSS from template literal with correct content", function()
      local bufnr = load_and_activate("06.ts")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      if code_chunks.css then
        local all_css = ""
        for _, chunk in ipairs(code_chunks.css) do
          all_css = all_css .. table.concat(chunk.text, "\n") .. "\n"
        end

        -- Should contain the actual CSS content
        assert.is_true(all_css:find("%.foo") ~= nil, "CSS should contain '.foo' selector")
        assert.is_true(all_css:find("color") ~= nil, "CSS should contain 'color' property")
        -- Should NOT contain backticks
        assert.is_false(all_css:match("^%s*`") ~= nil, "CSS should not start with backtick")
      end

      cleanup(bufnr)
    end)

    it("extracts Lua from template literal with correct content", function()
      local bufnr = load_and_activate("06.ts")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      if code_chunks.lua then
        local all_lua = ""
        for _, chunk in ipairs(code_chunks.lua) do
          all_lua = all_lua .. table.concat(chunk.text, "\n") .. "\n"
        end

        -- Should contain the actual Lua content
        assert.is_true(all_lua:find("local foo") ~= nil, "Lua should contain 'local foo'")
        assert.is_true(all_lua:find("print") ~= nil, "Lua should contain 'print'")
        -- Should NOT contain backticks
        assert.is_false(all_lua:match("^%s*`") ~= nil, "Lua should not start with backtick")
      end

      cleanup(bufnr)
    end)
  end)

  -- Tests for Lua files with vimscript injection (00.lua)
  describe("Lua file with vimscript injection from 00.lua", function()
    it("extracts vimscript from vim.cmd block", function()
      local bufnr = load_and_activate("00.lua")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for Lua file")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have vim chunks from the vim.cmd block
      if code_chunks.vim then
        local all_vim = ""
        for _, chunk in ipairs(code_chunks.vim) do
          all_vim = all_vim .. table.concat(chunk.text, "\n") .. "\n"
        end

        -- Should contain the vimscript content
        assert.is_true(all_vim:find("let x = 10") ~= nil, "Vim should contain 'let x = 10'")
        assert.is_true(all_vim:find("let y = 20") ~= nil, "Vim should contain 'let y = 20'")
      end

      cleanup(bufnr)
    end)
  end)

  -- Tests for quarto markdown variant (01b.qmd)
  describe("Quarto markdown from 01b.qmd", function()
    it("extracts python code from quarto code blocks", function()
      local bufnr = load_and_activate("01b.qmd")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for Quarto file")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      assert.is_not_nil(code_chunks.python, "should have python chunks")
      assert.is_true(#code_chunks.python >= 2, "should have at least 2 python chunks")

      local all_python = ""
      for _, chunk in ipairs(code_chunks.python) do
        all_python = all_python .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_python:find("import sys") ~= nil, "Python should contain 'import sys'")
      assert.is_true(all_python:find("print") ~= nil, "Python should contain 'print'")

      cleanup(bufnr)
    end)

    it("returns full code chunk for a single-line range", function()
      local bufnr = load_and_activate("01b.qmd")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for Quarto file")

      -- Pick a line inside the second python chunk (0-indexed row 14)
      local row = 14
      local chunks = keeper.extract_code_chunks(bufnr, "python", false, row, row).python

      assert.is_not_nil(chunks, "should have python chunks in range")
      assert.equals(1, #chunks, "range should select a single python chunk")

      local chunk = chunks[1]
      assert.is_true(#chunk.text > 1, "chunk should include multiple lines")

      local chunk_text = table.concat(chunk.text, "\n")
      assert.is_equals(chunk_text, 'x = 1\ny = "hello"\nprint("hello world")\ny.lower()')

      cleanup(bufnr)
    end)
  end)

  -- Tests for markdown with python code blocks (03b.md)
  describe("Markdown with Python from 03b.md", function()
    it("extracts python code with function definitions", function()
      local bufnr = load_and_activate("03b.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      assert.is_not_nil(code_chunks.python, "should have python chunks")
      assert.is_true(#code_chunks.python >= 4, "should have at least 4 python chunks")

      local all_python = ""
      for _, chunk in ipairs(code_chunks.python) do
        all_python = all_python .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_python:find("import os") ~= nil, "Python should contain 'import os'")
      assert.is_true(all_python:find("import math") ~= nil, "Python should contain 'import math'")
      assert.is_true(all_python:find("def hello") ~= nil, "Python should contain 'def hello'")

      cleanup(bufnr)
    end)
  end)

  -- Tests for simple markdown with R code (03c.md)
  describe("Markdown with R from 03c.md", function()
    it("extracts R code", function()
      local bufnr = load_and_activate("03c.md")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      assert.is_not_nil(code_chunks.r, "should have r chunks")
      assert.is_true(#code_chunks.r >= 1, "should have at least 1 R chunk")

      local all_r = ""
      for _, chunk in ipairs(code_chunks.r) do
        all_r = all_r .. table.concat(chunk.text, "\n") .. "\n"
      end

      assert.is_true(all_r:find("print") ~= nil, "R should contain 'print'")
      assert.is_true(all_r:find("hello world") ~= nil, "R should contain 'hello world'")

      cleanup(bufnr)
    end)
  end)

  -- Tests for Rust file with SQL injection (04.rs)
  describe("Rust file with SQL injection from 04.rs", function()
    it("extracts SQL from sqlx macro", function()
      local bufnr = load_and_activate("04.rs")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for Rust file")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Rust may have SQL injected via sqlx macro
      -- The injection depends on treesitter queries being configured
      if code_chunks.sql then
        local all_sql = ""
        for _, chunk in ipairs(code_chunks.sql) do
          all_sql = all_sql .. table.concat(chunk.text, "\n") .. "\n"
        end

        assert.is_true(all_sql:find("INSERT INTO") ~= nil, "SQL should contain 'INSERT INTO'")
        assert.is_true(all_sql:find("RETURNING") ~= nil, "SQL should contain 'RETURNING'")
      end

      cleanup(bufnr)
    end)
  end)

  -- Tests for Neorg files (05.norg)
  describe("Neorg file from 05.norg", function()
    it("extracts code from norg code blocks", function()
      local bufnr = load_and_activate("05.norg")

      -- Norg parser may not be available
      if not keeper.rafts[bufnr] then
        api.nvim_buf_delete(bufnr, { force = true })
        return
      end

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have lua chunks
      if code_chunks.lua then
        local all_lua = ""
        for _, chunk in ipairs(code_chunks.lua) do
          all_lua = all_lua .. table.concat(chunk.text, "\n") .. "\n"
        end

        assert.is_true(all_lua:find("Hello, Norg") ~= nil or all_lua:find("print") ~= nil,
          "Lua should contain Norg example code")
      end

      -- Should have python chunks
      if code_chunks.python then
        local all_python = ""
        for _, chunk in ipairs(code_chunks.python) do
          all_python = all_python .. table.concat(chunk.text, "\n") .. "\n"
        end

        assert.is_true(all_python:find("Hello world") ~= nil or all_python:find("numpy") ~= nil,
          "Python should contain Norg example code")
      end

      cleanup(bufnr)
    end)
  end)

  -- Tests for Nix files with Lua injection (07.nix)
  describe("Nix file with Lua injection from 07.nix", function()
    it("extracts Lua from nix multi-line string", function()
      local bufnr = load_and_activate("07.nix")
      assert.is_not_nil(keeper.rafts[bufnr], "raft should exist for Nix file")

      local code_chunks = keeper.extract_code_chunks(bufnr)

      -- Should have lua chunks from the injected string
      if code_chunks.lua then
        local all_lua = ""
        for _, chunk in ipairs(code_chunks.lua) do
          all_lua = all_lua .. table.concat(chunk.text, "\n") .. "\n"
        end

        assert.is_true(all_lua:find("a_string") ~= nil, "Lua should contain 'a_string'")
        assert.is_true(all_lua:find("print") ~= nil, "Lua should contain 'print'")
      end

      cleanup(bufnr)
    end)
  end)

  -- Test that verifies strip_wrapping_quotes is no longer needed
  -- by checking extraction works correctly without it
  describe("strip_wrapping_quotes removal verification", function()
    it("all existing test files extract correctly without quote issues", function()
      -- Test all markdown files to ensure no spurious quotes appear
      local test_files = { "minimal.md", "03.md", "03_html_only.md", "04_nested.md" }

      for _, filename in ipairs(test_files) do
        local bufnr = load_and_activate(filename)
        if keeper.rafts[bufnr] then
          local code_chunks = keeper.extract_code_chunks(bufnr)

          for lang, chunks in pairs(code_chunks) do
            for i, chunk in ipairs(chunks) do
              local text = table.concat(chunk.text, "\n")
              -- No chunk should be entirely wrapped in quotes
              local first = text:sub(1, 1)
              local last = text:sub(-1)

              -- If text starts and ends with same quote character, that's suspicious
              if (first == '"' or first == "'" or first == "`") and first == last and #text > 2 then
                -- Check if the ENTIRE text is just a quoted string
                local inner = text:sub(2, -2)
                -- This would only be a problem if the inner content looks like code
                -- and the quotes are from injection capture issues
                if inner:match("[%w_]") then
                  -- This is likely a bug - code shouldn't be wrapped in quotes
                  assert.fail(
                    "Chunk "
                      .. i
                      .. " of "
                      .. lang
                      .. " in "
                      .. filename
                      .. " appears to be incorrectly wrapped in quotes: "
                      .. text:sub(1, 50)
                  )
                end
              end
            end
          end

          cleanup(bufnr)
        else
          api.nvim_buf_delete(bufnr, { force = true })
        end
      end
    end)
  end)
end)
