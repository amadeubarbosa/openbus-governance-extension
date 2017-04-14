local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"
local cached = require "loop.cached"

local OpenBusFixture = require "openbus.test.fixture"

ContractFixture = cached.class({}, OpenBusFixture)

function ContractFixture:setup(...)
  OpenBusFixture.setup(self,...)
  self.ContractRegistry = assert(self.governance:getFacetByName("ContractRegistry"):__narrow())
end

function ContractFixture:teardown(...)
  self.ContractRegistry = nil
  OpenBusFixture.teardown(self,...)
end

return 
  ContractFixture{
    Suite{
      AddContract = function(fixture)
        local AllContract = {
          ["Navigation"] = {
            "IDL:example/data_service/IHierarchicalNavigation:1.0",
            "IDL:example/data_service/IHierarchicalManagement:1.0",
            "IDL:example/data_service/IHierarchicalTransfer:1.0",
            "IDL:example/data_service/IDataService:1.0",
          },
          ["Batch Execution"] = {
            "IDL/example/opendreams/IAlgorithmExecution:1.0",
            "IDL/example/opendreams/ISimulationMonitoring:1.0",
          },
        }
        local before = fixture.ContractRegistry:_get_contracts()
        checks.assert(before, checks.like{})

        for name, interfaces in pairs(AllContract) do
          local contract = fixture.ContractRegistry:add(name)
          before[#before+1] = contract
          -- empty interfaces
          checks.assert(contract:_get_interfaces(), checks.like{})
          for _, iface in ipairs(interfaces) do
            contract:addInterface(iface)
          end
          -- all interfaces were added
          --TODO: checks.assert(contract:_get_interfaces(), checks.like(interfaces))
          for _, iface in ipairs(interfaces) do
            contract:removeInterface(iface)
          end
          -- all interfaces were removed
          checks.assert(contract:_get_interfaces(), checks.like{})
        end

        local after = fixture.ContractRegistry:_get_contracts()
        --TODO: checks.assert(after, checks.like(before))

        for name in pairs(AllContract) do
          assert(fixture.ContractRegistry:remove(name))
        end
        checks.assert(fixture.ContractRegistry:_get_contracts(), checks.like{})
      end,
  }
}
