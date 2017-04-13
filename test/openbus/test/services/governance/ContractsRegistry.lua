local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"
local cached = require "loop.cached"

local OpenBusFixture = require "openbus.test.fixture"

ContractsFixture = cached.class({}, OpenBusFixture)

function ContractsFixture:setup(...)
  OpenBusFixture.setup(self,...)
  self.ContractsRegistry = assert(self.governance:getFacetByName("ContractsRegistry"):__narrow())
end

function ContractsFixture:teardown(...)
  self.ContractsRegistry = nil
  OpenBusFixture.teardown(self,...)
end

return 
  ContractsFixture{
    Suite{
      AddContract = function(fixture)
        local AllContracts = {
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
        local before = fixture.ContractsRegistry:_get_contracts()
        checks.like(before, {})

        for name, interfaces in pairs(AllContracts) do
          local contract = fixture.ContractsRegistry:add(name)
          before[#before+1] = contract
          -- empty interfaces
          checks.like(contract:_get_interfaces(), {})
          for _, iface in ipairs(interfaces) do
            contract:addInterface(iface)
          end
          -- all interfaces were added
          checks.like(contract:_get_interfaces(), interfaces)
          for _, iface in ipairs(interfaces) do
            contract:removeInterface(iface)
          end
          -- all interfaces were removed
          checks.like(contract:_get_interfaces(), {})
        end

        local after = fixture.ContractsRegistry:_get_contracts()
        checks.like(after, before)

        for name in pairs(AllContracts) do
          assert(fixture.ContractsRegistry:remove(name))
        end
        checks.like(fixture.ContractsRegistry:_get_contracts(), {})
      end,
  }
}
