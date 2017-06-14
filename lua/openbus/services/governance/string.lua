local string = _G.string

function string.split(s, sep)
  local sep = sep or "%s"
  local result = {}
  for match in string.gmatch(s or "", "([^"..sep.."]+)") do
    table.insert(result, match)
  end
  return result;
end

return string