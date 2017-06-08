local log = require "openbus.util.logger"
log:level(8)

local database = require "openbus.services.governance.Database"
local table = require "loop.table"

local db = assert(database.open(...))


local CONTRACTS = {
  ["Data Service"] = {
    "IDL:tecgraf/openbus/dataservice/v1_2/IDataService:1.0",
    "IDL:tecgraf/openbus/dataservice/v1_2/IHierarchicalNavigation:1.0",
    "IDL:tecgraf/openbus/dataservice/v1_2/IHierarchicalManagement:1.0",
  },
  ["Algorithms & Execution"] = {
    "IDL:tecgraf/opendreams/algorithms/v1_0/IAlgorithmService:1.0",
    "IDL:tecgraf/opendreams/service/v1_7/IOpenDreams:1.0",
    "IDL:tecgraf/opendreams/service/v1_7/IMonitoring:1.0",
  },
  ["Demo & Training"] = {
    "IDL:tecgraf/openbus/interop/v1_0/IHelloWorld:1.0",
    "IDL:helloworld/IHelloWorld:1.0",
  },
}

do -- contracts
  -- INSERT
  for c, ifaces in pairs(CONTRACTS) do
    db:pexec("addContract", c)
    for _, iface in ipairs(ifaces) do
      assert(db:pexec("addInterfaceContract", c, iface))
    end
  end
  -- SELECT
  for c, ifaces in pairs(CONTRACTS) do
    local found=table.copy(ifaces)
    db.pstmts.getInterfaceContract:bind_values(c)
    for t in db.pstmts.getInterfaceContract:nrows() do
      for i, iface in ipairs(ifaces) do
        if iface == t.interface then 
          found[i] = nil
          break
        end
      end
    end
    assert(#found == 0, "interfaces on db differs from asked to add")
  end
  -- DELETE
  for c in pairs(CONTRACTS) do
    assert(db:pexec("delContract", c))
    db.pstmts.getInterfaceContract:bind_values(c)
    for t in db.pstmts.getInterfaceContract:nrows() do
      assert(nil, "residual interfaces left on db (contract="..c..")")
    end
  end
  for t in db.pstmts.getContract:nrows() do
    assert(nil, "residual contracts left on db")
  end
end
