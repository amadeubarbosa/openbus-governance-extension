local Suite = require "loop.test.Suite"
local checks = require "loop.test.checks"
local cached = require "loop.cached"

local OpenBusFixture = require "openbus.test.fixture"

ConsumerFixture = cached.class({}, OpenBusFixture)

function ConsumerFixture:setup(...)
  OpenBusFixture.setup(self,...)
  self.ConsumerRegistry = assert(self.governance:getFacetByName("ConsumerRegistry"):__narrow())
end

function ConsumerFixture:teardown(...)
  self.ConsumerRegistry = nil
  OpenBusFixture.teardown(self,...)
end

return 
  ConsumerFixture{
    Suite{
      AddRemoveConsumer = function(fixture)
        local AllConsumer = {
          ["BRPlugins"] = false,
          ["SIGEO"] = false,
        }
        local before = fixture.ConsumerRegistry:_get_consumers()
        checks.assert(before, checks.like{})

        for name in pairs(AllConsumer) do
          local consumer = fixture.ConsumerRegistry:add(name)
          before[#before+1] = consumer
        end

        local after = fixture.ConsumerRegistry:_get_consumers()
        --TODO: checks.assert(after, checks.like(before))
        for _, c in ipairs(after) do
          local name = c:_get_name()
          checks.assert(AllConsumer[name], checks.equal(false, "invalid value in AllConsumer['"..name.."']"))
          AllConsumer[name] = true
        end
        for _, verified in pairs(AllConsumer) do
          checks.assert(verified, checks.equal(true, "some error put new values to original AllConsumer test table"))
        end

        for name in pairs(AllConsumer) do
          assert(fixture.ConsumerRegistry:remove(name))
        end
        checks.assert(fixture.ConsumerRegistry:_get_consumers(), checks.like{})
      end,
      ConsistencyChangesConsumer = function(fixture)
        local before = fixture.ConsumerRegistry:_get_consumers()
        checks.assert(before, checks.like{})

        local consumer = fixture.ConsumerRegistry:add("AnyConsumer")
        consumer:_set_name("AnyNewConsumerName")
        consumer:_set_code("BUGGYAPP")
        consumer:_set_supportoffice("Tecgraf/Engdist/OpenBus")
        consumer:_set_manageroffice("Tecgraf/External")
        consumer:_set_support({"users@tecgraf"})
        consumer:_set_manager({"openbus-dev@tecgraf"})
        consumer:_set_busquery("offer.entity == 'buggy_development'")

        local updated = fixture.ConsumerRegistry:get("AnyNewConsumerName")
        checks.assert(updated:_get_name(), checks.is(consumer:_get_name()))
        checks.assert(updated:_get_code(), checks.is(consumer:_get_code()))
        checks.assert(updated:_get_supportoffice(), checks.is(consumer:_get_supportoffice()))
        checks.assert(updated:_get_manageroffice(), checks.is(consumer:_get_manageroffice()))
        checks.assert(updated:_get_support(), checks.like(consumer:_get_support()))
        checks.assert(updated:_get_manager(), checks.like(consumer:_get_manager()))
        checks.assert(updated:_get_busquery(), checks.is(consumer:_get_busquery()))

        assert(fixture.ConsumerRegistry:remove(updated:_get_name()))
        local after = fixture.ConsumerRegistry:_get_consumers()
        checks.assert(after, checks.like{})
      end,
  }
}
