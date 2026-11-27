-- Author: David M. Anderson
-- Built with AI assistance (Claude, Anthropic)

local pages = {
  ["FRAMEWORK.md"] = "/profiles/framework/",
  ["CONVENTIONS.md"] = "/profiles/conventions/",
  ["DESIGN.md"] = "/profiles/design/",
  ["records/SPEC.md"] = "/profiles/records/",
  ["records/DESIGN.md"] = "/profiles/records/design/",
}

local function resolve(dir, target)
  local parts = {}
  for segment in (dir .. target):gmatch("[^/]+") do
    if segment == ".." then
      table.remove(parts)
    elseif segment ~= "." then
      table.insert(parts, segment)
    end
  end
  return table.concat(parts, "/")
end

function Pandoc(doc)
  local docfile = pandoc.utils.stringify(doc.meta["profile-doc"])
  local commit = pandoc.utils.stringify(doc.meta["profile-commit"])
  local dir = docfile:match("^(.*/)") or ""
  return doc:walk({
    Link = function(link)
      local target = link.target
      if target:match("^%a[%w+.-]*:") or target:match("^#") or target:match("^/") then
        return link
      end
      local path, fragment = target:match("^([^#]*)(#?.*)$")
      local resolved = resolve(dir, path)
      local page = pages[resolved]
      if page then
        link.target = page .. fragment
      else
        link.target = "https://github.com/excelano/slipcase-profiles/blob/" .. commit .. "/" .. resolved .. fragment
      end
      return link
    end,
  })
end
