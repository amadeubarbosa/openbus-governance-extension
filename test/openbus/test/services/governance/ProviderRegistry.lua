local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"
local cached = require "loop.cached"

local OpenBusFixture = require "openbus.test.fixture"

ProviderFixture = cached.class({}, OpenBusFixture)

function ProviderFixture:setup(...)
  OpenBusFixture.setup(self,...)
  self.ProviderRegistry = assert(self.governance:getFacetByName("ProviderRegistry"):__narrow())
  self.ContractRegistry = assert(self.governance:getFacetByName("ContractRegistry"):__narrow())
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
  for name, interfaces in pairs(AllContract) do
    local contract = self.ContractRegistry:add(name)
    for _, iface in ipairs(interfaces) do
      contract:addInterface(iface)
    end
  end
end

function ProviderFixture:teardown(...)
  self.ProviderRegistry = nil
  for _, contract in ipairs(self.ContractRegistry:_get_contracts()) do
    self.ContractRegistry:remove(contract:_get_name())
  end
  OpenBusFixture.teardown(self,...)
end

return 
  ProviderFixture{
    Suite{
      AddRemoveProvider = function(fixture)
        local AllProvider = {
          ["BRSiOP"] = {
            "Navigation",
            "Batch Execution"
          },
          ["MARLIM"] = {
            "Navigation",
            "Batch Execution"
          },
        }
        local before = fixture.ProviderRegistry:_get_providers()
        checks.assert(before, checks.like{})

        for name, contracts in pairs(AllProvider) do
          local provider = fixture.ProviderRegistry:add(name)
          before[#before+1] = provider
          -- empty contracts
          checks.assert(provider:_get_contracts(), checks.like{})
          for _, contract in ipairs(contracts) do
            local ok = provider:addContract(contract)
            assert(provider:addContract(contract))
          end
          -- all contracts were added
          --TODO: checks.assert(provider:_get_contracts(), checks.like(contracts))
          for _, contract in ipairs(contracts) do
            assert(provider:removeContract(contract))
          end
          -- all contracts were removed
          checks.assert(provider:_get_contracts(), checks.like{})
        end

        local after = fixture.ProviderRegistry:_get_providers()
        --TODO: checks.assert(after, checks.like(before))

        for name in pairs(AllProvider) do
          assert(fixture.ProviderRegistry:remove(name))
        end
        checks.assert(fixture.ProviderRegistry:_get_providers(), checks.like{})
      end,
      ConsistencyChangesProvider = function(fixture)
        local AllContracts = {
          ["Navigation"] = false,
          ["Batch Execution"] = false,
        }
        local before = fixture.ProviderRegistry:_get_providers()
        checks.assert(before, checks.like{})

        local provider = fixture.ProviderRegistry:add("AnyProvider")
        for name in pairs(AllContracts) do
          assert(provider:addContract(name))
        end
        provider:_set_code("BUGGYAPP")
        provider:_set_office("Tecgraf/Engdist/OpenBus")
        provider:_set_support({"users@tecgraf"})
        provider:_set_manager({"openbus-dev@tecgraf"})
        provider:_set_busquery("offer.entity == 'buggy_development'")

        local updated = fixture.ProviderRegistry:get("AnyProvider")
        checks.assert(updated:_get_code(), checks.is(provider:_get_code()))
        checks.assert(updated:_get_office(), checks.is(provider:_get_office()))
        checks.assert(updated:_get_support(), checks.like(provider:_get_support()))
        checks.assert(updated:_get_manager(), checks.like(provider:_get_manager()))
        checks.assert(updated:_get_busquery(), checks.is(provider:_get_busquery()))
        for _, c in ipairs(updated:_get_contracts()) do
          local name = c:_get_name()
          checks.assert(AllContracts[name], checks.equal(false, "invalid value in AllContracts['"..name.."']"))
          AllContracts[name] = true
        end
        for _, verified in pairs(AllContracts) do
          checks.assert(verified, checks.equal(true, "some error put new values to original AllContracts test table"))
        end

        assert(fixture.ProviderRegistry:remove(updated:_get_name()))
        local after = fixture.ProviderRegistry:_get_providers()
        checks.assert(after, checks.like{})
      end,
  }
}
