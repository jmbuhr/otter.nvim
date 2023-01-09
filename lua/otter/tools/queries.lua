return {
  markdown = [[
  (fenced_code_block
  (info_string
    (language) @lang
  )
  (code_fence_content) @code (#offset! @code)
  )]],
  quarto = [[
  (fenced_code_block
  (info_string
    (language) @lang
  ) @info
    (#match? @info "{")
  (code_fence_content) @code (#offset! @code)
  )]]
}
