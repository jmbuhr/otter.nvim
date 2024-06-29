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
  local client_id = vim.lsp.start({
    name = "otter-ls" .. "[" .. main_nr .. "]",
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    handlers = handlers,
    cmd = function(dispatchers)
      local members = {
        --- Send a request to the otter buffers and handle the response.
        --- The response can optionally be filtered through a function.
        ---@param method string lsp request method. One of ms
        ---@param params table params passed from nvim with the request
        ---@param handler function function(err, response, ctx, conf)
        ---@param _ function notify_reply_callback function. Not currently used
        ---
        -- params are created when vim.lsp.buf.<method> is called
        -- and modified here to be used with the otter buffers
        ---
        --- handler is a callback function that should be called with the result
        --- depending on the method it is either our custom handler
        --- (e.g. for retargeting got-to-definition results)
        --- or the default vim.lsp.handlers[method] handler
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
                -- TODO:
                -- documentRangeFormattingProvider = true,
                -- documentFormattingProvider = true,
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
            -- if we are not in an otter context. there is nothing to be done
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

          -- special modifications to params
          -- for some methods
          if method == ms.textDocument_documentSymbol then
            params.uri = otter_uri
          elseif method == ms.textDocument_references then
            params.context = {
              includeDeclaration = true,
            }
          elseif method == ms.textDocument_completion then
            -- params.position.character = params.position.character
            --   - keeper.get_leading_offset(params.position.line, main_nr)
            -- params.textDocument = {
            --   uri = otter_uri,
            -- }
          end
          -- take care of potential indents
          keeper.modify_position(params, main_nr, true, true)
          -- send the request to the otter buffer
          -- modification of the response is done by
          -- our handler
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

  return client_id
end

return otterlsp
