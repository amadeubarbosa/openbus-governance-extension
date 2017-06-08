local lsqlite = require "lsqlite3"

local lfs = require "lfs"
local getattribute = lfs.attributes

local log = require "openbus.util.logger"
local msg = require "openbus.util.messages"

local oo = require "openbus.util.oo"
local class = oo.class

local Database = class()

local DB_VERSION = 10 --  1.0

local SQL_QUERY_VERSION = 
[[PRAGMA main.user_version;]]

local SQL_UPDATE_VERSION = 
[[PRAGMA main.user_version = ]]..DB_VERSION..[[;]]

local SQL_CREATE_TABLES = [[
  CREATE TABLE IF NOT EXISTS interface (
    repid      TEXT PRIMARY KEY
  );

  CREATE TABLE IF NOT EXISTS contract (
    name       TEXT PRIMARY KEY
  );

  CREATE TABLE IF NOT EXISTS provider (
    name       TEXT PRIMARY KEY,
    code       TEXT,
    office     TEXT,
    support    TEXT,
    manager    TEXT,
    busquery   TEXT
  );

  CREATE TABLE IF NOT EXISTS consumer (
    name       TEXT PRIMARY KEY,
    code       TEXT,
    office     TEXT,
    support    TEXT,
    manager    TEXT,
    busquery   TEXT
  );

  CREATE TABLE IF NOT EXISTS integration (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    consumer   TEXT,
    provider   TEXT,
    activated  INTEGER
  );

  CREATE TABLE IF NOT EXISTS interfaceContract (
    contract   TEXT NOT NULL
               REFERENCES contract(name)
               ON DELETE CASCADE,
    interface  TEXT NOT NULL
               REFERENCES interface(repid)
               ON DELETE CASCADE,
    CONSTRAINT PK_interfaceContract PRIMARY KEY (contract, interface)
  );

  CREATE TABLE IF NOT EXISTS providerContract (
    contract TEXT NOT NULL
             REFERENCES contract(name)
             ON DELETE CASCADE,
    provider TEXT NOT NULL
             REFERENCES provider(name)
             ON DELETE CASCADE,
    CONSTRAINT PK_providerContract PRIMARY KEY (contract, provider)
  );

  CREATE TABLE IF NOT EXISTS integrationContract (
    contract TEXT NOT NULL
             REFERENCES contract(name)
             ON DELETE CASCADE,
    integration INTEGER NOT NULL
             REFERENCES integration(id)
             ON DELETE CASCADE,
    CONSTRAINT PK_integrationContract PRIMARY KEY (contract, integration)
  );
]]

local actions = {--[[
  -- INSERT
  { name = "addCategory",
    values = { "id", "name" } },
  { name="addEntity",
    values = { "id", "name", "category" } },
  { name="addInterface",
    values = { "repid" } },
  { name="addEntityInterface",
    values = { "entity", "interface" } },
  { name="addOffer",
    values = { "id", "service_ref", "entity", "login", "timestamp",
	       "day", "month", "year", "hour", "minute",
	       "second", "component_name", "component_major_version",
	       "component_minor_version", "component_patch_version",
	       "component_platform_spec" } },
  { name="addPropertyOffer",
    values = { "name", "value", "offer" } },
  { name="addPropertyOfferRegistryObserver",
    values = { "name", "value", "offer_registry_observer" } },
  { name="addFacet",
    values = { "name", "interface_name", "offer" } },
  { name="addOfferObserver",
    values = { "id", "login", "observer", "offer" } },
  { name="addOfferRegistryObserver",
    values = { "id", "login", "observer" } },
  { name="addSettings",
    values = { "key", "value" } },
  { name="addLogin",
    values = { "id", "entity", "encodedKey" } },
  { name="addLoginObserver",
    values = { "id", "ior", "login" } },
  { name="addWatchedLogin",
    values = { "login_observer", "login" } },
  { name="addCertificate",
    values = { "certificate", "entity" } },

  -- DELETE
  { name="delCategory",
    where = { "id" } },
  { name="delEntity",
    where = { "id" } },
  { name="delEntityInterface",
    where = { "entity", "interface" } },
  { name="delInterface",
    where = { "repid" } },
  { name="delOffer",
    where = { "id" } },
  { name="delPropertyOffer",
    where = { "offer" } },
  { name="delFacet",
    where = { "offer" } },
  { name="delOfferObserver",
    where = { "id" } },
  { name="delOfferRegistryObserver",
    where = { "id" } },
  { name="delPropertyOfferRegistryObserver",
    where = { "offer_registry_observer" } },
  { name="delLogin",
    where = { "id" } },
  { name="delLoginObserver",
    where = { "id" } },
  { name="delWatchedLogin",
    where = { "login_observer", "login" } },
  { name="delCertificate",
    where = { "entity" } },

  -- UPDATE
  { name="setCategory",
    set="name",
    where="id" },
  { name="setEntity",
    set="name",
    where="id" },
  { name="setCertificate",
    set="certificate",
    where="entity" },

  -- SELECT
  { name="getCategory",
    select = { "id", "name" } },
  { name="getCertificate",
    select = { "entity, certificate" } },
  { name="getEntity",
    select = { "id", "name", "category" }, 
    from = { "entity" } },
  { name="getEntityById",
    select = { "id" }, 
    from = { "entity" },
    where = { "id" } },
  { name="getEntityWithCerts",
    select = { "entity" }, 
    from = { "certificate" } },
  { name="getInterface",
    select = { "repid" },
    from = { "interface" } },
  { name="getAuthorizedInterface",
    select = { "interface.repid" },
    from = { "entityInterface", "interface" },
    where_hc = { "interface.repid = entityInterface.interface" },
    where = { "entityInterface.entity" } },
  { name="getOffer",
    select = { "*" },
    from = { "offer" } },
  { name="getPropertyOffer",
    select = { "*" },
    from = { "propertyOffer" },
    where = { "offer" } },
  { name="getFacet",
    select = { "*" },
    from = { "facet" },
    where = { "offer" } },
  { name="getOfferObserver",
    select = { "*" },
    from = { "offerObserver" },
    where = { "offer" } },
  { name="getOfferRegistryObserver",
    select = { "*" },
    from = { "offerRegistryObserver" },
  },
  { name="getPropertyOfferRegistryObserver",
    select = { "*" },
    from = { "propertyOfferRegistryObserver" },
    where = { "offer_registry_observer" },
  },
  { name="getSettings",
    select = { "value" },
    from = { "settings" },
    where = { "key" }
  },
  { name="getLogin",
    select = { "*" },
    from = { "login" }
  },
  { name="getLoginObserver",
    select = { "*" },
    from = { "loginObserver" }
  },
  { name="getWatchedLoginByObserver",
    select = { "login" },
    from = { "watchedLogin" },
    where = { "login_observer" },
  },
  { name="getAuthorizedInterfaces",
    select = { "interface.repid" },
    from = { "entityInterface", "interface" },
    where_hc = { "interface.repid = entityInterface.interface" },
    where = { "entityInterface.entity" },
  },
]]
}


local function quote(sql)
  return sql and string.gsub(sql, '%s+', ' ')
end

local function herror(code, sql, errmsg)
  if code and code ~= lsqlite.OK then
    return nil, msg.SqliteError:tag{code=tostring(code), sql=quote(sql), error=errmsg}
  end
  return true
end

local function iClause(sql, clause, entries, sep, suf)
  if not entries then
    return sql
  end
  if sql then
    sql = sql.." "
  else
    sql = ""
  end
  if not string.find(sql, clause) then 
     sql = sql..clause.." "
  else
     sql = sql.." AND "
  end
  for i, col in ipairs(entries) do
    if i > 1 then sql = sql..sep.." " end
    sql = sql..col
    if suf then sql = sql.." "..suf.." " end
  end
  return sql
end

local function buildSQL(action)
  local name = action.name
  local verb = string.sub(name, 1, 3)
  local sql
  local stable = string.lower(string.sub(name, 4, 4))
     ..string.sub(name, 5, -1)
  if "add" == verb then
    sql = "INSERT INTO "..stable.." ("
    local values = action.values
    sql = sql..table.concat(values, ",")
    sql = sql..") VALUES ("
    sql = sql..string.rep("?", #values, ",")
    sql = sql..")"
  elseif "del" == verb then
    sql = "DELETE FROM "..stable.." "
    sql = iClause(sql, "WHERE", action.where, "AND", "= ?") 
  elseif "set" == verb then
    local stable = action.table or stable
    sql = "UPDATE "..stable.. " "
    sql = sql.."SET "..action.set.. " = ? "
    sql = sql.."WHERE "..action.where.." = ?"
  elseif "get" == verb then
    sql = iClause(nil, "SELECT", action.select, ",")
    local from = action.from
    if from then 
      sql = iClause(sql, "FROM", action.from, ",")
    else
      sql = sql.." FROM "..stable
    end
    sql = iClause(sql, "WHERE", action.where, "AND", "= ?") 
    sql = iClause(sql, "WHERE", action.where_hc, "AND") 
  end
  return sql
end

local stmts = {}

function Database:__init()
  local conn = self.conn
  self:aexec(SQL_UPDATE_VERSION)
  self:aexec("PRAGMA foreign_keys=ON;")
  self:aexec("BEGIN;")
  self:aexec(SQL_CREATE_TABLES)
  local pstmts = {}
  for _, action in ipairs(actions) do
    local sql = buildSQL(action)
    local res, errcode = conn:prepare(sql)
    if not res then 
      assert(herror(errcode, quote(sql)))
    end
    local key = action.name
    pstmts[key] = res
    stmts[key] = sql
  end
  self:aexec("COMMIT;")
  self.pstmts = pstmts
end

-- assert conn:exec
function Database:aexec(sql)
  assert(self:exec(sql))
end

-- raw conn:exec
function Database:exec(sql, callback)
  local gsql = quote(sql)
  local res, errmsg = herror(self.conn:exec(sql, callback), gsql, self.conn:errmsg())
  if not res then
    return nil, errmsg
  end
  log:database(msg.SqlStatement:tag{sql=gsql})
  return true
end

-- prepare statements
function Database:pexec(action, ...)
  local pstmt = self.pstmts[action]
  local gsql = quote(stmts[action])
  local res, errmsg = herror(pstmt:bind_values(...), gsql)
  if not res then
    return nil, errmsg
  end
  log:database(msg.SqlPrepareStatement:tag{sql=gsql, values="{"..table.concat({...}, ", ").."}"})
  local errcode = pstmt:step()
  if errcode == lsqlite.DONE then
    pstmt:reset()
    return true, errcode
  elseif errcode == lsqlite.ROW then
    return true, errcode
  end
  return nil, herror(errcode, gsql, self.conn:errmsg())
end

local module = {}

function module.checkversion(conn)
  local self = {conn = conn}
  local version = nil
  local res, errmsg =
    Database.exec(self, SQL_QUERY_VERSION, function(_, _, values, _)
      version = tonumber(values[1])
      return 0
    end)
  if not res then
    return nil, errmsg
  end
  if not version or (version > 0 and version ~= DB_VERSION) then
    return nil, msg.SchemaUserVersionMismatch:tag{current=version, expected=DB_VERSION}
  end
  return version
end

function module.open(path)
  local conn, errcode, errmsg = lsqlite.open(path)
  if not conn then return herror(errcode, nil, errmsg) end
  local version, errmsg = module.checkversion(conn)
  if not version then return nil, errmsg end
  log:database(msg.SchemaUserVersionIsCompatible:tag{version=version})
  return Database{ conn = conn }
end

return module
