local oo = require "openbus.util.oo"
local idl = require "openbus.services.governance.idl"
local ContractType = idl.types.Contract
local ContractRegistryType = idl.types.ContractRegistry

-- Contract
local Contract = oo.class{
  __type = ContractType,
}
function Contract:__init() 
  assert(self.name)
  self._interfaces = {}
end
function Contract:_get_interfaces() 
  local result = {}
  for repid in pairs(self._interfaces) do
    result[#result+1] = repid
  end
  return result
end
function Contract:addInterface(repid)
  self._interfaces[repid] = true
end
function Contract:removeInterface(repid)
  self._interfaces[repid] = nil
end

-- Contract Registry
local ContractRegistry = oo.class{
  __type = ContractRegistryType,
  __objkey = "ContractRegistry",
}
function ContractRegistry:__init()
  self._contracts = {}
end
function ContractRegistry:_get_contracts()
  local result = {}
  for name, contract in pairs(self._contracts) do
    result[#result+1] = contract
  end
  return result
end
function ContractRegistry:get(name)
  return self._contracts[name]
end
function ContractRegistry:add(name)
  local contract = Contract{name = name}
  self._contracts[name] = contract
  return contract
end
function ContractRegistry:remove(name)
  local result = self._contracts[name]
  self._contracts[name] = nil
  return result
end

return ContractRegistry