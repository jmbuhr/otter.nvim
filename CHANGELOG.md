# Changelog

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
