local cfg = require("otter.config").cfg
local handlers = require("otter.lsp.handlers")
local keeper = require("otter.keeper")
local ms = vim.lsp.protocol.Methods
local fn = require("otter.tools.functions")

local otterlsp = {}

--- @param main_nr integer main buffer
--- @param completion boolean should completion be enabled?
--- @return integer? client_id
otterlsp.start = function(main_nr, completion)
  local main_uri = vim.uri_from_bufnr(main_nr)
  return vim.lsp.start({
    name = "otter-ls",
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    handlers = handlers,
    cmd = function(dispatchers)
      local members = {
        --- Send a request to the otter buffers and handle the response.
        --- The response can optionally be filtered through a function.
        ---@param method string lsp request method. One of ms
        ---@param params table params passed from nvim with the request
        ---@param handler function function(err, response, ctx, conf)
        ---@param _ function notify_reply_callback function. not currently used
        ---
        -- params are created when vim.lsp.buf.<method> is called
        -- and modified here to be used with the otter buffers
        ---
        --- handler is a callback function that should be called with the result
        --- depending on the method it is either our custom handler
        --- (e.g. for retargeting got-to-definition results)
        --- or the default vim.lsp.handlers[method] handler
        --- TODO: since otter-ls has to bring (some of) its own handlers
        --- to handle redirects etc.
        --- those have preference over handlers configured by the user
        --- with vim.lsp.with()
        --- additional entry points for configuring the otter handlers should
        --- be provided eventually
        request = function(method, params, handler, _)
          -- handle initialization first
          if method == ms.initialize then
            local completion_options
            if completion then
              completion_options = {
                triggerCharacters = { "." },
                resolveProvider = true,
              }
            else
              completion_options = false
            end
            local initializeResult = {
              capabilities = {
                hoverProvider = true,
                definitionProvider = true,
                typeDefinitionProvider = true,
                renameProvider = true,
                rangeFormattingProvider = true,
                referencesProvider = true,
                documentSymbolProvider = true,
                completionProvider = completion_options,
              },
              serverInfo = {
                name = "otter-ls",
                version = "2.0.0",
              },
            }
            -- default handler for initialize
            handler(nil, initializeResult)
            return
          end

          -- all other methods need to know the current language and
          -- otter responsible for that language
          local lang, start_row, start_col, end_row, end_col = keeper.get_current_language_context(main_nr)
          if not fn.contains(keeper.rafts[main_nr].languages, lang) then
            -- if we are not in na otter context there is nothing to be done
            return
          end

          -- update the otter buffer of that language
          keeper.sync_raft(main_nr, lang)
          local otter_nr = keeper.rafts[main_nr].buffers[lang]
          local otter_uri = vim.uri_from_bufnr(otter_nr)

          -- general modifications to params for all methods
          params.textDocument = {
            uri = otter_uri,
          }
          -- container to pass additional information to the handlers
          params.otter = {}
          params.otter.main_uri = main_uri

          if method == ms.textDocument_documentSymbol then
            params.uri = otter_uri
          elseif method == ms.textDocument_references then
            params.context = {
              includeDeclaration = true,
            }
          elseif method == ms.textDocument_rangeFormatting then
            params.textDocument = {
              uri = otter_uri,
            }
            params.range = {
              start = { line = start_row, character = start_col },
              ["end"] = { line = end_row, character = end_col },
            }
            assert(end_row)
            local line = vim.api.nvim_buf_get_lines(otter_nr, end_row, end_row + 1, false)[1]
            if line then
              params.range["end"].character = #line
            end
            keeper.modify_position(params, main_nr, true, true)
          end
          -- send the request to the otter buffer
          vim.lsp.buf_request(otter_nr, method, params, handler)
        end,
        notify = function(method, params) end,
        is_closing = function() end,
        terminate = function() end,
      }
      return members
    end,
    before_init = function(_, _) end,
    on_init = function(client, init_result) end,
    root_dir = cfg.lsp.root_dir(),
  })
end

return otterlsp
