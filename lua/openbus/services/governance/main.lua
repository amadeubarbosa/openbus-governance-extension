local oil     = require "oil"
local oillog  = require "oil.verbose"
local oo      = require "openbus.util.oo"
local ComponentContext = require "scs.core.ComponentContext"

local openbus = require "openbus"
local log     = require "openbus.util.logger"
local server  = require "openbus.util.server"
local msg     = require "openbus.services.governance.messages"

local coreidl = require "openbus.core.idl"  -- OpenBus types
local InvalidLoginsType = coreidl.types.services.access_control.InvalidLogins
local ServiceFailure = coreidl.throw.services.ServiceFailure

local sysex = require "openbus.util.sysex"
local NO_PERMISSION = sysex.NO_PERMISSION

local ContractRegistry = require "openbus.services.governance.ContractRegistry"
local ProviderRegistry = require "openbus.services.governance.ProviderRegistry"
local ConsumerRegistry = require "openbus.services.governance.ConsumerRegistry"
local governanceidl = require "openbus.services.governance.idl"
local ServiceName = governanceidl.const.ServiceName

local config, orb
do -- loading configuration 
  config = server.ConfigArgs(
    {
      host = "*",
      port = 2091,    
      bushost = "localhost",
      busport = 2089,  
      database = "governance.sqlite3",
      privatekey = "governance.key",
      entity = ServiceName,
      loglevel = 4,
      logfile = "",
      oilloglevel = 0,
      oillogfile = "",
      nodnslookup = false,
      noipaddress = false,
      alternateaddr = {},
    })

  -- read configuration file
  config:configs("configs", 
    os.getenv("GOVERNANCE_CONFIG") or "governance.cfg")
  -- read arguments passed by command line
  io.write(msg.CopyrightNotice, "\n")
  local argidx, errmsg = config(...)
  if (not argidx or argidx <= select("#", ...)) then
    if (errmsg ~= nil) then
      io.stderr:write(errmsg,"\n")
    end
    io.stderr:write("\nUsage:  ", OPENBUS_PROGNAME, msg.CommandLineOptions)
    return 1
  end
  -- custom logs
  server.setuplog(log, config.loglevel, config.logfile)
  server.setuplog(oillog, config.oilloglevel, config.oillogfile)

  -- validate oil objrefaddr configuration
  local objrefaddr = {
    hostname = (not config.nodnslookup),
    ipaddress = (not config.noipaddress),
  }
  local additional = {}
  for _, address in ipairs(config.alternateaddr) do
    local host, port = address:match("^([%w%-%_%.]+):(%d+)$")
    port = tonumber(port)
    if (host ~= nil) and (port ~= nil) then
      additional[#additional+1] = { host = host, port = port }
    else
      log:misconfig(msg.WrongAlternateAddressSyntax:tag{
        value = address,
        expected = "host:port or ip:port",
      })
      return 1
    end
  end
  if (#additional > 0) then
    objrefaddr.additional = additional
  end
  log:config(msg.AdditionalInternetAddressConfiguration:tag(objrefaddr))

  -- CORBA ORB activated with OpenBus protocol
  orb = openbus.initORB{
    host = config.host,
    port = config.port,
    objrefaddr = objrefaddr,
  }
end

-- load interface definitions
governanceidl.loadto(orb)

-- get bus context manager
local OpenBusContext = orb.OpenBusContext

-- bus connection
local connection = OpenBusContext:createConnection(config.bushost, config.busport)
OpenBusContext:setDefaultConnection(connection)
connection:loginByPassword(config.entity, config.entity, "testing")

do -- server creation
  local component = server.newSCS(
    {
      orb = orb,
      name = ServiceName,
      objkey = ServiceName,
      facets = {
          ContractRegistry = ContractRegistry(),
          ProviderRegistry = ProviderRegistry(),
          ConsumerRegistry = ConsumerRegistry(),
      },
      shutdown = function(self)
        local caller = OpenBusContext:getCallerChain().caller
        if caller.entity ~= config.entity and caller.entity ~= BusEntity then
          NO_PERMISSION{ completed = "COMPLETED_NO" }
        end
        self.context:deactivateComponent()
        connection:logout()
        orb:shutdown()
        log:uptime(msg.ServiceTerminated)
      end,
    })
  component.IComponent:startup()

  local offers = OpenBusContext:getOfferRegistry()
  local ok, errmsg = pcall(offers.registerService, offers, component.IComponent, {})
  if (not ok) then
    ServiceFailure({
      message = msg.UnableToRegisterService:tag({
        error = errmsg
      })
    })
  end
end

log:uptime(msg.ServiceSuccessfullyStarted)
