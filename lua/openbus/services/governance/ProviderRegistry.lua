local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"

local listener = require "openbus.services.governance.Listener"
local string = require "openbus.services.governance.string"

local msg = require "openbus.services.governance.messages"
local idl = require "openbus.services.governance.idl"
local ProviderType = idl.types.Provider
local ProviderRegistryType = idl.types.ProviderRegistry
local sysex = require "openbus.util.sysex"
local BAD_PARAM = sysex.BAD_PARAM

-- Provider
local Provider = oo.class{
  __type = ProviderType,
}
function Provider:__init()
  assert(self.ProviderRegistry)
  assert(self.ContractRegistry)
  assert(self.database)
  assert(self.name)
  self.code = self.code or ""
  self.office = self.office or ""
  self.busquery = self.busquery or ""
  self.support = self.support or {}
  self.manager = self.manager or {}
  self.contracts = self.contracts or {}
end

function Provider:_get_name()
  return self.name
end
function Provider:_set_name(name)
  local ProviderRegistry = self.ProviderRegistry
  local db = self.database
  local oldname = self.name
  assert(db:exec("BEGIN;"))
  -- integrity of table integration
  local getIntegrationByProvider = db.pstmts.getIntegrationByProvider
  getIntegrationByProvider:bind_values(oldname)
  local integrations = {}
  for entry in getIntegrationByProvider:nrows() do
    integrations[#integrations+1] = entry.id
  end
  -- avoiding foreign key constraint failure
  for contract in pairs(self.contracts) do
    local ok, errmsg = db:pexec("delProviderContract", contract, oldname)
    if not ok then
      assert(db:exec("ROLLBACK;"))
      log:exception(msg.FailedPreparingToUpdateProvider:tag{
        contract=contract, provider=oldname})
      BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
    end
  end
  -- regular update on provider table
  local ok, errmsg = db:pexec("setProviderName", name, oldname)
  if not ok then
    assert(db:exec("ROLLBACK;"))
    log:exception(msg.FailedUpdatingProvider:tag{attr="name", error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  -- update data affected by provider name change
  for _, id in ipairs(integrations) do
    local ok, errmsg = db:pexec("setIntegrationProvider", name, id)
    if not ok then
      assert(db:exec("ROLLBACK;"))
      log:exception(msg.FailedUpdatingProviderRelationships:tag{
        integration=id, provider=name, error=errmsg})
      BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
    end
  end
  for contract in pairs(self.contracts) do
    local ok, errmsg = db:pexec("addProviderContract", contract, name)
    if not ok then
      assert(db:exec("ROLLBACK;"))
      log:exception(msg.FailedUpdatingProviderRelationships:tag{
        contract=contract, provider=name, error=errmsg})
      BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
    end
  end
  assert(db:exec("COMMIT;"))
  self.name = name
  ProviderRegistry.providers[oldname] = nil
  ProviderRegistry.providers[name] = self
  log:action(msg.UpdatedProviderName:tag{oldname=oldname, newname=name})
end
do -- getters & setters for very simple attributes
  local camelcase = {"Code", "Office", "Support", "Manager", "BusQuery"}
  for _, item in ipairs(camelcase) do
    local attribute = string.lower(item)
    local getmethod = "_get_"..attribute
    local setmethod = "_set_"..attribute
    local dbsetstmt = "setProvider"..item

    Provider[getmethod] = function (self)
      return self[attribute]
    end

    Provider[setmethod] = function (self, value)
      local db = self.database
      if type(value) == "table" then -- hacking string sequences
        dbvalue = table.concat(value, ",")
      elseif type(value) == "boolean" then
        dbvalue = (value and 1) or 0
      else
        dbvalue = value -- number or string is accepted
      end
      local ok, errmsg = db:pexec(dbsetstmt, dbvalue, self.name)
      if not ok then
        log:exception(msg.FailedUpdatingProvider:tag{attr=attribute, error=errmsg})
        BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
      end
      local oldvalue = self[attribute]
      log:action(msg.UpdatedProviderAttribute:tag{attr=attribute, old=oldvalue, new=value})
      self[attribute] = value
    end
  end
end

function Provider:_get_contracts() 
  local result = {}
  for name in pairs(self.contracts) do
    result[#result+1] = self.ContractRegistry:get(name)
  end
  return result
end
function Provider:addContract(name)
  if not self.ContractRegistry:get(name) then
    log:exception(msg.RefusingAddingContractThatDoesntExist:tag{provider=self.name, contract=name})
    return false -- contract doesn't exist in registry
  end
  local db = self.database
  local entry = {contract = name, provider = self.name}
  local ok, errmsg = db:pexec("addProviderContract", entry)
  if not ok then
    log:exception(msg.FailedAddingContractToProvider:tag{
      entry=entry, error=errmsg
      })
    BAD_PARAM{ completed = "COMPLETED_NO" , minor = 0 }
  end
  log:action(msg.ContractAddedToProvider:tag(entry))
  self.contracts[name] = true
  return true
end
function Provider:removeContract(name)
  local contracts = self.contracts
  if not contracts[name] then
    log:exception(
      msg.RefusingRemovingContractNotAssociatedBefore:tag{
        provider=self.name, contract=name
      })
    return false
  end
  local db = self.database
  local entry = {contract = name, provider = self.name}
  local ok, errmsg = db:pexec("delProviderContract", entry)
  if not ok then
    log:exception(msg.FailedRemovingContractFromProvider:tag{
      entry=entry, error=errmsg
      })
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  log:action(msg.ContractRemovedFromProvider:tag(entry))
  self.contracts[name] = nil
  return true
end

-- Provider Registry
local ProviderRegistry = oo.class{
  __type = ProviderRegistryType,
  __objkey = "ProviderRegistry",
}

function ProviderRegistry:__init()
  local db = assert(self.database)
  local ContractRegistry = assert(self.context.ContractRegistry)
  self.providers = {}
  self.callbacks = listener()
  for entry in db.pstmts.getProvider:nrows() do
    -- data
    assert(entry.name)
    entry.support = string.split(entry.support, ",")
    entry.manager = string.split(entry.manager, ",")
    entry.contracts = {}
    local getProviderContract = db.pstmts.getProviderContract
    getProviderContract:bind_values(entry.name)
    for row in getProviderContract:nrows() do
      entry.contracts[row.contract] = true
    end
    log:action(msg.LoadPersistedProvider:tag(entry))
    -- framework dependencies
    entry.ContractRegistry = ContractRegistry
    entry.ProviderRegistry = self -- used in _set_name
    entry.database = db
    self.providers[entry.name] = Provider(entry)
  end
end
function ProviderRegistry:_get_providers()
  local result = {}
  for name, provider in pairs(self.providers) do
    result[#result+1] = provider
  end
  return result
end
function ProviderRegistry:get(name)
  return self.providers[name]
end
function ProviderRegistry:add(name)
  -- data
  local entry = {name = name}
  local db = self.database
  local ok, errmsg = db:pexec("addProvider", entry)
  if not ok then
    log:exception(msg.FailedAddingProvider:tag{entry=entry, error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  -- framework dependencies
  entry.ContractRegistry = self.context.ContractRegistry
  entry.ProviderRegistry = self -- used in _set_name
  entry.database = db
  local provider = Provider(entry)
  self.providers[entry.name] = provider
  log:action(msg.ProviderAdded:tag{name=provider.name})
  return provider
end
function ProviderRegistry:remove(name)
  local providers = self.providers
  local result = providers[name]
  if not result then
    log:exception(msg.FailedRemovingProvider:tag{name=name})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  assert(self.database:pexec("delProvider", name))
  providers[name] = nil
  self.callbacks:notify("remove", result)
  log:action(msg.ProviderRemoved:tag{name=result.name})
  return result
end

return ProviderRegistry
