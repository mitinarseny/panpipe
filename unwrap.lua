local unwrapAttr = 'unwrap'

function CodeBlock(block)
  local unwrap = block.attributes[unwrapAttr]
  if not unwrap then
    return
  end
  block.attributes[unwrapAttr] = nil
  local ok, res = pcall(pandoc.read, block.text, unwrap)
  if not ok then
    error('can not read with format ' .. unwrap .. ': ' .. res)
  end
  return pandoc.Div(res.blocks, pandoc.Attr(
    block.identifier,
    block.classes,
    block.attributes
  ))
end

return {
  {CodeBlock = function (block)
    local ok, res = pcall(CodeBlock, block)
    if not ok then
      error('unable to process code block'
        .. ((block.identifier ~= '' and (' #' .. block.identifier)) or '') .. ': ' .. tostring(res))
    end
  end},
}
