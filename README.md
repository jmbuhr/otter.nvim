# otter.nvim

Just ask an otter! 🦦

> [!NOTE]
> Otter has grown up! It is now a language server-client combo,
> which means you don't have to configure keybindings for it.
> Just call `otter.activate()`!.
> 
> If you previously used e.g. `otter.ask_hover()`, you now just use the normal
> lsp request functions like `vim.lsp.buf.hover()` and the otters take it from there.
> If you previously used the `otter` `nvim-cmp` source, you can remove it,
> as the completion results now come directly via the `cmp-nvim-lsp` source
> together with other language servers.
> If you want to stick to the old way, you have to pin the version to `v1.15.1`.

## What is otter.nvim?

**tldr: Otter.nvim provides lsp features and a code completion source for code embedded in other documents**

![An otter eagerly awaiting your lsp requests.](https://github.com/jmbuhr/otter.nvim/assets/17450586/e4dcce8d-674b-40d3-99c5-db42bda2faeb)

Demo

https://user-images.githubusercontent.com/17450586/209436156-f7f42ea9-471c-478a-868e-77517d71a1c5.mp4

When implementing autocompletion, code diagnostics and the likes for [quarto-nvim](https://github.com/quarto-dev/quarto-nvim) I realized that a core feature would be useful to other plugins and usecases as well.
[quarto](https://quarto.org) documents are computational notebooks for scientific communication based on [pandoc](https://pandoc.org/)s markdown.
One key feature is that these `qmd` documents can contain exectuable code blocks, with possibly different languages such as `R` and `python` mixed in one document.

How do we get all the cool language features we get for a pure e.g. `python` file -- like code completion, documentation hover windows, diagnostics -- when the code is just embedded as code blocks in a document?
Well, if one document can't give us the answer, we ask an otter (another)!
`otter.nvim` creates and synchronizes hidden buffers containing a single language each and directs requests for completion and other lsp requests from the main buffer to those other buffers (otter buffers).

Example in a markdown (or quarto markdown) document `index.md`:

````
# Some markdown
Hello world

```python
import numpy as np
np.zeros(10)
```
````

We create a hidden buffer for a file `index.md.tmp.py`


````
 
 
 
 
import numpy as np
np.zeros(10)

````

This contains just the python code and blank lines for all other lines (this keeps line numbers the same, which comes straight from the trick that the quarto dev team uses for the vs code extension as well).
Language servers can then attach to this hidden buffer.
We can do this for all embedded languages found in a document.

### A group of otters is called a raft

Each otter-activated buffer can maintain a set of other buffers synchronized to the main buffer.

> In other words, each buffer can have a raft of otters!

The otter keeper looks after the otters associated with each main buffer
to keep them in sync:

```{mermaid}
stateDiagram-v2
Main --> otterkeeper
otterkeeper --> 🦦1
otterkeeper --> 🦦2
otterkeeper --> 🦦3
```

The otter language server directs lsp requests to the main
buffer to the otter responsible for the language of the
current code section.
It modifies the parameters accordingly e.g. to change the
uri of the file of which a position is requested.
If does so both ways, first with the request and then
when handling the request.
Once the response has been properly modifed it is passed on
to be handled by Neovim's default handlers `vim.lsp.handlers[<...>]`.

```{mermaid}
stateDiagram-v2
otterls : otter-ls
params : modified request params
ls : ls attached to otter buffer 🦦1
handler: otter-ls handler
defaultHandler: default handler of nvim
request --> otterls
otterls --> params
params --> ls
ls --> response
response --> handler
handler --> defaultHandler
```

There are some exceptions in which the otter-ls handler has to completely
handle the response and doesn't pass it on to the default handler.

## How do I use otter.nvim?

### Dependencies

`otter.nvim` requires the following plugins:

```lua
{
  'neovim/nvim-lspconfig',
  'nvim-treesitter/nvim-treesitter'
}
```

### Minimal lazy.nvim spec:

```lua
{
    'jmbuhr/otter.nvim',
    dev = true,
    dependencies = {
      {
        'neovim/nvim-lspconfig',
        'nvim-treesitter/nvim-treesitter',
      },
    },
    opts = {},
},
```

### Configure otter

If you want to use the default config below you don't need to call `setup`.

```lua
local otter = require'otter'
otter.setup{
  lsp = {
    -- `:h events` that cause the diagnostics to update. Set to:
    -- { "BufWritePost", "InsertLeave", "TextChanged" } for less performant
    -- but more instant diagnostic updates
    diagnostic_update_events = { "BufWritePost" },
    -- function to find the root dir where the otter-ls is started
    root_dir = require("lspconfig").util.root_pattern({ ".git", "_quarto.yml", "package.json" }),
  },
  buffers = {
    -- if set to true, the filetype of the otterbuffers will be set.
    -- otherwise only the autocommand of lspconfig that attaches
    -- the language server will be executed without setting the filetype
    set_filetype = false,
    -- write <path>.otter.<embedded language extension> files
    -- to disk on save of main buffer.
    -- usefule for some linters that require actual files
    -- otter files are deleted on quit or main buffer close
    write_to_disk = false,
  },
  strip_wrapping_quote_characters = { "'", '"', "`" },
  -- otter may not work the way you expect when entire code blocks are indented (eg. in Org files)
  -- When true, otter handles these cases fully.
  handle_leading_whitespace = false,
}
```

### Activate otter

Activate otter for the current document with `otter.activate()`

```lua
--- Activate the current buffer by adding and synchronizing
---@param languages table|nil List of languages to activate. If nil, all available languages will be activated.
---@param completion boolean|nil Enable completion for otter buffers. Default: true
---@param diagnostics boolean|nil Enable diagnostics for otter buffers. Default: true
---@param tsquery string|nil Explicitly provide a treesitter query. If nil, the injections query for the current filetyepe will be used. See :h treesitter-language-injections.
otter.activate(languages, completion, diagnostics, tsquery)
```

### Use otter

Use your normal lsp keybindings for e.g. `vim.lsp.buf.hover`, `vim.lsp.buf.references` etc.

#### LSP Methods currently implemented

| Method | `nvim.lsp.buf.<function>` |
| ------------- | ---- |
| textDocument/hover             | `hover`                           |
| textDocument/signatureHelp     | `signature_help`                  |
| textDocument/definition        | `definition`                      |
| textDocument/implementation    | `implementation`                  |
| textDocument/declaration       | `declaration`                     |
| textDocument/documentSymbol    | `document_symbol`                 |
| textDocument/typeDefinition    | `type_definition`                 |
| textDocument/rename            | `rename`                          |
| textDocument/references        | `references`                      |
| textDocument/completion        | `completion`                      |


#### Additional functions

```lua
-- Export the raft of otters as files.
-- Asks for filename for each language.
otter.export()
otter.export_otter_as()
```

## Current limitations

- Otter-ls currently runs only in single file mode. So while the language servers associated with
  each otter can know about a complete project, only one notebook is looked at by one instance of otter-ls.
  This means, you can e.g. rename a python variable across a bunch of modules directly from a quarto notebook
  managed by otter.nvim, but this (currently) won't automatically affect the same variable should used in a different notebook.
- Likewise, the other language servers don't know they are being fed by the otter-ls and otter.nvim doesn't hear about
  things that happen directly with the other language server.
  In a similar example as above: If I send a rename request while in a quarto file it is handled by otter-ls and
  properly passed on to pyright in a modified form. The variable gets rename in the qmd file and in all python files
  of the project. However, if I send the request while in a python file it get's handled directly by pyright.
  Otter-ls never hears of this, so the variable stays as it is in the qmd file.
- Diagnostics are handled via an autocommand instead of lsp requests to otter-ls for now,
  because they don't require the cursor to be in an otter context. Could be solved more elegantly in the future.
- `telescope` has their own builtin pickers for e.g. lsp references. However, they don't function as a lsp response
  handler, but instead create their own params, send their own request and immidiately handle it.
  As such, you can't use e.g. `require'telescope.builtin'.lsp_references` instead of `vim.lsp.buf.references` with
  otter.nvim for now. A pure handler version of telescope's pickers that can receive our already modified
  responses can change this in the future.
- Formatting requests are tricky. But formatting is handled very well by [conform.nvim](https://github.com/stevearc/conform.nvim)
  also for injected code via their `injected` formatter.
  (TODO: link my conform configs as an example)
- The new implementation is more consistent and reliable, but currently at the expense of being less reliable with completion
  for cases with globally offset code chunks. I'm happy about hints or PR's for those.

