local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"

local msg = require "openbus.services.governance.messages"
local idl = require "openbus.services.governance.idl"
local IntegrationType = idl.types.Integration
local IntegrationRegistryType = idl.types.IntegrationRegistry
local sysex = require "openbus.util.sysex"
local BAD_PARAM = sysex.BAD_PARAM

-- Integration
local Integration = oo.class{
  __type = IntegrationType,
}
function Integration:__init()
  assert(self.ContractRegistry)
  assert(self.database)
  assert(self.id)
  self.consumer = self.consumer -- nil is accepted
  self.provider = self.provider -- nil is accepted
  self.activated = (self.activated == 1)
  self.contracts = self.contracts or {}
end
function Integration:_set_activated(activated)
  local db = self.database
  local dbvalue = (activated and 1) or 0
  local ok, errmsg = db:pexec("setIntegrationActivated", dbvalue, self.id)
  if not ok then
    log:exception(msg.FailedUpdatingIntegration:tag{
      activated=dbvalue, id=self.id, error=errmsg
      })
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  log:action(msg.UpdatedIntegrationActivation:tag{
    activated=activated, id=self.id})
  self.activated = activated
end
function Integration:_get_activated()
  return self.activated
end
function Integration:_set_consumer(consumer)
  local oldname = (self.consumer and self.consumer:_get_name()) or "nil"
  local newname = consumer:_get_name()
  local db = self.database
  local ok, errmsg = db:pexec("setIntegrationConsumer", newname, self.id)
  if not ok then
    log:exception(msg.FailedUpdatingIntegration:tag{
      consumer=newname, id=self.id, error=errmsg
    })
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  log:action(
    msg.UpdatedIntegrationConsumer:tag{
      oldname=oldname, newname=newname
    })
  self.consumer = consumer
end
function Integration:_get_consumer()
  return self.consumer
end
function Integration:_set_provider(provider)
  local oldname = (self.provider and self.provider:_get_name()) or "nil"
  local newname = provider:_get_name()
  local db = self.database
  local ok, errmsg = db:pexec("setIntegrationProvider", newname, self.id)
  if not ok then
    log:exception(msg.FailedUpdatingIntegration:tag{
      provider=newname, id=self.id, error=errmsg
    })
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  log:action(
    msg.UpdatedIntegrationProvider:tag{
      oldname=oldname, newname=newname
    })
  self.provider = provider
end
function Integration:_get_provider()
  return self.provider
end
function Integration:_get_contracts() 
  local result = {}
  for name in pairs(self.contracts) do
    result[#result+1] = self.ContractRegistry:get(name)
  end
  return result
end
function Integration:addContract(name)
  if not self.ContractRegistry:get(name) then
    log:exception(msg.RefusingAddingContractThatDoesntExist:tag{integration=self.id, contract=name})
    return false -- contract doesn't exist in registry
  end
  if self.provider ~= nil then
    local supported = false
    for _, c in ipairs(self.provider:_get_contracts()) do
      if c:_get_name() == name then
        supported = true
        break
      end
    end
    if not supported then
      log:exception(msg.RefusingAddingContractWhichProviderDoesntSupport:tag{
        integration=self.id, contract=name, provider=self.provider:_get_name()})
      return false -- provider doesn't support this contract
    end
  end
  local db = self.database
  local entry = {contract = name, integration = self.id}
  local ok, errmsg = db:pexec("addIntegrationContract", entry)
  if not ok then
    log:exception(msg.FailedAddingContractToIntegration:tag{
      entry=entry, error=errmsg
      })
    BAD_PARAM{ completed = "COMPLETED_NO" , minor = 0 }
  end
  log:action(msg.ContractAddedToIntegration:tag(entry))
  self.contracts[name] = true
  return true
end
function Integration:removeContract(name)
  local contracts = self.contracts
  if not contracts[name] then
    log:exception(
      msg.RefusingRemovingContractNotAssociatedBefore:tag{
        integration=self.id, contract=name
      })
    return false
  end
  local db = self.database
  local entry = {contract = name, integration = self.id}
  local ok, errmsg = db:pexec("delIntegrationContract", entry)
  if not ok then
    log:exception(msg.FailedRemovingContractFromIntegration:tag{
      entry=entry, error=errmsg
      })
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  log:action(msg.ContractRemovedFromIntegration:tag(entry))
  self.contracts[name] = nil
  return true
end

-- Integration Registry
local IntegrationRegistry = oo.class{
  __type = IntegrationRegistryType,
  __objkey = "IntegrationRegistry",
}

function IntegrationRegistry:__init()
  local db = assert(self.database)
  local ContractRegistry = assert(self.context.ContractRegistry)
  local ConsumerRegistry = assert(self.context.ConsumerRegistry)
  local ProviderRegistry = assert(self.context.ProviderRegistry)

  self.integrations = {}
  -- listening for database updated to reflect memory structures
  ContractRegistry.callbacks:insert(function(event, ...)
    if event == "remove" then
      local contract = assert(select(1, ...))
      for id, integration in pairs(self.integrations) do
        for name in pairs(integration.contracts) do
          if name == contract.name then
            integration.contracts[name] = nil
            log:action(msg.UpdatedIntegrationAfterContractRemoval:tag{
              integration=id, contract=name
              })
            break
          end
        end
      end
    end
    end)
  ConsumerRegistry.callbacks:insert(function(event, ...)
    if event == "remove" then
      local consumer = assert(select(1, ...))
      local name = consumer.name
      for id, integration in pairs(self.integrations) do
        if integration.consumer and (name == integration.consumer:_get_name()) then
          integration.consumer = nil
          -- the following code is necessary by the lack
          -- of foreign keys on integration.consumer
          local db = self.database
          local ok, errmsg = db:pexec("setIntegrationConsumer", nil, id)
          if not ok then
            -- should abort?
            log:exception(
              msg.FailedUpdatingIntegrationAfterConsumerRemoval:tag{
                integration=id, consumer=name, error=errmsg
              })
          else
            log:action(msg.UpdatedIntegrationAfterConsumerRemoval:tag{
              integration=id, consumer=name
              })
          end
          break
        end
      end
    end
    end)
  ProviderRegistry.callbacks:insert(function(event, ...)
    if event == "remove" then
      local provider = select(1, ...)
      for id, integration in pairs(self.integrations) do
        if integration.provider and (provider.name == integration.provider:_get_name()) then
          integration.provider = nil
          -- the following code is necessary by the lack
          -- of foreign keys on integration.provider
          local db = self.database
          local ok, errmsg = db:pexec("setIntegrationProvider", nil, id)
          if not ok then
            -- should abort?
            log:exception(
              msg.FailedUpdatingIntegrationAfterProviderRemoval:tag{
                integration=id, provider=provider.name, error=errmsg
              })
          else
            log:action(msg.UpdatedIntegrationAfterProviderRemoval:tag{
              integration=id, provider=provider.name
              })
          end
          break
        end
      end
    end
    end)
  for entry in db.pstmts.getIntegration:nrows() do
    -- data
    assert(entry.id)
    entry.contracts = {}
    local getIntegrationContract = db.pstmts.getIntegrationContract
    getIntegrationContract:bind_values(entry.id)
    for row in getIntegrationContract:nrows() do
      entry.contracts[row.contract] = true
    end
    -- get related corba references
    log:action(msg.LoadPersistedIntegration:tag(entry))
    if entry.consumer then
      entry.consumer = ConsumerRegistry:get(entry.consumer)
    end
    if entry.provider then
      entry.provider = ProviderRegistry:get(entry.provider)
    end
    -- framework dependencies
    entry.ContractRegistry = ContractRegistry
    entry.database = db
    self.integrations[entry.id] = Integration(entry)
  end
end
function IntegrationRegistry:_get_integrations()
  local result = {}
  for id, integration in pairs(self.integrations) do
    result[#result+1] = integration
  end
  return result
end
function IntegrationRegistry:add()
  local db = self.database
  local ok, errmsg = db:pexec("addIntegration", {})
  if not ok then
    log:exception(msg.FailedAddingIntegration:tag{error=errmsg})
    NO_RESOURCES{ completed = "COMPLETED_NO", minor = 0 }
  end
  -- data
  local entry = {id = assert(db.conn:last_insert_rowid())}
  -- framework dependencies
  entry.ContractRegistry = self.context.ContractRegistry
  entry.database = db
  local integration = Integration(entry)
  self.integrations[entry.id] = integration
  log:action(msg.IntegrationAdded:tag{id=entry.id})
  return integration
end
function IntegrationRegistry:remove(id)
  local integrations = self.integrations
  local result = integrations[id]
  if not result then
    log:exception(msg.FailedRemovingIntegration:tag{id=id})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  assert(self.database:pexec("delIntegration", id))
  integrations[id] = nil
  log:action(msg.IntegrationRemoved:tag{id=id})
  return result
end

return IntegrationRegistry
