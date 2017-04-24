local log = require "openbus.util.logger"
local msg = require "openbus.services.governance.messages"

local oo = require "openbus.util.oo"
local idl = require "openbus.services.governance.idl"
local ConsumerType = idl.types.Consumer
local ConsumerRegistryType = idl.types.ConsumerRegistry

-- Consumer
local Consumer = oo.class{
  __type = ConsumerType,
}
function Consumer:__init()
  assert(self.context.ConsumerRegistry)
  assert(self.name)
  self.code = ""
  self.office = ""
  self.support = ""
  self.manager = ""
  self.busquery = ""
  self._contracts = {}
end
function Consumer:_set_name(name)
  log:action(msg.UpdatedConsumerName:tag{oldname=self.name, newname=name})
  self.context.ConsumerRegistry._consumers[self.name] = nil
  self.context.ConsumerRegistry._consumers[name] = self
  self.name = name
end
function Consumer:_get_name()
  return self.name
end
function Consumer:_set_code(code)
  log:action(msg.UpdatedConsumerCode:tag{oldcode=self.code, newcode=code})
  self.code = code
end

-- Consumer Registry
local ConsumerRegistry = oo.class{
  __type = ConsumerRegistryType,
  __objkey = "ConsumerRegistry",
}

function ConsumerRegistry:__init()
  self._consumers = {}
end
function ConsumerRegistry:_get_consumers()
  local result = {}
  for name, consumer in pairs(self._consumers) do
    result[#result+1] = consumer
  end
  return result
end
function ConsumerRegistry:get(name)
  return self._consumers[name]
end
function ConsumerRegistry:add(name)
  local consumer = Consumer{context = self.context, name = name}
  self._consumers[name] = consumer
  return consumer
end
function ConsumerRegistry:remove(name)
  local result = self._consumers[name]
  self._consumers[name] = nil
  return result
end

return ConsumerRegistry