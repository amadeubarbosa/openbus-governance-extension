local oo = require "openbus.util.oo"

local Listener = oo.class{
  insert = table.insert,
  remove = table.remove,
}
function Listener:notify(event, ...)
  for _, func in ipairs(self) do
    func(event, ...)
  end
end

return Listener