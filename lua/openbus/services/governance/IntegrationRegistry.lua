local log = require "openbus.util.logger"
local msg = require "openbus.services.governance.messages"

local oo = require "openbus.util.oo"
local idl = require "openbus.services.governance.idl"
local IntegrationType = idl.types.Integration
local IntegrationRegistryType = idl.types.IntegrationRegistry

-- Integration
local Integration = oo.class{
  __type = IntegrationType,
}
function Integration:__init()
  assert(self.context.ContractRegistry) -- scs facet
  assert(self.id)
  self.consumer = nil
  self.provider = nil
  self.activated = false
  self._contracts = {}
end
function Integration:_set_consumer(consumer)
  local oldname = (self.consumer and self.consumer:_get_name()) or "nil"
  log:action(
    msg.UpdatedIntegratioConsumer:tag{
      oldname=oldname,
      newname=consumer:_get_name()
    })
  self.consumer = consumer
end
function Integration:_get_consumer()
  return self.consumer
end
function Integration:_set_provider(provider)
  local oldname = (self.provider and self.provider:_get_name()) or "nil"
  log:action(
    msg.UpdatedIntegrationProvider:tag{
      oldname=oldname,
      newname=provider:_get_name()
    })
  self.provider = provider
end
function Integration:_get_provider()
  return self.provider
end
function Integration:_get_contracts() 
  local result = {}
  for name in pairs(self._contracts) do
    result[#result+1] = self.context.ContractRegistry:get(name)
  end
  return result
end
function Integration:addContract(name)
  local contract = self.context.ContractRegistry:get(name)
  if not contract then
    return false
  end
  self._contracts[name] = true
  return true
end
function Integration:removeContract(name)
  self._contracts[name] = nil
  return true
end


-- Integration Registry
local IntegrationRegistry = oo.class{
  __type = IntegrationRegistryType,
  __objkey = "IntegrationRegistry",
}

function IntegrationRegistry:__init()
  self._integrations = {}
  self._seed = 0 --TODO: db autoincrement
end
function IntegrationRegistry:_get_integrations()
  local result = {}
  for id, integration in pairs(self._integrations) do
    result[#result+1] = integration
  end
  return result
end
function IntegrationRegistry:add()
  self._seed = self._seed + 1
  local integration = Integration{
    id = self._seed,
    context = self.context,
  }
  self._integrations[self._seed] = integration
  return integration
end
function IntegrationRegistry:remove(id)
  local result = self._integrations[id]
  self._integrations[id] = nil
  return result
end

return IntegrationRegistry
