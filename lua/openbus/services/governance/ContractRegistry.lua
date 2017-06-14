local oo = require "openbus.util.oo"
local log = require "openbus.util.logger"

local listener = require "openbus.services.governance.Listener"

local msg = require "openbus.services.governance.messages"
local idl = require "openbus.services.governance.idl"
local ContractType = idl.types.Contract
local ContractRegistryType = idl.types.ContractRegistry
local sysex = require "openbus.util.sysex"
local BAD_PARAM = sysex.BAD_PARAM

-- Contract
local Contract = oo.class{
  __type = ContractType,
}
function Contract:__init()
  assert(self.database)
  assert(self.name)
  self.interfaces = self.interfaces or {}
end
function Contract:_get_name()
  return self.name
end
function Contract:_get_interfaces()
  local result = {}
  for repid in pairs(self.interfaces) do
    result[#result+1] = repid
  end
  return result
end
function Contract:addInterface(repid)
  local db = self.database
  local entry = {contract = self.name, interface = repid}
  local ok, errmsg = db:pexec("addInterfaceContract", entry)
  if not ok then
    log:exception(msg.FailedAddingInterface:tag{entry=entry, error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  self.interfaces[repid] = true
  log:action(msg.InterfaceAddedToContract:tag(entry))
end
function Contract:removeInterface(repid)
  local db = self.database
  local entry = {contract = self.name, interface = repid}
  local ok, errmsg = db:pexec("delInterfaceContract", entry)
  if not ok then
    log:exception(msg.FailedRemovingInterface:tag{entry=entry, error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  self.interfaces[repid] = nil
  log:action(msg.InterfaceRemovedFromContract:tag(entry))
end

-- Contract Registry
local ContractRegistry = oo.class{
  __type = ContractRegistryType,
  __objkey = "ContractRegistry",
}
function ContractRegistry:__init()
  local db = assert(self.database)
  self.callbacks = listener()
  self.contracts = {}
  for entry in db.pstmts.getContract:nrows() do
    -- data
    assert(entry.name)
    entry.interfaces = {}
    local getInterfaceContract = db.pstmts.getInterfaceContract
    getInterfaceContract:bind_values(entry.name)
    for row in getInterfaceContract:nrows() do
      entry.interfaces[ row.interface ] = true
    end
    log:action(msg.LoadPersistedContract:tag(entry))
    -- framework dependencies
    entry.database = db
    self.contracts[entry.name] = Contract(entry)
  end
end

function ContractRegistry:_get_contracts()
  local result = {}
  for name, contract in pairs(self.contracts) do
    result[#result+1] = contract
  end
  return result
end
function ContractRegistry:get(name)
  return self.contracts[name]
end
function ContractRegistry:add(name)
  -- data
  local entry = {name = name}
  local db = self.database
  local ok, errmsg = db:pexec("addContract", entry)
  if not ok then
    log:exception(msg.FailedAddingContract:tag{name=entry.name, error=errmsg})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  -- framework dependencies
  entry.database = db
  local contract = Contract(entry)
  self.contracts[name] = contract
  log:action(msg.ContractAdded:tag{name=name})
  return contract
end
function ContractRegistry:remove(name)
  local contracts = self.contracts
  local result = contracts[name]
  if not result then
    log:exception(msg.FailedRemovingContract:tag{name=name})
    BAD_PARAM{ completed = "COMPLETED_NO", minor = 0 }
  end
  assert(self.database:pexec("delContract", name))
  contracts[name] = nil
  self.callbacks:notify("remove", result)
  log:action(msg.ContractRemoved:tag{name=result.name})
  return result
end

return ContractRegistry
