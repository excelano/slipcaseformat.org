-- Author: David M. Anderson
-- Built with AI assistance (Claude, Anthropic)

function Link(link)
  local host = link.target:match("^https?://([^/:?#]+)")
  if host and host:lower():gsub("^www%.", "") ~= "slipcaseformat.org" then
    link.attributes.target = "_blank"
  end
  return link
end
