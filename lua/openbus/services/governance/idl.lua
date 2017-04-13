local _G = require "_G"
local ipairs = _G.ipairs

local array = require "table"
local unpack = array.unpack

local makeaux = require "openbus.core.idl.makeaux"
local parsed = require "openbus.services.governance.parsed"

local types, const, throw = {}, {}, {}
for _, parsed in ipairs(parsed) do
  if parsed.name == "tecgraf" then
    makeaux(parsed, types, const, throw)
  end
end

local idl = {
  types = types.tecgraf.openbus.services.governance.v1_0,
  throw = throw.tecgraf.openbus.services.governance.v1_0,
  const = const.tecgraf.openbus.services.governance.v1_0,
}

function idl.loadto(orb)
  orb.TypeRepository.registry:register(unpack(parsed))
end

return idl
