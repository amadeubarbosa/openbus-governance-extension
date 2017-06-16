local string = require "string"
local os = require "os"
local oil = require "oil"
local openbus = require "openbus"

local alternativepath = ...
-- load collab configuration
local configfile = assert(os.getenv("GOVERNANCE_CONFIG") or alternativepath, "missing path to governance.cfg")
local config = {}
configloader = assert(loadfile(configfile, "t", config), "config file "..configfile.." can't be read")
configloader()

-- process command-line arguments
bushost = assert(config.bushost, "missing bushost")
busport = assert(config.busport, "missing busport")
busport = assert(tonumber(busport), "invalid port ("..busport.."), must be a number")
privatekeypath = assert(config.privatekey, "missing privatekey")
entity = config.entity or "GovernanceExtensionService"

local privatekey = assert(openbus.readKeyFile(privatekeypath), 
  "privatekey ("..privatekeypath..") can't be read")

-- setup and start the ORB
local orb = openbus.initORB()

-- get bus context manager
local OpenBusContext = orb.OpenBusContext

-- connect to the bus
local connection = OpenBusContext:createConnection(bushost, busport)
OpenBusContext:setDefaultConnection(connection)
-- call in protected mode
local ok, result = pcall(function ()
  -- login to the bus
  connection:loginByCertificate(entity, privatekey)
  -- register service at the bus
  local OfferRegistry = OpenBusContext:getOfferRegistry()
  return OfferRegistry:findServices{{name="openbus.offer.entity",value=entity}}
end)

local date = os.date("%Y%m%d_%Hh%Mm%Ss")

-- show eventual errors
local errcode = 0
if not ok then
  io.stderr:write(
    string.format("[%s][error] failed to find service: %s\n",
      date, tostring(result)))
  io.stderr:flush()
  errcode = 1
elseif #result > 0 then
  for _, offer in ipairs(result) do
    local ok, result = pcall(offer.service_ref.shutdown, offer.service_ref)
    if not ok then
      io.stderr:write(
        string.format("[%s][error] failed shutting down the service: %s\n",
          date, tostring(result)))
      io.stderr:flush()
      errcode = 2
    end
  end
else
  io.stderr:write(
    string.format("[%s][error] no offer found (entity: %s)\n",
      date, entity))
  io.stderr:flush()
  errcode = 3
end

-- free any resoures allocated
connection:logout()
orb:shutdown()
oil.sleep(2)
if errcode ~= 0 then os.exit(errcode) end
