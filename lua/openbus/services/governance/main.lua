local oil     = require "oil"
local oillog  = require "oil.verbose"

local openbus = require "openbus"
local oo      = require "openbus.util.oo"
local log     = require "openbus.util.logger"
local server  = require "openbus.util.server"
local sleep   = openbus.sleep

local coreidl = require "openbus.core.idl"  -- OpenBus types
local ServiceFailure = coreidl.throw.services.ServiceFailure

local libidl = require "openbus.idl"
local AlreadyLoggedIn = libidl.types.AlreadyLoggedIn

local sysex = require "openbus.util.sysex"
local NO_PERMISSION = sysex.NO_PERMISSION

local db = require "openbus.services.governance.Database"
local dbopen = db.open
local dbversion = db.checkversion

local ContractRegistry = require "openbus.services.governance.ContractRegistry"
local ProviderRegistry = require "openbus.services.governance.ProviderRegistry"
local ConsumerRegistry = require "openbus.services.governance.ConsumerRegistry"
local IntegrationRegistry = require "openbus.services.governance.IntegrationRegistry"

local governanceidl = require "openbus.services.governance.idl"
local ServiceName = governanceidl.const.ServiceName

local msg = require "openbus.services.governance.messages"

return function(...)
  local config, orb, privatekey, database
  do -- loading configuration
    config = server.ConfigArgs(
      {
        _badnumber = "invalid value for option '%s', number excepted but got '%s'",
        _missing = "no value defined for option '%s'",
        _unknown = "unknown option '%s'",
        _norepeat = "option '%s' was already defined",

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
        relogininterval = 5,
        
        help = false,
        version = false,
        _alias = {
          v = "version",
          h = "help",
        },
      })

    -- read configuration file
    config:configs("configs",
      os.getenv("GOVERNANCE_CONFIG") or "governance.cfg")
    -- read arguments passed by command line
    local argidx, errmsg = config(...)
    if (not argidx or argidx <= select("#", ...)) then
      if (errmsg ~= nil) then
        io.stderr:write(msg.ErrorProcessingCommandLine,": ", errmsg,"\n\n")
        config.help = true
      end
    end
    if config.help then
      io.write(msg.CopyrightNotice, "\n")
      io.stderr:write([[
Usage:  ]], OPENBUS_PROGNAME, [[ [options]
Options:

  -host <name>                hostname or IP address used by this service (default: "0.0.0.0")
  -port <number>              network port used by this service (default: 2091)
  -database <path>            path to SQLite3 database (default: governance.sqlite3)
  -bushost <name>             hostname used to connect to openbus (default: "localhost")
  -busport <number>           network port used to connect to openbus (default: 2089)
  -privatekey <path>          path to private key file used to authenticate on openbus (default: governance.key)
  -entity <name>              entity name used to authenticate on openbus (default: ]]..governanceidl.const.ServiceName..[[)
  -loglevel <number>          verbose level used on service calls (default: 4)
  -logfile <path>             output file for verbose messages on service calls (default: standard output)
  -oilloglevel <number>       verbose level for OiL, use only for debugging purpose (default: 0)
  -oillogfile <path>          output file for verbose OiL messages (default: standard output)
  -nodnslookup                prevent to use DNS names on IOR references (default: disabled)
  -noipaddress                prevent to use IP address on IOR references (default: disabled)
  -alternateaddr <host:port>  optional network address to be included on IOR reference (default: none)
  -relogininterval <number>   interval in seconds to retry the login on bus after a failure (default: 5)
  
  -configs <path>             path to additional configuration file (default: governance.cfg or GOVERNANCE_CONFIG env variable)

  -h, -help                   show this help message
  -v, -version                show program version
]])
      return 1
    end
    if config.version then
      io.write(msg.CopyrightNotice, "\n")
      return 0
    end
    -- custom logs
    server.setuplog(log, config.loglevel, config.logfile)
    log:config(msg.ServiceLogLevel:tag{value=config.loglevel})
    server.setuplog(oillog, config.oilloglevel, config.oillogfile)
    log:config(msg.OilLogLevel:tag{value=config.oilloglevel})
  
    do -- read privatekey
      local result, errmsg = server.readprivatekey(config.privatekey)
      if not result then
        log:misconfig(msg.UnableToLoadPrivateKey:tag{path=config.privatekey, error=errmsg})
        return 1
      end
      privatekey = result
      log:config(msg.ServicePrivateKeyLoaded:tag{path=config.privatekey})
    end
  
    do -- open database
      local result, errmsg = dbopen(config.database)
      if not result then
       log:misconfig(msg.UnableToLoadDatabase:tag{path=config.database, error=errmsg})
       return 1
      end
      database = result
      log:config(msg.ServiceDatabaseLoaded:tag{path=config.database,version=database.version})
    end
  
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
  
    -- CORBA ORB activated with OpenBus protocol
    orb = openbus.initORB{
      host = config.host,
      port = config.port,
      objrefaddr = objrefaddr,
    }
  
    log:config(msg.ServiceListeningAddress:tag{host=orb.host,port=orb.port})
    log:config(msg.AdditionalInternetAddressConfiguration:tag(objrefaddr))
  end
  
  -- load interface definitions
  governanceidl.loadto(orb)
  
  -- get bus context manager
  local OpenBusContext = orb.OpenBusContext
  
  -- bus connection
  local connection = OpenBusContext:createConnection(config.bushost, config.busport)
  OpenBusContext:setDefaultConnection(connection)
  connection:loginByCertificate(config.entity, privatekey)
  log:config(msg.ServiceConnectedToBus:tag{host=config.bushost, port=config.busport})
  
  local component do -- server creation
    component = server.newSCS(
      {
        orb = orb,
        name = ServiceName,
        objkey = ServiceName,
        facets = {
          ContractRegistry = ContractRegistry,
          ProviderRegistry = ProviderRegistry,
          ConsumerRegistry = ConsumerRegistry,
          IntegrationRegistry = IntegrationRegistry,
        },
        init = function()
          -- facets should be initialize in this order
          ContractRegistry.database = database
          ContractRegistry:__init()
          ConsumerRegistry.database = database
          ConsumerRegistry:__init()
          ProviderRegistry.database = database
          ProviderRegistry:__init()
          IntegrationRegistry.database = database
          IntegrationRegistry:__init()
        end,
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
    -- register service offer
    local registerService = function() 
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
    registerService()
    -- callback to retry the login and register service again
    connection.onInvalidLogin = function(conn, oldlogin)
      while true do
        local ok, ex = pcall(function()
          log:action(msg.RetryLogInAfterInvalidLogin:tag{bushost=config.bushost,busport=config.busport,oldlogin=oldlogin.id})
          conn:loginByCertificate(config.entity, privatekey)
          registerService()
        end)
        if ok or ex._repid == AlreadyLoggedIn then
          break
        end
        log:exception(msg.FailedRetryingLogIn:tag{bushost=config.bushost,busport=config.busport,error=ex})
        sleep(config.relogininterval)
      end
    end
  end
  
  log:uptime(msg.ServiceSuccessfullyStarted)
end
