local log = require "openbus.util.logger"
local msg = require "openbus.services.governance.messages"

local oo = require "openbus.util.oo"
local idl = require "openbus.services.governance.idl"
local ProviderType = idl.types.Provider
local ProviderRegistryType = idl.types.ProviderRegistry

-- Provider
local Provider = oo.class{
  __type = ProviderType,
}
function Provider:__init()
  assert(self.context.ProviderRegistry) -- scs facet
  assert(self.context.ContractRegistry) -- scs facet
  assert(self.name)
  self.code = ""
  self.office = ""
  self.support = ""
  self.manager = ""
  self.busquery = ""
  self._contracts = {}
end
function Provider:_set_name(name)
  log:action(msg.UpdatedProviderName:tag{oldname=self.name, newname=name})
  self.name = name
end
function Provider:_set_code(code)
  log:action(msg.UpdatedProviderCode:tag{oldcode=self.code, newcode=code})
  self.code = code
end
function Provider:_get_contracts() 
  local result = {}
  for name in pairs(self._contracts) do
    result[#result+1] = self.context.ContractRegistry:get(name)
  end
  return result
end
function Provider:addContract(name)
  local contract = self.context.ContractRegistry:get(name)
  if not contract then
    return false
  end
  self._contracts[name] = true
  return true
end
function Provider:removeContract(name)
  self._contracts[name] = nil
  return true
end

-- Provider Registry
local ProviderRegistry = oo.class{
  __type = ProviderRegistryType,
  __objkey = "ProviderRegistry",
}

function ProviderRegistry:__init()
  self._providers = {}
end
function ProviderRegistry:_get_providers()
  local result = {}
  for name, provider in pairs(self._providers) do
    result[#result+1] = provider
  end
  return result
end
function ProviderRegistry:get(name)
  return self._providers[name]
end
function ProviderRegistry:add(name)
  local provider = Provider{
                      context = self.context,
                      name = name
                   }
  self._providers[name] = provider
  return provider
end
function ProviderRegistry:remove(name)
  local result = self._providers[name]
  self._providers[name] = nil
  return result
end

return ProviderRegistry