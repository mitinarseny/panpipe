local cacheEnabled = true
local cacheDir = '.panpipe'

local metaCacheEnabled = 'panpipeCacheEnabled'
local metaCacheDir = 'panpipeCacheDir'

local pipeAttr = 'pipe'
local depsAttr = 'deps'

local classHidden = 'hidden'
local classNoCache = 'noCache'

-- initCache inits the cache
local function initCache()
  if cacheEnabled and not io.open(cacheDir, 'r') then
    os.execute('mkdir -p ' .. cacheDir)
  end
end

function Meta(meta)
  if type(meta[metaCacheEnabled]) == 'boolean'  then
    cacheEnabled = meta[metaCacheEnabled]
  end
  if type(meta[metaCacheDir]) == 'string' then
    cacheDir = meta[cacheDir]
  end
  initCache()
end

local blockHashes = {}

-- concatDepsHashes returs concatenated hash of all dependencies
local function concatDepsHashes(ids)
  local s = ''
  for id in ids do
    local idHash = blockHashes[id]
    if idHash then
      s = s .. idHash
    end
  end
  return s
end

-- split splits the string with given separator and returs an iterator
function string:split(sep)
  return self:gmatch('([^' .. (sep or '%s') .. ']+)')
end

-- blockHash returs hash of block taking pipe, deps and content into account
local function blockHash(pipe, deps, content)
  return pandoc.utils.sha1(pipe
    .. (deps and concatDepsHashes(deps:split(',')) or '')
    .. content)
end

local function cachePath(filename)
  return cacheDir .. '/' .. filename
end

-- loadCache returns content of cached output with given hash
-- returns nil if there is no cached output
local function loadCache(hash)
  local fname = cachePath(hash)
  local f = io.open(fname, 'r')
  return f and f:read('*a')
end

-- storeCache stores content with hash key and returns file handler opened in write mode
local function storeCache(hash, content)
  local fname = cachePath(hash)
  local f = assert(
    io.open(fname, 'w'),
    'unable to open file `' .. fname .. '` to write cache'
  )
  return f:write(content)
end

function CodeBlock(block)
  local pipe = block.attributes[pipeAttr]
  if not pipe then
    return
  end
  block.attributes[pipeAttr] = nil

  local deps = block.attributes[depsAttr]
  block.attributes[depsAttr] = nil

  local noCache, hidden
  block.classes = block.classes:filter(function (cls)
    if cls == classNoCache then
      noCache = true
      return
    elseif cls == classHidden then
      hidden = true
      return
    end
    return true
  end)

  block.text = (function (piper)
    if not cacheEnabled then
      return piper(pipe, block.text)
    end
    local hash = blockHash(pipe, deps, block.text)
    if block.identifier ~= '' then
      blockHashes[block.identifier] = hash
    end
    if noCache then
      return piper(pipe, block.text)
    end

    local cached = loadCache(hash)
    if cached then
      return cached
    end
    local output = piper(pipe, block.text)
    local ok, err = pcall(storeCache, hash, output)
    if not ok then
      error('unable to store cache: ' .. err)
    end
    return output
  end)(function (pipe, input)
    return pandoc.pipe('sh', {'-c', pipe}, input)
  end)

  if hidden then
    return {}
  end

  return block
end

return {
  {Meta      = Meta},
  {CodeBlock = function (block)
    local ok, res = pcall(CodeBlock, block)
    if not ok then
      error('error while processing code block'
        .. ((block.identifier ~= '' and (' #' .. block.identifier)) or '') .. ': ' .. tostring(res))
    end
    return res
  end},
}
