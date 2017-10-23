#!/usr/bin/env busadmin

local _G = require "_G"
local assert = _G.assert
local error = _G.error
local ipairs = _G.ipairs
local loadfile = _G.loadfile
local luatype = _G.type
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local setmetatable = _G.setmetatable
local tostring = _G.tostring

local array = require "table"
local unpack = array.unpack

local io = require "io"
local stderr = io.stderr

local Arguments = require "loop.compiler.Arguments"

local Viewer = require "loop.debug.Viewer"

local ltable = require "loop.table"
local memoize = ltable.memoize

local msg = require "openbus.util.messages"
local log = require "openbus.util.logger"
local sandbox = require "openbus.util.sandbox"
local newsandbox = sandbox.create

local governanceidl = require "openbus.services.governance.idl"
local ContractRegistry    = governanceidl.types.ContractRegistry
local IntegrationRegistry = governanceidl.types.IntegrationRegistry
local ConsumerRegistry    = governanceidl.types.ConsumerRegistry
local ProviderRegistry    = governanceidl.types.ProviderRegistry

local viewer = Viewer{
  indentation = "",
  linebreak = " ",
  nolabels = true,
  noindices = true,
}

local args = Arguments{
  verbose = 2,
  unload = false,
  help = false,
}
args._alias = {
  v = "verbose",
  u = "unload",
  h = "help",
}


-- parse command line parameters
local argidx, errmsg = args(...)
if argidx == nil or argidx > select("#", ...) then
  if argidx ~= nil then
    errmsg = msg.DescriptorPathMissing
  end
  stderr:write(errmsg,"\n")
  args.help = true
end

if args.help then
  stderr:write([[
Usage:  [options] <path to busextension descriptor>
Options:

  -v, -verbose <log level>         0=deactivated, 1=error, 2=everything (default: 2)
  -u, -unload                      remove all data described on descriptor file
  -h, -help                        show this help message

]])
  return 1
end

if args.verbose > 0 then
  log:flag("warning", true)
  log:flag("success", true)
end
if args.verbose > 1 then
  log:flag("failure", true)
end

local exitcode = 0

-- new busadmin operation: loadidl
loadidl(governanceidl.loadto)

local service = memoize(
  function(interface)
    local result = offers{{name="openbus.component.interface", value=interface}}
    for _, offer in ipairs(result) do
      local ref = offer.service_ref
      local ok, res = pcall(ref._non_existent, ref)
      if ok and res == false then
        return ref:getFacet(interface):__narrow()
      end
    end
    error(msg.GovernanceExtensionServiceNotFound:tag{interface=interface})
  end,
  "kv")

local stringfycontracts = function(list)
  local result = ""
  for i, contract in ipairs(list) do
    result = result.. contract:_get_name()
    if i < #list then
      result = result .. ","
    end
  end
  return result
end

local Definitions = {
  {
    tag = "Contract",
    fields = {
      {name = "name", type = "string"},
      {name = "interfaces", type = {"string"}},
    },
    load = function(name, interfaces)
      local contract = service[ContractRegistry]:get(name)
      if not contract then
        contract = service[ContractRegistry]:add(name)
      else
        log:warning(msg.UpdatingInterfacesOfExistentContract:tag{name=name})
      end
      for _, iface in ipairs(interfaces) do
        contract:addInterface(iface)
      end
    end,
    unload = function(name)
      service[ContractRegistry]:remove(name)
    end,
  }, {
    tag = "Consumer",
    fields = {
      {name = "name", type = "string"},
      {name = "code", type = "string"},
      {name = "supportoffice", type = "string"},
      {name = "manageroffice", type = "string"},
      {name = "support", type = {"string"}},
      {name = "manager", type = {"string"}},
      {name = "busquery", type = "string"},
    },
    load = function(name, code, soffice, moffice, support, manager, busquery)
      local consumer = service[ConsumerRegistry]:get(name)
      local updating = false
      if not consumer then
        consumer = service[ConsumerRegistry]:add(name)
      else
        updating = true
        log:warning(msg.UpdatingDataOfExistentConsumer:tag{name=name})
      end
      consumer:_set_code(code)
      consumer:_set_supportoffice(soffice)
      consumer:_set_manageroffice(moffice)
      consumer:_set_busquery(busquery)
      if updating then
        local data = consumer:_get_support()
        for _, supp in ipairs(support) do
          data[#data+1] = supp
        end
        consumer:_set_support(data)
        local data = consumer:_get_manager()
        for _, mng in ipairs(manager) do
          data[#data+1] = mng
        end
        consumer:_set_manager(data)
      else
        consumer:_set_support(support)
        consumer:_set_manager(manager)
      end
    end,
    unload = function(name)
      service[ConsumerRegistry]:remove(name)
    end,
  }, {
    tag = "Provider",
    fields = {
      {name = "name", type = "string"},
      {name = "code", type = "string"},
      {name = "supportoffice", type = "string"},
      {name = "manageroffice", type = "string"},
      {name = "support", type = {"string"}},
      {name = "manager", type = {"string"}},
      {name = "busquery", type = "string"},
      {name = "contracts", type = {"string"}},
    },
    load = function(name, code, soffice, moffice, support, manager, busquery, contracts)
      local provider = service[ProviderRegistry]:get(name)
      local updating = false
      if not provider then
        provider = service[ProviderRegistry]:add(name)
      else
        updating = true
        log:warning(msg.UpdatingDataOfExistentProvider:tag{name=name})
      end
      provider:_set_code(code)
      provider:_set_supportoffice(soffice)
      provider:_set_manageroffice(moffice)
      provider:_set_busquery(busquery)
      if updating then
        local data = provider:_get_support()
        for _, supp in ipairs(support) do
          data[#data+1] = supp
        end
        provider:_set_support(data)
        local data = provider:_get_manager()
        for _, mng in ipairs(manager) do
          data[#data+1] = mng
        end
        provider:_set_manager(data)
      else
        provider:_set_support(support)
        provider:_set_manager(manager)
      end
      for _, contract in ipairs(contracts) do
        provider:addContract(contract)
      end
    end,
    unload = function(name)
      service[ProviderRegistry]:remove(name)
    end,
  }, {
    tag = "Integration",
    fields = {
      {name = "consumer", type = "string"},
      {name = "provider", type = "string"},
      {name = "contracts", type = {"string"}},
      {name = "activated", type = "boolean"},
    },
    load = function(consumer_name, provider_name, contracts, activated)
      local result = service[IntegrationRegistry]:_get_integrations()
      local consumer = assert(service[ConsumerRegistry]:get(consumer_name), "consumer "..consumer_name.." doesnt exist")
      local provider = assert(service[ProviderRegistry]:get(provider_name), "provider "..provider_name.." doesnt exist")
      for _, integration in ipairs(result) do
        if integration:_get_consumer():_get_name() == consumer_name and
          integration:_get_provider():_get_name() == provider_name then
          local current = integration:_get_contracts()
          local comparison = function(c1, c2) return c1:_get_name() == c2:_get_name() end
          table.sort(current, comparison)
          local integrationcontracts = stringfycontracts(current)
          table.sort(contracts, comparison)
          local givencontracts = table.concat(contracts, ",")
          if givencontracts == integrationcontracts then
            log:warning(msg.UpdatingActivattionFieldOfExistentIntegration:tag{consumer=consumer:_get_name(), provider=provider:_get_name(), id=integration:_get_id()})
            -- only force the update the activated field
            integration:_set_activated(activated)
            return
          end
        end
      end
      local integration = service[IntegrationRegistry]:add()
      integration:_set_consumer(consumer)
      integration:_set_provider(provider)
      integration:_set_activated(activated)
      for _, contract in ipairs(contracts) do
        integration:addContract(contract)
      end
    end,
    unload = function(consumer, provider, contracts, activated)
    local result = service[IntegrationRegistry]:_get_integrations()
      for _, integration in ipairs(result) do
        if integration:_get_consumer():_get_name() == consumer and
          integration:_get_provider():_get_name() == provider then
          local current = integration:_get_contracts()
          local comparison = function(c1, c2) return c1:_get_name() == c2:_get_name() end
          table.sort(current, comparison)
          local integrationcontracts = stringfycontracts(current)
          table.sort(contracts, comparison)
          local givencontracts = table.concat(contracts, ",")
          if givencontracts == integrationcontracts then
            service[IntegrationRegistry]:remove(integration:_get_id())
            return
          end
        end
      end
      error(msg.IntegrationNotFound:tag{consumer=consumer:_get_name(), provider=provider:_get_name()})
    end,
  },
}

local function checkfields(value, typespec, prefix)
  if luatype(typespec) == "table" then
    prefix = prefix and prefix.."." or ""
    if type(typespec[1]) == "table" then
      for _, field in pairs(typespec) do
        local fieldname, typespec = field.name, field.type
        checkfields(value[fieldname], typespec, prefix..fieldname)
      end
    else
      typespec = typespec[1]
      for index, value in ipairs(value) do
        checkfields(value, typespec, prefix.."["..index.."]")
      end
    end
  elseif luatype(value) ~= typespec then
    error("field '"..prefix.."' must be '"..typespec.."', but is '"..luatype(value).."'")
  end
end

local env = setmetatable(newsandbox(), {__index = _G})
local defs = {}
for index, info in ipairs(Definitions) do
  env[info.tag] = function (fields)
    checkfields(fields, info.fields)
    local list = defs[info.tag]
    if list == nil then
      list = { fields }
      defs[info.tag] = list
    else
      list[#list+1] = fields
    end
  end
end

local op, start, finish, increment = "load", 1, #Definitions, 1
if args.unload then
  op, start, finish, increment = "unload", finish, start, -1
end

local path = select(argidx, ...)
local loader, errmsg = loadfile(path, "t" , env)
if loader ~= nil then
  local ok, errmsg = pcall(loader, select(argidx+1, ...))
  if ok then
    local ok, errmsg = whoami()
    if not ok then
      io.write("Bus Ref.: ")
      local busref = assert(io.read())
      io.write("Entity: ")
      local entity = assert(io.read())
      ok, errmsg = pcall(login, busref, entity)
    end
    if ok then
      for i = start, finish, increment do
        local info = Definitions[i]
        local list = defs[info.tag]
        if list ~= nil then
          for _, fields in ipairs(list) do
            local params = {}
            for index, field in ipairs(info.fields) do
              params[index] = fields[field.name]
            end
            local ok, result = pcall(info[op], unpack(params))
            local logtag
            if ok then
              logtag = "success"
              result = ""
            else
              logtag = "failure"
              result = ": "..result
              exitcode = 5
            end
            log[logtag](log, op," ",info.tag," ",viewer:tostring(params),result)
          end
        end
      end
    else
      log:failure(msg.LoginFailure:tag{error=errmsg})
      exitcode = 4
    end
  else
    log:failure(errmsg)
    exitcode = 3
  end
else
  log:failure(errmsg)
  exitcode = 2
end

return exitcode
