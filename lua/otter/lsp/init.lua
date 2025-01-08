-- reference: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
local handlers = require("otter.lsp.handlers")
local keeper = require("otter.keeper")
local ms = vim.lsp.protocol.Methods
local fn = require("otter.tools.functions")

local capabilities = vim.lsp.protocol.make_client_capabilities()

local has_blink, blink = pcall(require, 'blink.cmp')
if has_blink then
  capabilities = blink.get_lsp_capabilities({}, true)
end

local otterls = {}

--- @param main_nr integer main buffer
--- @param completion boolean should completion be enabled?
--- @return integer? client_id
otterls.start = function(main_nr, completion)
  local main_uri = vim.uri_from_bufnr(main_nr)
  local client_id = vim.lsp.start({
    name = "otter-ls" .. "[" .. main_nr .. "]",
    capabilities = capabilities,
    cmd = function(dispatchers)
      local _ = dispatchers
      local members = {
        --- Send a request to the otter buffers and handle the response.
        --- The response can optionally be filtered through a function.
        ---@param method string one of vim.lsp.protocol.Methods
        ---@param params table params passed from nvim with the request params are created when vim.lsp.buf.<method> is called and modified here to be used with the otter buffers
        ---@param handler lsp.Handler function(err, response, ctx) handler is a callback function that should be called with the result depending on the method it is either a user-defined handler (e.g. user's using telescope to list references) or the default vim.lsp.handlers[method] handler
        ---@param _ function notify_reply_callback function. Not currently used
        request = function(method, params, handler, _)
          -- handle initialization first
          if method == ms.initialize then
            local completion_options
            if completion then
              completion_options = {
                triggerCharacters = { "." },
                resolveProvider = true,
                completionItem = {
                  labelDetailsSupport = true,
                }
              }
            else
              completion_options = false
            end
            local initializeResult = {
              capabilities = {
                hoverProvider = true,
                definitionProvider = true,
                implementationProvider = true,
                declarationProvider = true,
                signatureHelpProvider = {
                  triggerCharacters = { "(", "," },
                  retriggerCharacters = {}
                },
                typeDefinitionProvider = true,
                renameProvider = true,
                referencesProvider = true,
                documentSymbolProvider = true,
                completionProvider = completion_options,
                textDocumentSync = {
                  -- we don't do anything with this, yet
                  openClose = true,
                  change = 2, -- 0 none; -- 1 = full; 2 = incremental
                },
              },
              serverInfo = {
                name = "otter-ls",
                version = "2.0.0",
              },
            }

            -- default handler for initialize
            handler(nil, initializeResult, params.context)
            return
          elseif params == nil then
            -- can params be nil?
            return
          elseif method == ms.shutdown then
            -- TODO: how do we actually stop otter-ls?
            -- it's just a function in memory,
            -- no external process
            handler(nil, nil, params.context)
            return
          elseif method == ms.exit then
            handler(nil, nil, params.context)
            return
          end

          -- container to pass additional information to otter and the handlers
          if params.otter == nil then
            params.otter = {}
          end

          -- all other methods need to know the current language and
          -- otter responsible for that language

          -- lang can be explicitly passed to otter-ls
          local lang = params.otter.lang
          if lang == nil then
            -- otherwise it is determined by cursor position
            lang, _, _, _, _ = keeper.get_current_language_context(main_nr)
          end

          local has_otter = fn.contains(keeper.rafts[main_nr].languages, lang)
          if not has_otter then
            -- if we don't have an otter for lang, there is nothing to be done
            handler(nil, nil, params.context)
            return
          end

          local otter_nr = keeper.rafts[main_nr].buffers[lang]
          local otter_uri = vim.uri_from_bufnr(otter_nr)

          -- get clients attached to otter buffer
          local otterclients = vim.lsp.get_clients({ bufnr = otter_nr })
          -- collect capabilities
          local supports_method = false
          for _, client in pairs(otterclients) do
            if client.supports_method(method) then
              supports_method = true
            end
          end
          if not supports_method then
            -- no server attached to the otter buffer supports this method
            handler(nil, nil, params.context)
            return
          end

          -- update the otter buffer of that language
          local success = keeper.sync_raft(main_nr, lang)
          if not success then
            -- no otter buffer for lang
            handler(nil, nil, params.context)
            return
          end

          -- general modifications to params for all methods
          params.textDocument = {
            uri = otter_uri,
          }
          params.otter.main_nr = main_nr
          params.otter.main_uri = main_uri
          params.otter.otter_uri = otter_uri

          -- special modifications to params
          -- for some methods
          if method == ms.textDocument_documentSymbol then
            params.uri = otter_uri
          elseif method == ms.textDocument_references then
            params.context = {
              includeDeclaration = true,
            }
          end
          -- take care of potential indents
          keeper.modify_position(params, main_nr, true, true)
          -- send the request to the otter buffer
          -- modification of the response is done by our handler
          -- and then passed on to the default handler or user-defined handler
          vim.lsp.buf_request(otter_nr, method, params, function(err, result, ctx)
            if handlers[method] ~= nil then
              err, result, ctx = handlers[method](err, result, ctx)
            end
            handler(err, result, ctx)
          end)
        end,
        --- Handle notify events
        --- @param method string one of vim.lsp.protocol.Methods
        --- @param params table
        notify = function(method, params)
          local _, _ = method, params
          -- we don't actually notify otter buffers
          -- they get their change notifications
          -- via nvim's clients attached to
          -- the buffers when we sync their text
        end,
        is_closing = function() end,
        terminate = function() end,
      }
      return members
    end,
    init_options = {},
    ---@param params lsp.ConfigurationParams
    ---@param config table
    before_init = function(params, config)
      local _, _ = params, config
      -- nothing to be done
    end,
    ---@param client vim.lsp.Client
    ---@param initialize_result lsp.InitializeResult
    on_init = function(client, initialize_result)
      local _, _ = client, initialize_result
      -- nothing to be done
    end,
    root_dir = require("otter.config").cfg.lsp.root_dir(),
    ---@param code integer
    ---@param signal integer
    ---@param client_id integer
    on_exit = function(code, signal, client_id)
      local _, _, _ = code, signal, client_id
      -- nothing to be done
    end,
  })

  return client_id
end

--- for reference
--- lsp._request_name_to_capability = {
---   [ms.textDocument_hover] = { 'hoverProvider' },
---   [ms.textDocument_signatureHelp] = { 'signatureHelpProvider' },
---   [ms.textDocument_definition] = { 'definitionProvider' },
---   [ms.textDocument_implementation] = { 'implementationProvider' },
---   [ms.textDocument_declaration] = { 'declarationProvider' },
---   [ms.textDocument_typeDefinition] = { 'typeDefinitionProvider' },
---   [ms.textDocument_documentSymbol] = { 'documentSymbolProvider' },
---   [ms.textDocument_prepareCallHierarchy] = { 'callHierarchyProvider' },
---   [ms.callHierarchy_incomingCalls] = { 'callHierarchyProvider' },
---   [ms.callHierarchy_outgoingCalls] = { 'callHierarchyProvider' },
---   [ms.textDocument_prepareTypeHierarchy] = { 'typeHierarchyProvider' },
---   [ms.typeHierarchy_subtypes] = { 'typeHierarchyProvider' },
---   [ms.typeHierarchy_supertypes] = { 'typeHierarchyProvider' },
---   [ms.textDocument_rename] = { 'renameProvider' },
---   [ms.textDocument_prepareRename] = { 'renameProvider', 'prepareProvider' },
---   [ms.textDocument_codeAction] = { 'codeActionProvider' },
---   [ms.textDocument_codeLens] = { 'codeLensProvider' },
---   [ms.codeLens_resolve] = { 'codeLensProvider', 'resolveProvider' },
---   [ms.codeAction_resolve] = { 'codeActionProvider', 'resolveProvider' },
---   [ms.workspace_executeCommand] = { 'executeCommandProvider' },
---   [ms.workspace_symbol] = { 'workspaceSymbolProvider' },
---   [ms.textDocument_references] = { 'referencesProvider' },
---   [ms.textDocument_rangeFormatting] = { 'documentRangeFormattingProvider' },
---   [ms.textDocument_formatting] = { 'documentFormattingProvider' },
---   [ms.textDocument_completion] = { 'completionProvider' },
---   [ms.textDocument_documentHighlight] = { 'documentHighlightProvider' },
---   [ms.textDocument_semanticTokens_full] = { 'semanticTokensProvider' },
---   [ms.textDocument_semanticTokens_full_delta] = { 'semanticTokensProvider' },
---   [ms.textDocument_inlayHint] = { 'inlayHintProvider' },
---   [ms.textDocument_diagnostic] = { 'diagnosticProvider' },
---   [ms.inlayHint_resolve] = { 'inlayHintProvider', 'resolveProvider' },
---   [ms.textDocument_documentLink] = { 'documentLinkProvider' },
---   [ms.documentLink_resolve] = { 'documentLinkProvider', 'resolveProvider' },
---   [ms.textDocument_didClose] = { 'textDocumentSync', 'openClose' },
---   [ms.textDocument_didOpen] = { 'textDocumentSync', 'openClose' },
---   [ms.textDocument_willSave] = { 'textDocumentSync', 'willSave' },
---   [ms.textDocument_willSaveWaitUntil] = { 'textDocumentSync', 'willSaveWaitUntil' },
--- }

return otterls
