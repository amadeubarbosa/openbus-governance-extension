local oil= require 'oil'

local log = require "openbus.util.logger"

local database = require "openbus.services.governance.Database"

local db = assert(database.open(...))

-- seed to random string
math.randomseed(oil.time()*1.e6)
function string.random(length)
  local chars={"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9"}

  local result={}
  for i=1,tonumber(length) do
    result[i] = chars[math.random(#chars)]
  end
  return table.concat(result)
end

-- log level (ex: log:database starts on 7)
log:level(7)

local table = require "loop.table"

local CONTRACTS = {
  { name ="Data Service",
    interfaces = {
      "IDL:tecgraf/openbus/dataservice/v1_2/IDataService:1.0",
      "IDL:tecgraf/openbus/dataservice/v1_2/IHierarchicalNavigation:1.0",
      "IDL:tecgraf/openbus/dataservice/v1_2/IHierarchicalManagement:1.0",
    },
  },
  { name = "Algorithms & Execution",
    interfaces = {
      "IDL:tecgraf/opendreams/algorithms/v1_0/IAlgorithmService:1.0",
      "IDL:tecgraf/opendreams/service/v1_7/IOpenDreams:1.0",
      "IDL:tecgraf/opendreams/service/v1_7/IMonitoring:1.0",
    },
  },
  { name = "Demo & Training",
    interfaces = {
      "IDL:tecgraf/openbus/interop/v1_0/IHelloWorld:1.0",
      "IDL:helloworld/IHelloWorld:1.0",
    },
  }
}

-- BASIC CONSISTENCY
--
do -- CONTRACTS
  -- INSERT
  for _, c in ipairs(CONTRACTS) do
    assert(db:pexec("addContract", c))
    for _, iface in ipairs(c.interfaces) do
      assert(db:pexec("addInterfaceContract", c.name, iface))
    end
  end
  -- SELECT
  for _, c in ipairs(CONTRACTS) do
    local found=table.copy(c.interfaces)
    db.pstmts.getInterfaceContract:bind_values(c.name)
    for t in db.pstmts.getInterfaceContract:nrows() do
      for i, iface in ipairs(c.interfaces) do
        if iface == t.interface then
          found[i] = nil
          break
        end
      end
    end
    assert(#found == 0, "interfaces on db differs from asked to add")
  end
  -- DELETE
  for _, c in ipairs(CONTRACTS) do
    assert(db:pexec("delContract", c))
    db.pstmts.getInterfaceContract:bind_values(c.name)
    for t in db.pstmts.getInterfaceContract:nrows() do
      assert(nil, "residual interfaces left on db (contract="..c..")")
    end
  end
  for t in db.pstmts.getContract:nrows() do
    assert(nil, "residual contracts left on db")
  end
end

local CONSUMERS = {}
for i=1,10 do
  CONSUMERS[i] = { 
    name=string.random(6), code=string.random(4),
    supportoffice=string.random(6), manageroffice=string.random(6),
    support=string.random(6), manager=string.random(6),
    busquery=string.random(25)
  }
end

do -- CONSUMERS
  -- INSERT
  for _, c in ipairs(CONSUMERS) do
    assert(db:pexec("addConsumer", c))
  end
  -- SELECT
  local found=table.copy(CONSUMERS)
  for t in db.pstmts.getConsumer:nrows() do
    for i, c in ipairs(CONSUMERS) do
      if c.name == t.name then
        found[i] = nil
        break
      end
    end
  end
  assert(#found == 0, "consumers on db differs from asked to add")
  -- DELETE
  for _, c in ipairs(CONSUMERS) do
    assert(db:pexec("delConsumer", c))
    for t in db.pstmts.getConsumerByName:nrows() do
      assert(nil, "residual consumer left on db (consumer="..c.name..")")
    end
  end
  for t in db.pstmts.getConsumer:nrows() do
    assert(nil, "residual consumers left on db")
  end
end

local PROVIDERS = {}
for i=1,10 do
  PROVIDERS[i] = { 
    name=string.random(6), code=string.random(4),
    supportoffice=string.random(6), manageroffice=string.random(6),
    support=string.random(6), manager=string.random(6),
    busquery=string.random(25), CONTRACTS={}
  }
  for j=1,5 do
    PROVIDERS[i].CONTRACTS[CONTRACTS[math.random(#CONTRACTS)]] = true
  end
end

do -- PROVIDERS
  -- INSERT
  local contractscleanup = {}
  for _, p in ipairs(PROVIDERS) do
    assert(db:pexec("addProvider", p))
    for c in pairs(p.CONTRACTS) do
      if not contractscleanup[c.name] then
        db:pexec("addContract", c.name)
        contractscleanup[c.name] = true
      end
      assert(db:pexec("addProviderContract", c.name, p.name))
    end
  end
  -- SELECT
  local found = table.copy(PROVIDERS)
  for t in db.pstmts.getProvider:nrows() do
    for i, p in ipairs(PROVIDERS) do
      if p.name == t.name then
        found[i] = nil
        local foundrelationship = table.copy(p.CONTRACTS)
        db.pstmts.getProviderContract:bind_values(p.name)
        for pc in db.pstmts.getProviderContract:nrows() do
          for c in pairs(p.CONTRACTS) do
            if c.name == pc.contract then
              foundrelationship[c] = nil
              break
            end
          end
        end
        for r in pairs(foundrelationship) do
          assert(nil, "relationship provider x contract on db differs from asked to add ("..r.name..")")
        end
        break
      end
    end
  end
  assert(#found == 0, "providers on db differs from asked to add")
  -- DELETE
  for _, p in ipairs(PROVIDERS) do
    assert(db:pexec("delProvider", p))
    db.pstmts.getProviderContract:bind_values(p.name)
    for t in db.pstmts.getProviderContract:nrows() do
      assert(nil, "residual provider x contract relationship left on db (provider="..t.provider..",contract="..t.contract..")")
    end
  end
  for t in db.pstmts.getProvider:nrows() do
    assert(nil, "residual providers left on db")
  end
  -- CLEANUP
  for name in pairs(contractscleanup) do
    db:pexec("delContract", name)
  end
  contractscleanup = nil
  for t in db.pstmts.getContract:nrows() do
    assert(nil, "residual contracts left on db after provider test routine")
  end
end

local INTEGRATIONS = {}
for i=1,10 do
  local provider = PROVIDERS[math.random(#PROVIDERS)]
  INTEGRATIONS[i] = { consumer=CONSUMERS[math.random(#CONSUMERS)].name, provider=provider.name, activated=(math.random(2) == 1), CONTRACTS={} }
  local j=1 repeat
    local random = CONTRACTS[math.random(#CONTRACTS)]
    for supported in pairs(provider.CONTRACTS) do
      if supported.name == random.name then
        INTEGRATIONS[i].CONTRACTS[supported] = true
        j = j+1
      end
    end
  until (j==5)
end

do -- INTEGRATIONS
  -- INSERT
  local contractscleanup = {}
  for _, int in ipairs(INTEGRATIONS) do
    assert(db:pexec("addIntegration", int))
    -- auto increment integration ID
    int.id = db.conn:last_insert_rowid()
    assert(int.id ~= 0, "autoincrement integration id column failed")
    for c in pairs(int.CONTRACTS) do
      if not contractscleanup[c.name] then
        db:pexec("addContract", c.name)
        contractscleanup[c.name] = true
      end
      assert(db:pexec("addIntegrationContract", c.name, int.id))
    end
  end
  -- SELECT
  local found = table.copy(INTEGRATIONS)
  for t in db.pstmts.getIntegration:nrows() do
    for i, int in ipairs(INTEGRATIONS) do
      if int.id == t.id then
        found[i] = nil
        local foundrelationship = table.copy(int.CONTRACTS)
        db.pstmts.getIntegrationContract:bind_values(int.id)
        for intc in db.pstmts.getIntegrationContract:nrows() do
          for c in pairs(int.CONTRACTS) do
            if c.name == intc.contract then
              foundrelationship[c] = nil
              break
            end
          end
        end
        for r in pairs(foundrelationship) do
          assert(nil, "relationship integration x contract on db differs from asked to add ("..r.name..")")
        end
        break
      end
    end
  end
  assert(#found == 0, "integrations on db differs from asked to add")
  -- DELETE
  for _, int in ipairs(INTEGRATIONS) do
    assert(db:pexec("delIntegration", int))
    db.pstmts.getIntegrationContract:bind_values(int.id)
    for t in db.pstmts.getIntegrationContract:nrows() do
      assert(nil, "residual integration x contract relationship left on db (integration="..t.id.."provider="..t.provider..",contract="..t.contract..")")
    end
  end
  for t in db.pstmts.getIntegration:nrows() do
    assert(nil, "residual integrations left on db")
  end
  -- CLEANUP
  for name in pairs(contractscleanup) do
    db:pexec("delContract", name)
  end
  contractscleanup = nil
  for t in db.pstmts.getContract:nrows() do
    assert(nil, "residual contracts left on db after integratio test routine")
  end
end
