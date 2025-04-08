# Changelog

## [2.11.2](https://github.com/jmbuhr/otter.nvim/compare/v2.11.1...v2.11.2) (2025-04-08)


### Bug Fixes

* make otter buffers writable and always close on ExitPre. fixes [#228](https://github.com/jmbuhr/otter.nvim/issues/228) ([6332f4c](https://github.com/jmbuhr/otter.nvim/commit/6332f4c6fe05a98ddcadb772d5065f0498b4f3a0))
* overwrite BufWriteCmd for otterbuffers, preventing them from being written to disk unless config.buffers.write_to_disk is set to true ([d63eeb8](https://github.com/jmbuhr/otter.nvim/commit/d63eeb8bcc7267ff5b32e2160f52edefb36a79e4))

## [2.11.1](https://github.com/jmbuhr/otter.nvim/compare/v2.11.0...v2.11.1) (2025-04-04)


### Bug Fixes

* fix [#227](https://github.com/jmbuhr/otter.nvim/issues/227) and format with stylua. Also closes [#230](https://github.com/jmbuhr/otter.nvim/issues/230) ([b830d6c](https://github.com/jmbuhr/otter.nvim/commit/b830d6c76cf21b97159770f913d3ff28027c46a1))

## [2.11.0](https://github.com/jmbuhr/otter.nvim/compare/v2.10.0...v2.11.0) (2025-03-26)


### Features

* add postamble support ([61868fc](https://github.com/jmbuhr/otter.nvim/commit/61868fce68c489c073a822763ed6fe62560e2060))

## [2.10.0](https://github.com/jmbuhr/otter.nvim/compare/v2.9.0...v2.10.0) (2025-03-24)


### Features

* provide usercommands for common actions ([6227b9a](https://github.com/jmbuhr/otter.nvim/commit/6227b9a27de47708350231129140c6e4d26e025f))

## [2.9.0](https://github.com/jmbuhr/otter.nvim/compare/v2.8.0...v2.9.0) (2025-03-17)


### Features

* add gleam to extensions ([#223](https://github.com/jmbuhr/otter.nvim/issues/223)) ([474629b](https://github.com/jmbuhr/otter.nvim/commit/474629b1b40d712ce9798ad96132670f6159469c))


### Bug Fixes

* match error message for textlock and catch. fixes [#178](https://github.com/jmbuhr/otter.nvim/issues/178) ([#219](https://github.com/jmbuhr/otter.nvim/issues/219)) ([e37053d](https://github.com/jmbuhr/otter.nvim/commit/e37053d2c6a17463e705483122eee04d41e3d4af))

## [2.8.0](https://github.com/jmbuhr/otter.nvim/compare/v2.7.0...v2.8.0) (2025-03-03)


### Features

* add ignore_pattern option to filter language lines ([#217](https://github.com/jmbuhr/otter.nvim/issues/217)) ([4ac831e](https://github.com/jmbuhr/otter.nvim/commit/4ac831e579952acebf53fb746309c9131a56233c))

## [2.7.0](https://github.com/jmbuhr/otter.nvim/compare/v2.6.1...v2.7.0) (2025-02-28)


### Features

* add fish to extensions ([#214](https://github.com/jmbuhr/otter.nvim/issues/214)) ([213d1f7](https://github.com/jmbuhr/otter.nvim/commit/213d1f7a47be788f430099a110456a06167ab0f4))
* preamble ([#212](https://github.com/jmbuhr/otter.nvim/issues/212)) ([b2e2d6a](https://github.com/jmbuhr/otter.nvim/commit/b2e2d6aa3829db4540b0cf372243bb448edc344a))


### Bug Fixes

* filter special characters from language string captures. fixes [#211](https://github.com/jmbuhr/otter.nvim/issues/211) ([085b2b0](https://github.com/jmbuhr/otter.nvim/commit/085b2b0c815103047f8db18a0f71a561462606b5))
* make lspconfig augroup a warning instead of error ([21f042f](https://github.com/jmbuhr/otter.nvim/commit/21f042f4d1a9ff4788634ad76a10033eed13c7f2))

## [2.6.1](https://github.com/jmbuhr/otter.nvim/compare/v2.6.0...v2.6.1) (2025-02-03)


### Bug Fixes

* fix [#204](https://github.com/jmbuhr/otter.nvim/issues/204) via Cleanup ([#205](https://github.com/jmbuhr/otter.nvim/issues/205)) ([0d7f464](https://github.com/jmbuhr/otter.nvim/commit/0d7f464ab50391d6d708a2ed01f132d22c284d31))

## [2.6.0](https://github.com/jmbuhr/otter.nvim/compare/v2.5.1...v2.6.0) (2025-01-09)


### Features

* extened blink capabilites ([4f53b89](https://github.com/jmbuhr/otter.nvim/commit/4f53b8944017a937d2cfc9b50794f42674b47cab))


### Bug Fixes

* always call the handler for a request response even if the result ([4f53b89](https://github.com/jmbuhr/otter.nvim/commit/4f53b8944017a937d2cfc9b50794f42674b47cab))
* document config and make sure config is required first in init ([4f53b89](https://github.com/jmbuhr/otter.nvim/commit/4f53b8944017a937d2cfc9b50794f42674b47cab))
* textlock ([#195](https://github.com/jmbuhr/otter.nvim/issues/195)) ([4f53b89](https://github.com/jmbuhr/otter.nvim/commit/4f53b8944017a937d2cfc9b50794f42674b47cab))

## [2.5.1](https://github.com/jmbuhr/otter.nvim/compare/v2.5.0...v2.5.1) (2024-12-17)


### Bug Fixes

* use schedule_wrap to avoid text_lock ([#190](https://github.com/jmbuhr/otter.nvim/issues/190)) ([964b012](https://github.com/jmbuhr/otter.nvim/commit/964b012f74f5d9c57184e9fcf350775344db6053))

## [2.5.0](https://github.com/jmbuhr/otter.nvim/compare/v2.4.0...v2.5.0) (2024-08-25)


### Features

* Check capabilities before sending request to otter buffer ([#169](https://github.com/jmbuhr/otter.nvim/issues/169)) ([18fcdbb](https://github.com/jmbuhr/otter.nvim/commit/18fcdbbbf9dbc09febf7a1bbdca46b5310b3aa84))

## [2.4.0](https://github.com/jmbuhr/otter.nvim/compare/v2.3.0...v2.4.0) (2024-08-13)


### Features

* add pyodide and webr extensions and sort alphabetically ([54914ff](https://github.com/jmbuhr/otter.nvim/commit/54914ff27190a4f5b10faa21a240c0a2314cf174))

## [2.3.0](https://github.com/jmbuhr/otter.nvim/compare/v2.2.2...v2.3.0) (2024-07-22)


### Features

* inject otter handlers in between manually passed or default ([a6037d4](https://github.com/jmbuhr/otter.nvim/commit/a6037d4beb20cdeff8103e6bafa622548ad2df5d))

## [2.2.2](https://github.com/jmbuhr/otter.nvim/compare/v2.2.1...v2.2.2) (2024-07-16)


### Bug Fixes

* temporary fix for [#163](https://github.com/jmbuhr/otter.nvim/issues/163) ([fe68b41](https://github.com/jmbuhr/otter.nvim/commit/fe68b41c45efd830a5a75823752539a2717c2496))

## [2.2.1](https://github.com/jmbuhr/otter.nvim/compare/v2.2.0...v2.2.1) (2024-07-09)


### Bug Fixes

* only start activate otter-ls if code chunks are found. fixes [#161](https://github.com/jmbuhr/otter.nvim/issues/161) ([dc90ffb](https://github.com/jmbuhr/otter.nvim/commit/dc90ffbc2e51839d88405cf38f75bdf172b798e7))

## [2.2.0](https://github.com/jmbuhr/otter.nvim/compare/v2.1.0...v2.2.0) (2024-07-06)


### Features

* add vim extension ([935aeb5](https://github.com/jmbuhr/otter.nvim/commit/935aeb5756de2024697194c83fe0f16951818b1a))


### Bug Fixes

* don't add an otter for the language of the main buffer ([66b3a33](https://github.com/jmbuhr/otter.nvim/commit/66b3a33735eda2f28025ac2f55c77faf9d1b4b68))

## [2.1.0](https://github.com/jmbuhr/otter.nvim/compare/v2.0.3...v2.1.0) (2024-07-04)


### Features

* accept custom lsp params. Allow to explicitly request language ([f583efd](https://github.com/jmbuhr/otter.nvim/commit/f583efd7c9b3c520ae88dd6fb847135a4dd2b20f))


### Bug Fixes

* lsps not updating with new contents ([#155](https://github.com/jmbuhr/otter.nvim/issues/155)) ([3638522](https://github.com/jmbuhr/otter.nvim/commit/3638522d134e64d9e46c35747383cda39c4aa657))

## [2.0.3](https://github.com/jmbuhr/otter.nvim/compare/v2.0.2...v2.0.3) (2024-06-30)


### Bug Fixes

* correctly specify signatureHelpProvider. fixes [#148](https://github.com/jmbuhr/otter.nvim/issues/148) ([01adf50](https://github.com/jmbuhr/otter.nvim/commit/01adf500832ef9603c6330a223c962aa2f80808c))
* handle otter-ls detach and re-attach for otter.deactivate ([893934b](https://github.com/jmbuhr/otter.nvim/commit/893934b932ccc62736c0acca32cf6b5910f24d0e))

## [2.0.2](https://github.com/jmbuhr/otter.nvim/compare/v2.0.1...v2.0.2) (2024-06-30)


### Bug Fixes

* remove diagnostics autocommand on otter.deactivate ([411fd22](https://github.com/jmbuhr/otter.nvim/commit/411fd2264a8ef35c48187f071b1b00b46d13f9a5))

## [2.0.1](https://github.com/jmbuhr/otter.nvim/compare/v2.0.0...v2.0.1) (2024-06-30)


### Bug Fixes

* users' `lsp.root_dir` config not respected when starting lsp ([#142](https://github.com/jmbuhr/otter.nvim/issues/142)) ([8ff9adc](https://github.com/jmbuhr/otter.nvim/commit/8ff9adcd7062507216e2d2ec69e951a9802a906d))

## [2.0.0](https://github.com/jmbuhr/otter.nvim/compare/v1.15.1...v2.0.0) (2024-06-29)


### ⚠ BREAKING CHANGES

* turn otter into a builtin lsp server-client combo to avoid manual configuration ([#137](https://github.com/jmbuhr/otter.nvim/issues/137))

### Features

* turn otter into a builtin lsp server-client combo to avoid manual configuration ([#137](https://github.com/jmbuhr/otter.nvim/issues/137)) ([4d6c335](https://github.com/jmbuhr/otter.nvim/commit/4d6c3355413d01503295bcec437c4380a9ab6a2e))

## [1.15.1](https://github.com/jmbuhr/otter.nvim/compare/v1.15.0...v1.15.1) (2024-06-09)


### Bug Fixes

* [#131](https://github.com/jmbuhr/otter.nvim/issues/131) ([#132](https://github.com/jmbuhr/otter.nvim/issues/132)) ([083407a](https://github.com/jmbuhr/otter.nvim/commit/083407ae9405b414ac4828e19f9b1e9f0e1ac102))
* fix [#135](https://github.com/jmbuhr/otter.nvim/issues/135) ([#136](https://github.com/jmbuhr/otter.nvim/issues/136)) ([2d028a9](https://github.com/jmbuhr/otter.nvim/commit/2d028a98edb29c49cd5604f8acd65031efe56a7e))

## [1.15.0](https://github.com/jmbuhr/otter.nvim/compare/v1.14.0...v1.15.0) (2024-05-09)


### Features

* add fallback to type definition + type annotations ([#126](https://github.com/jmbuhr/otter.nvim/issues/126)) ([8198492](https://github.com/jmbuhr/otter.nvim/commit/819849249ec87b4dc429c24513df7e6efcacf56c))
* add webc + sort alphabetically ([#128](https://github.com/jmbuhr/otter.nvim/issues/128)) ([0504278](https://github.com/jmbuhr/otter.nvim/commit/0504278089a6f08e08d64245717171cdc15b33f6))

## [1.14.0](https://github.com/jmbuhr/otter.nvim/compare/v1.13.0...v1.14.0) (2024-05-01)


### Features

* forward custom fallbacks from ask_ functions to send_request ([#123](https://github.com/jmbuhr/otter.nvim/issues/123)) ([f963beb](https://github.com/jmbuhr/otter.nvim/commit/f963beb52d0e02c55bb903ad4b49957bbcc455f3)), closes [#122](https://github.com/jmbuhr/otter.nvim/issues/122)

## [1.13.0](https://github.com/jmbuhr/otter.nvim/compare/v1.12.2...v1.13.0) (2024-04-25)


### Features

* **extensions.lua:** add clojure ([#120](https://github.com/jmbuhr/otter.nvim/issues/120)) ([ab3d90f](https://github.com/jmbuhr/otter.nvim/commit/ab3d90faa7b7eb596a0d66f67a8ff16a830f872d))
* **extensions.lua:** add conjure ([#118](https://github.com/jmbuhr/otter.nvim/issues/118)) ([3b636d8](https://github.com/jmbuhr/otter.nvim/commit/3b636d8040d2357bcd47d40a91b1700a20bdf09b))

## [1.12.2](https://github.com/jmbuhr/otter.nvim/compare/v1.12.1...v1.12.2) (2024-04-09)


### Bug Fixes

* write out file once before lsp attach if config.buffers.write_to_disk ([b90f0e5](https://github.com/jmbuhr/otter.nvim/commit/b90f0e5e3f3cf421aa95c0f8d9139430f4bac0b7)), closes [#116](https://github.com/jmbuhr/otter.nvim/issues/116)

## [1.12.1](https://github.com/jmbuhr/otter.nvim/compare/v1.12.0...v1.12.1) (2024-03-25)


### Bug Fixes

* fix [#70](https://github.com/jmbuhr/otter.nvim/issues/70) ([3797723](https://github.com/jmbuhr/otter.nvim/commit/3797723a9fc402604f03715665f8462d29ced002))

## [1.12.0](https://github.com/jmbuhr/otter.nvim/compare/v1.11.0...v1.12.0) (2024-03-24)


### Features

* add .json to extensions.lua ([#112](https://github.com/jmbuhr/otter.nvim/issues/112)) ([6b81cef](https://github.com/jmbuhr/otter.nvim/commit/6b81cefd0445d277b473c57e873a1cf97e6cca81))

## [1.11.0](https://github.com/jmbuhr/otter.nvim/compare/v1.10.0...v1.11.0) (2024-03-20)


### Features

* add .sh to extensions.lua ([#110](https://github.com/jmbuhr/otter.nvim/issues/110)) ([b368b6f](https://github.com/jmbuhr/otter.nvim/commit/b368b6f4656be65e6ce9dabf4ff5c2b4c9fa67a8))

## [1.10.0](https://github.com/jmbuhr/otter.nvim/compare/v1.9.2...v1.10.0) (2024-03-17)


### Features

* add htmldjango extension ([#107](https://github.com/jmbuhr/otter.nvim/issues/107)) ([12894e0](https://github.com/jmbuhr/otter.nvim/commit/12894e015eb2aedb8f2a1d23e68aa91c917fcc66))

## [1.9.2](https://github.com/jmbuhr/otter.nvim/compare/v1.9.1...v1.9.2) (2024-03-04)


### Bug Fixes

* diagnostics not updating ([#105](https://github.com/jmbuhr/otter.nvim/issues/105)) ([8bdc078](https://github.com/jmbuhr/otter.nvim/commit/8bdc07896241a1ba32819146492a7cce4f621a14))
* fix [#101](https://github.com/jmbuhr/otter.nvim/issues/101) ([a16df0a](https://github.com/jmbuhr/otter.nvim/commit/a16df0a1b77576b0ef4e808328e6e3434675703a))
* replace deprecated nvim_buf_set_option ([91883c2](https://github.com/jmbuhr/otter.nvim/commit/91883c210c3739c57013eaefd20d13ecdf9faba3))

## [1.9.1](https://github.com/jmbuhr/otter.nvim/compare/v1.9.0...v1.9.1) (2024-03-03)


### Bug Fixes

* fix lsp formatting response handling ([528f14d](https://github.com/jmbuhr/otter.nvim/commit/528f14d32159dd360fb8ca0d31df65cfb433659b))

## [1.9.0](https://github.com/jmbuhr/otter.nvim/compare/v1.8.0...v1.9.0) (2024-03-02)


### Features

* handle leading whitespace ([#86](https://github.com/jmbuhr/otter.nvim/issues/86)) ([9c2bc06](https://github.com/jmbuhr/otter.nvim/commit/9c2bc061f2890835d65fc6fd75703f16169bf507))

## [1.8.0](https://github.com/jmbuhr/otter.nvim/compare/v1.7.2...v1.8.0) (2024-03-02)


### Features

* activate all languages for which extensions are known by passing nil ([#95](https://github.com/jmbuhr/otter.nvim/issues/95)) ([6234723](https://github.com/jmbuhr/otter.nvim/commit/6234723e8852de72da29e045a39c0d0f8e1be0e6))
* add observable js (ojs) as js extension ([0674acb](https://github.com/jmbuhr/otter.nvim/commit/0674acbbebd842e7df65d4cc81d21b93e5e5bb71))
* otter.deactivate function ([#96](https://github.com/jmbuhr/otter.nvim/issues/96)) ([519c777](https://github.com/jmbuhr/otter.nvim/commit/519c777704c01d6951b78379843f84e38726ebc0))


### Bug Fixes

* only attempt to activate found languages with found extension ([5a4967c](https://github.com/jmbuhr/otter.nvim/commit/5a4967c8970ebb80c8d67327008f43a97d1c1ec6))
* sync diagnostics on activate ([#98](https://github.com/jmbuhr/otter.nvim/issues/98)) ([dad5c46](https://github.com/jmbuhr/otter.nvim/commit/dad5c46495f16cc47e82618ac0ee7391aa77388e))
* use proper treesiter iteration from nvim nightly to handle offsets ([#100](https://github.com/jmbuhr/otter.nvim/issues/100)) ([53165d7](https://github.com/jmbuhr/otter.nvim/commit/53165d7b4d5ecb861092e4f4b9d8b61bb83de78f))

## [1.7.2](https://github.com/jmbuhr/otter.nvim/compare/v1.7.1...v1.7.2) (2024-02-19)


### Bug Fixes

* make helper function is_otter_language_context actually return ([5572d0b](https://github.com/jmbuhr/otter.nvim/commit/5572d0ba84d775f3510848611065838c4632a63f))

## [1.7.1](https://github.com/jmbuhr/otter.nvim/compare/v1.7.0...v1.7.1) (2024-02-12)


### Bug Fixes

* empty metadata caused treesitter directives like offset to be ignored ([#80](https://github.com/jmbuhr/otter.nvim/issues/80)) ([0fd09ca](https://github.com/jmbuhr/otter.nvim/commit/0fd09ca26c1525619aa11dc90a9ac715f32ecb32))
* **opts:** failing to opt-out features (completion and diagnostics) ([#83](https://github.com/jmbuhr/otter.nvim/issues/83)) ([0eeb4f9](https://github.com/jmbuhr/otter.nvim/commit/0eeb4f9bd852aee07c5450aae8010d735e30bd86))

## [1.7.0](https://github.com/jmbuhr/otter.nvim/compare/v1.6.0...v1.7.0) (2024-01-04)


### Features

* trigger release ([51e69ba](https://github.com/jmbuhr/otter.nvim/commit/51e69bafb8ca74c0581ee8b1a16b6d6c7c85ab6e))

## [1.6.0](https://github.com/jmbuhr/otter.nvim/compare/v1.5.0...v1.6.0) (2023-12-22)


### Features

* add dot language ([3473c3e](https://github.com/jmbuhr/otter.nvim/commit/3473c3e68ed29639f7665cea331bf26adf2b03c0))


### Bug Fixes

* use complete language name if no extension is found ([a4c6cd8](https://github.com/jmbuhr/otter.nvim/commit/a4c6cd8ca259efe58bd2079b90483de7f8e16e2c))

## [1.5.0](https://github.com/jmbuhr/otter.nvim/compare/v1.4.1...v1.5.0) (2023-12-02)


### Features

* remove wrapping quotes from injections and make this configurable. Fixes [#72](https://github.com/jmbuhr/otter.nvim/issues/72) ([#73](https://github.com/jmbuhr/otter.nvim/issues/73)) ([0678bf3](https://github.com/jmbuhr/otter.nvim/commit/0678bf3f3db6a4234fea47d49d161b85a22c67d5))

## [1.4.1](https://github.com/jmbuhr/otter.nvim/compare/v1.4.0...v1.4.1) (2023-10-25)


### Bug Fixes

* config use ([ea23615](https://github.com/jmbuhr/otter.nvim/commit/ea236158460eb100b7b126226340bcc70291180b))

## [1.4.0](https://github.com/jmbuhr/otter.nvim/compare/v1.3.1...v1.4.0) (2023-10-25)


### Features

* add option to set otter buffer filetype ([e302002](https://github.com/jmbuhr/otter.nvim/commit/e30200211aed45cb3daf1c458f23f2645f9abba9)), closes [#63](https://github.com/jmbuhr/otter.nvim/issues/63)


### Bug Fixes

* re-add [#64](https://github.com/jmbuhr/otter.nvim/issues/64) ([a6d3786](https://github.com/jmbuhr/otter.nvim/commit/a6d37869b04a0ed07815433974db6b8b4fe01ae5))

## [1.3.1](https://github.com/jmbuhr/otter.nvim/compare/v1.3.0...v1.3.1) (2023-10-25)


### Performance Improvements

* parsing optimizations ([#60](https://github.com/jmbuhr/otter.nvim/issues/60)) ([4b111ee](https://github.com/jmbuhr/otter.nvim/commit/4b111ee2d1fe38c277ce22b9ed19c007815fe5c3))

## [1.3.0](https://github.com/jmbuhr/otter.nvim/compare/v1.2.1...v1.3.0) (2023-10-24)


### Features

* Add Markdown and Elixir extensions ([#64](https://github.com/jmbuhr/otter.nvim/issues/64)) ([ecb2f21](https://github.com/jmbuhr/otter.nvim/commit/ecb2f21abd109682bd60ce07d5ec22649e700a8f))

## [1.2.1](https://github.com/jmbuhr/otter.nvim/compare/v1.2.0...v1.2.1) (2023-09-16)


### Bug Fixes

* prevent accidentially leaving otter completion on outside of main ([229690a](https://github.com/jmbuhr/otter.nvim/commit/229690a58808fe0a82641b50d671d22d7174c497))

## [1.2.0](https://github.com/jmbuhr/otter.nvim/compare/v1.1.0...v1.2.0) (2023-08-27)


### Features

* format current code chunk ([01578a4](https://github.com/jmbuhr/otter.nvim/commit/01578a40b9cece7a4a4e51e903b8a255c9b1f42a))

## [1.1.0](https://github.com/jmbuhr/otter.nvim/compare/v1.0.3...v1.1.0) (2023-08-23)


### Features

* also get injection.language directly from metadata if available ([94f642c](https://github.com/jmbuhr/otter.nvim/commit/94f642c06d03d7b91d857efc30ede01b96d53101))

## [1.0.3](https://github.com/jmbuhr/otter.nvim/compare/v1.0.2...v1.0.3) (2023-08-22)


### Bug Fixes

* fix [#51](https://github.com/jmbuhr/otter.nvim/issues/51) completion items come up multiple times ([#52](https://github.com/jmbuhr/otter.nvim/issues/52)) ([ef79ee7](https://github.com/jmbuhr/otter.nvim/commit/ef79ee7f2adc4d8e6934c81595c6bbd820af5f87))

## [1.0.2](https://github.com/jmbuhr/otter.nvim/compare/v1.0.1...v1.0.2) (2023-08-01)


### Bug Fixes

* fix document/rename ([3bec604](https://github.com/jmbuhr/otter.nvim/commit/3bec6044f39e4b6de98559d80af214aad024ac14))

## [1.0.1](https://github.com/jmbuhr/otter.nvim/compare/v1.0.0...v1.0.1) (2023-07-15)


### Bug Fixes

* fix [#47](https://github.com/jmbuhr/otter.nvim/issues/47) ([18a33c9](https://github.com/jmbuhr/otter.nvim/commit/18a33c94a0ac34fdc9bac8bb78e120a2f4bf6cc8))

## [1.0.0](https://github.com/jmbuhr/otter.nvim/compare/v0.17.0...v1.0.0) (2023-07-11)


### ⚠ BREAKING CHANGES

* trigger version

### Bug Fixes

* trigger version ([25c177b](https://github.com/jmbuhr/otter.nvim/commit/25c177bdf579c545d9780010cb645741e75e1e8f))

## [0.17.0](https://github.com/jmbuhr/otter.nvim/compare/v0.16.1...v0.17.0) (2023-06-28)


### Features

* **lsp:** ask_type_definition and ask_document_symbol ([6a5d874](https://github.com/jmbuhr/otter.nvim/commit/6a5d874b4b425f14afc56303d28cdbe6af53525a))
* use node:range instead of node text to get lines ([963a7b3](https://github.com/jmbuhr/otter.nvim/commit/963a7b3077e218cf6284da0666515ebfb56d13f9))


### Bug Fixes

* silently return if no response by the language server or the filter ([3b5d856](https://github.com/jmbuhr/otter.nvim/commit/3b5d856290a5f2b62b58be6b437e4bf02e02e779))

## [0.16.1](https://github.com/jmbuhr/otter.nvim/compare/v0.16.0...v0.16.1) (2023-06-06)


### Bug Fixes

* deactivate otter cmp source when not in the main buffer ([1f7dfcd](https://github.com/jmbuhr/otter.nvim/commit/1f7dfcd877b5c3d290722fdf158e77d259ca7957))

## [0.16.0](https://github.com/jmbuhr/otter.nvim/compare/v0.15.1...v0.16.0) (2023-06-06)


### Features

* get_language_lines_around cursor ([864db19](https://github.com/jmbuhr/otter.nvim/commit/864db19aeaa26f85ee18f9a6fc0e582e5cd14155))

## [0.15.1](https://github.com/jmbuhr/otter.nvim/compare/v0.15.0...v0.15.1) (2023-06-05)


### Performance Improvements

* don't set ft on otter buffers ([#41](https://github.com/jmbuhr/otter.nvim/issues/41)) ([6aa0699](https://github.com/jmbuhr/otter.nvim/commit/6aa0699c4a64980c1d77d951dc2dbf1798c870e3))

## [0.15.0](https://github.com/jmbuhr/otter.nvim/compare/v0.14.0...v0.15.0) (2023-06-03)


### Features

* use injections ([c05e899](https://github.com/jmbuhr/otter.nvim/commit/c05e899dc867360d41800cf791759e77f91bdbbf))

## [0.14.0](https://github.com/jmbuhr/otter.nvim/compare/v0.13.1...v0.14.0) (2023-05-31)


### Features

* **query:** add org mode ([9fffb91](https://github.com/jmbuhr/otter.nvim/commit/9fffb91915007b9fb65ebc051df105ff80ce1100))

## [0.13.1](https://github.com/jmbuhr/otter.nvim/compare/v0.13.0...v0.13.1) (2023-05-28)


### Bug Fixes

* ask_references and return early when outside of otter context ([4fbc0d6](https://github.com/jmbuhr/otter.nvim/commit/4fbc0d6b92837bb38a98d8d991ab412fa4e3d729))

## [0.13.0](https://github.com/jmbuhr/otter.nvim/compare/v0.12.0...v0.13.0) (2023-05-26)


### Features

* add otter.ask_references ([6249847](https://github.com/jmbuhr/otter.nvim/commit/6249847cab5264b6c9a2bdd1820ec5c85dfbc204))
* add otter.ask_rename ([dde4ef5](https://github.com/jmbuhr/otter.nvim/commit/dde4ef5e49f063a495876bc20fa7ed1e3277adea))
* allow custom handlers for lsp request responses ([54320db](https://github.com/jmbuhr/otter.nvim/commit/54320db67d61d8f9d58535e03f67493949822369))

## [0.12.0](https://github.com/jmbuhr/otter.nvim/compare/v0.11.0...v0.12.0) (2023-05-06)


### Features

* more way to get code chunks ([74e569c](https://github.com/jmbuhr/otter.nvim/commit/74e569cba137439f7796f511979c7a77f32ed7bd))

## [0.11.0](https://github.com/jmbuhr/otter.nvim/compare/v0.10.1...v0.11.0) (2023-05-01)


### Features

* omit `eval: false` code blocks (for QuartoSend) ([ae3b91b](https://github.com/jmbuhr/otter.nvim/commit/ae3b91b3cd1eb4667c6783979825706c459fb45a))

## [0.10.1](https://github.com/jmbuhr/otter.nvim/compare/v0.10.0...v0.10.1) (2023-04-25)


### Bug Fixes

* Set buftype=nowrite for otter buffers. PR[#30](https://github.com/jmbuhr/otter.nvim/issues/30) from yongrenjie/main ([ee2f5f6](https://github.com/jmbuhr/otter.nvim/commit/ee2f5f6d72a2dd8b9c06a9592520e488471f1537))

## [0.10.0](https://github.com/jmbuhr/otter.nvim/compare/v0.9.0...v0.10.0) (2023-04-20)


### Features

* helper functions to get the current language of a chode chunk and ([9c302e7](https://github.com/jmbuhr/otter.nvim/commit/9c302e7e22656d6aa0ba75c545ecc59291d2a14e))

## [0.9.0](https://github.com/jmbuhr/otter.nvim/compare/v0.8.1...v0.9.0) (2023-04-09)


### Features

* allow specifying which langueage to update ([3a818b0](https://github.com/jmbuhr/otter.nvim/commit/3a818b096482483e9fab7cf097b51328a0d9a75c))
* function to determine if within a code chunk of a certain language ([c5e5828](https://github.com/jmbuhr/otter.nvim/commit/c5e5828fc02c8daf3faaa418d1b9014b0765c3e6))
* use treesitter functions from nvim v0.9.0 nightly! ([6bb1170](https://github.com/jmbuhr/otter.nvim/commit/6bb11702656573ed0c0e0d6ec99cc536e11162ac))


### Bug Fixes

* attach lsp server on activation ([d3044fd](https://github.com/jmbuhr/otter.nvim/commit/d3044fd11ac8abce8212953414ab4dd4b7e3d3ac))
* **CI:** ... ([9cae1f3](https://github.com/jmbuhr/otter.nvim/commit/9cae1f3bc587087a4b93e59c46d3e9c7f0368e7c))
* CI... ([c31abb0](https://github.com/jmbuhr/otter.nvim/commit/c31abb09712c6433489e1d2c9be1065c7a4a2f9e))
* update treesitter in remaining places ([9fa88ca](https://github.com/jmbuhr/otter.nvim/commit/9fa88ca1ac18293513edfde7f63abcf576f2026a))
* use nvim.appimage for CI ([8bf3e54](https://github.com/jmbuhr/otter.nvim/commit/8bf3e5462c29978917621d160e02b0138f4923a9))
* use save instead of write to export otter buffers ([7ced7e9](https://github.com/jmbuhr/otter.nvim/commit/7ced7e9af49fa6e0d8f9fe9beec60e8ae3bf9a42))


### Performance Improvements

* faster otter buffer line updates ([4ff9d1d](https://github.com/jmbuhr/otter.nvim/commit/4ff9d1dd609303beca1e09fd3823dbb88424e718))
* only set buffer options on activation, not sync ([1159b49](https://github.com/jmbuhr/otter.nvim/commit/1159b49f22ed53352b24a34f34e721eeb50c0b0a))
* try hover without vim syntax enabled ([a3588f6](https://github.com/jmbuhr/otter.nvim/commit/a3588f64a297e871c506879a4914705b57431ee4))

## [0.8.1](https://github.com/jmbuhr/otter.nvim/compare/v0.8.0...v0.8.1) (2023-03-27)


### Bug Fixes

* make sure main module is local ([5c6ad47](https://github.com/jmbuhr/otter.nvim/commit/5c6ad47178edb6c3c1a2b111667cbc5e207f4704))

## [0.8.0](https://github.com/jmbuhr/otter.nvim/compare/v0.7.0...v0.8.0) (2023-03-11)


### Features

* pass fallback function to send_request ([2f5f760](https://github.com/jmbuhr/otter.nvim/commit/2f5f7602fc9d8c1427214a3ed4129e257a5c1e3a))


### Bug Fixes

* add cmp to test dependencies ([2789556](https://github.com/jmbuhr/otter.nvim/commit/2789556d936fbab89ff9531d5154c9384c8803f7))

## [0.7.0](https://github.com/jmbuhr/otter.nvim/compare/v0.6.0...v0.7.0) (2023-02-19)


### Features

* add custom configuration for hover windows ([77b3199](https://github.com/jmbuhr/otter.nvim/commit/77b3199a7923a0b2fbac690473563b8b541b012e))


### Bug Fixes

* add custom hover handler ([f29a9f3](https://github.com/jmbuhr/otter.nvim/commit/f29a9f303a956c266c19d36598f3f0edb6a23bbc))
* correct function signature to make tsqueries optional ([b0e8a95](https://github.com/jmbuhr/otter.nvim/commit/b0e8a95a88a101c52ae97d8e68ac4e053ca8854f))

## [0.6.0](https://github.com/jmbuhr/otter.nvim/compare/v0.5.1...v0.6.0) (2023-01-28)


### Features

* add export_otter_as function ([3f0818e](https://github.com/jmbuhr/otter.nvim/commit/3f0818ee244d9ac786e754dd3b39fff91f4eb4b9))
* allow passing ts query directly ([a67cd5b](https://github.com/jmbuhr/otter.nvim/commit/a67cd5b6d44be74493bae86baf305f92e3353173))

## [0.5.1](https://github.com/jmbuhr/otter.nvim/compare/v0.5.0...v0.5.1) (2023-01-26)


### Bug Fixes

* also use nvim-treesitter parsername for completion source ([8e257b6](https://github.com/jmbuhr/otter.nvim/commit/8e257b6081cf61191ebc10ec538ddc3713bcc43a))

## [0.5.0](https://github.com/jmbuhr/otter.nvim/compare/v0.4.0...v0.5.0) (2023-01-26)


### Features

* use parsername from nvim-treesitter.parsers ([31ab3a4](https://github.com/jmbuhr/otter.nvim/commit/31ab3a420f9dadb8bcea9088e5971934335c9cc5))

## [0.4.0](https://github.com/jmbuhr/otter.nvim/compare/v0.3.1...v0.4.0) (2023-01-20)


### Features

* add automatic release PRs ([d84c214](https://github.com/jmbuhr/otter.nvim/commit/d84c2141e60826eef49cc0fb6d59394ae6c9591c))
