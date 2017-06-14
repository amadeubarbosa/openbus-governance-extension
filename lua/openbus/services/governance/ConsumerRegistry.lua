local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"

local listener = require "openbus.services.governance.Listener"
local string = require "openbus.services.governance.string"

local msg = require "openbus.services.governance.messages"
local idl = require "openbus.services.governance.idl"
local ConsumerType = idl.types.Consumer
local ConsumerRegistryType = idl.types.ConsumerRegistry
local sysex = require "openbus.util.sysex"
local BAD_PARAM = sysex.BAD_PARAM

-- Consumer
local Consumer = oo.class{
  __type = ConsumerType,
}
function Consumer:__init()
  assert(self.registry)
  assert(self.database)
  assert(self.name)
  self.code = self.code or ""
  self.office = self.office or ""
  self.busquery = self.busquery or ""
  self.support = self.support or {}
  self.manager = self.manager or {}
end

function Consumer:_get_name()
  return self.name
end
function Consumer:_set_name(name)
  local registry = self.registry
  local db = self.database
  local oldname = self.name
  assert(db:exec("BEGIN;"))
  -- integrity of table integration
  local getIntegrationByConsumer = db.pstmts.getIntegrationByConsumer
  getIntegrationByConsumer:bind_values(oldname)
  local integrations = {}
  for entry in getIntegrationByConsumer:nrows() do
    integrations[#integrations+1] = entry.id
  end
  -- regular update on consumer table
  local ok, errmsg = db:pexec("setConsumerName", name, oldname)
  if not ok then
    assert(db:exec("ROLLBACK;"))
    log:exception(msg.FailedUpdatingConsumer:tag{attr="name", error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  --TODO: the following code should be in IntegrationRegistry.lua as a callback?
  -- update data affected by consumer name change
  for _, id in ipairs(integrations) do
    local ok, errmsg = db:pexec("setIntegrationConsumer", name, id)
    if not ok then
      assert(db:exec("ROLLBACK;"))
      log:exception(msg.FailedUpdatingConsumerOnIntegration:tag{integration=id})
      BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
    end
  end
  assert(db:exec("COMMIT;"))
  self.name = name
  registry.consumers[oldname] = nil
  registry.consumers[name] = self
  log:action(msg.UpdatedConsumerName:tag{oldname=oldname, newname=name})
end
do -- getters & setters for very simple attributes
  local camelcase = {"Code", "Office", "Support", "Manager", "BusQuery"}
  for _, item in ipairs(camelcase) do
    local attribute = string.lower(item)
    local getmethod = "_get_"..attribute
    local setmethod = "_set_"..attribute
    local dbsetstmt = "setConsumer"..item

    Consumer[getmethod] = function (self)
      return self[attribute]
    end

    Consumer[setmethod] = function (self, value)
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
        log:exception(msg.FailedUpdatingConsumer:tag{attr=attribute, error=errmsg})
        BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
      end
      local oldvalue = self[attribute]
      log:action(msg.UpdatedConsumerAttribute:tag{attr=attribute, old=oldvalue, new=value})
      self[attribute] = value
    end
  end
end

-- Consumer Registry
local ConsumerRegistry = oo.class{
  __type = ConsumerRegistryType,
  __objkey = "ConsumerRegistry",
}

function ConsumerRegistry:__init()
  local db = assert(self.database)
  self.consumers = {}
  self.callbacks = listener()
  for entry in db.pstmts.getConsumer:nrows() do
    -- data
    assert(entry.name)
    entry.support = string.split(entry.support, ",")
    entry.manager = string.split(entry.manager, ",")
    log:action(msg.LoadPersistedConsumer:tag(entry))
    -- framework dependencies
    entry.registry = self -- used in _set_name
    entry.database = db
    self.consumers[entry.name] = Consumer(entry)
  end
end
function ConsumerRegistry:_get_consumers()
  local result = {}
  for name, consumer in pairs(self.consumers) do
    result[#result+1] = consumer
  end
  return result
end
function ConsumerRegistry:get(name)
  return self.consumers[name]
end
function ConsumerRegistry:add(name)
  -- data
  local entry = {name = name}
  local db = self.database
  local ok, errmsg = db:pexec("addConsumer", entry)
  if not ok then
    log:exception(msg.FailedAddingConsumer:tag{entry=entry, error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  -- framework dependencies
  entry.registry = self
  entry.database = db
  local consumer = Consumer(entry)
  self.consumers[name] = consumer
  log:action(msg.ConsumerAdded:tag{name=consumer.name})
  return consumer
end
function ConsumerRegistry:remove(name)
  local consumers = self.consumers
  local result = consumers[name]
  if not result then
    log:exception(msg.FailedRemovingConsumer:tag{name=name})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  assert(self.database:pexec("delConsumer", name))
  consumers[name] = nil
  self.callbacks:notify("remove", result)
  log:action(msg.ConsumerRemoved:tag{name=result.name})
  return result
end

return ConsumerRegistry
