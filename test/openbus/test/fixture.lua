local table = require "loop.table"
local cached = require "loop.cached"

local Fixture = require "loop.test.Fixture"

local openbus = require "openbus"
local governanceidl = require "openbus.services.governance.idl"

require "openbus.test.util"

setorbcfg(orbsecurity, true) -- able to configure ssl

local OpenBusFixture = cached.class({}, Fixture)

function OpenBusFixture:setup()
  self.orb = openbus.initORB(orbcfg and table.copy(orbcfg))
  self.context = self.orb.OpenBusContext
  governanceidl.loadto(self.orb)
  local idlloaders = self.idlloaders
  if idlloaders ~= nil then
    for _, loader in ipairs(idlloaders) do
      loader(self.orb)
    end
  end
  self.conn = self.context:createConnection(bushost, busport)
  self.context:setDefaultConnection(self.conn)
  self.conn:loginByPassword(user, password, domain)
  local offers = findoffers(
                  self.context:getOfferRegistry(), 
                  {{ 
                    name="openbus.component.name",
                    value=governanceidl.const.ServiceName
                  }})
  self.governance = assert(offers[1]).service_ref
end

function OpenBusFixture:teardown()
  self.conn:logout()
  self.orb:shutdown()
  self.orb = nil
  self.context = nil
  self.conn = nil
  self.governance = nil 
end

return OpenBusFixture
