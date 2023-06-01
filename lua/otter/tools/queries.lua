return {
  markdown = [[
  (fenced_code_block
  (info_string
    (language) @_lang
  )
  (code_fence_content) @content (#offset! @content)
  )]],
  quarto = [[
  (fenced_code_block
  (info_string
    (language) @_lang
  ) @info
    (#match? @info "{")
  (code_fence_content) @content (#offset! @content)
  )]]
}
