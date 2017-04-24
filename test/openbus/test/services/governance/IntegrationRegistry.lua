local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"
local cached = require "loop.cached"

require "openbus.test.services.governance.ProviderRegistry"

IntegrationFixture = cached.class({}, ProviderFixture)

function IntegrationFixture:setup(...)
  ProviderFixture.setup(self,...)
  self.IntegrationRegistry = assert(self.governance:getFacetByName("IntegrationRegistry"):__narrow())
  self.ConsumerRegistry = assert(self.governance:getFacetByName("ConsumerRegistry"):__narrow())
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
  for name, contracts in pairs(AllProvider) do
    local provider = self.ProviderRegistry:add(name)
    for _, contractName in ipairs(contracts) do
      assert(provider:addContract(contractName))
    end
  end
  local AllConsumer = {
    ["VGEPlugins"] = {
      code = "WELLIMP",
      office = "Tecgraf/Engdist/OpenBus",
      support = {"users@tecgraf"},
      manager = {"boss@tecgraf"},
      busquery = "offer.entity == 'plugins_development'",
    },
    ["RECON"] = {
      code = "RECGEO",
      office = "Tecgraf/RECON",
      support = {"recon@tecgraf"},
      manager = {"boss2@tecgraf"},
      busquery = "offer.entity == 'recon_development'",
    },
  }
  for name, fields in pairs(AllConsumer) do
    local consumer = self.ConsumerRegistry:add(name)
    for k,v in pairs(fields) do
      consumer["_set_"..k](consumer, v)
    end
  end
end

function IntegrationFixture:teardown(...)
  ProviderFixture.teardown(self,...)
  self.ConsumerRegistry = nil
  self.IntegrationRegistry = nil
end

return 
  IntegrationFixture{
    Suite{
      AddRemoveIntegration = function(fixture)
        local AllIntegration = { -- provider name x consumer table
          ["BRSiOP"] = { -- consumer table
            name = "RECON",
            contracts = {"Navigation"},
            activated = true,
          },
          ["MARLIM"] = { -- consumer table
            name = "VGEPlugins",
            contracts = {"Navigation", "Batch Execution"},
            activated = false,
          },
        }
        local before = fixture.IntegrationRegistry:_get_integrations()
        checks.assert(before, checks.like{})

        local AllIds = {}
        for name, details in pairs(AllIntegration) do
          local integration = fixture.IntegrationRegistry:add()
          AllIds[#AllIds+1] = integration:_get_id()
          integration:_set_provider(assert(fixture.ProviderRegistry:get(name)))
          integration:_set_consumer(assert(fixture.ConsumerRegistry:get(details.name)))
          integration:_set_activated(details.activated)
          before[#before+1] = integration
          -- empty contracts
          checks.assert(integration:_get_contracts(), checks.like{})
          for _, contract in ipairs(details.contracts) do
            assert(integration:addContract(contract))
          end
          -- all contracts were added
          --TODO: checks.assert(integration:_get_contracts(), checks.like(details.contracts))
          for _, contract in ipairs(details.contracts) do
            assert(integration:removeContract(contract))
          end
          -- all contracts were removed
          checks.assert(integration:_get_contracts(), checks.like{})
        end

        for _, id in ipairs(AllIds) do
          assert(fixture.IntegrationRegistry:remove(id))
        end
        local after = fixture.IntegrationRegistry:_get_integrations()
        checks.assert(after, checks.like{})
      end,
  }
}
