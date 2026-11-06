---@diagnostic disable: undefined-global
-- Pandoc Lua filter: replace mermaid code blocks with images rendered by `mmdc`.
-- Images go into pandoc's mediabag, so they end up embedded in the output
-- (inline in HTML with --embed-resources, inside the .docx/.pdf otherwise).
--
-- HTML gets SVG (crisp at any zoom); everything else gets a 3x PNG sized back down
-- to its natural width. Markdown output keeps the ```mermaid block as-is, since
-- GitHub / GitLab / Azure DevOps render it natively.
--
-- Renders are cached by content hash in $XDG_CACHE_HOME/org-mermaid.

local SCALE = 3

local cache = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/org-mermaid"
local is_html = FORMAT:match("html") ~= nil
local is_markdown = FORMAT:match("markdown") ~= nil or FORMAT == "gfm" or FORMAT == "commonmark"
local ext = is_html and "svg" or "png"
local mime = is_html and "image/svg+xml" or "image/png"

local function read(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local data = f:read("a")
  f:close()
  return data
end

local function write(path, data)
  local f = assert(io.open(path, "wb"))
  f:write(data)
  f:close()
end

local function render(code, out)
  pandoc.system.make_directory(cache, true)
  pandoc.system.with_temporary_directory("mermaid", function(dir)
    local src = dir .. "/diagram.mmd"
    write(src, code)
    local args = { "-i", src, "-o", out, "-b", "white", "-t", "default", "--quiet" }
    if ext == "png" then
      table.insert(args, "-s")
      table.insert(args, tostring(SCALE))
    end
    pandoc.pipe("mmdc", args, "")
  end)
end

function CodeBlock(el)
  if not el.classes:includes("mermaid") then
    return nil
  end
  if is_markdown then
    -- pandoc's markdown writers drop languages unknown to its highlighter, emit the fence ourselves
    return pandoc.RawBlock("markdown", "```mermaid\n" .. el.text:gsub("\n$", "") .. "\n```")
  end

  local name = pandoc.utils.sha1(el.text) .. "." .. ext
  local path = cache .. "/" .. name
  local data = read(path)
  if not data then
    local ok, err = pcall(render, el.text, path)
    data = ok and read(path)
    if not data then
      io.stderr:write("mermaid: failed to render diagram, keeping source block\n" .. tostring(err) .. "\n")
      return nil
    end
  end
  pandoc.mediabag.insert(name, mime, data)

  local attrs = {}
  if ext == "png" then
    -- PNG IHDR: width is the big-endian uint32 at byte 17. Without this, docx/pdf
    -- would size the 3x render at 3x its intended size.
    local width = string.unpack(">I4", data, 17)
    attrs.width = math.floor(width / SCALE) .. "px"
  end
  return pandoc.Para({ pandoc.Image({}, name, "", pandoc.Attr(el.identifier, {}, attrs)) })
end
