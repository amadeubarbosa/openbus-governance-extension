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
    interface  TEXT NOT NULL,
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

local actions = {
  -- INSERT
  { name="addContract",
    values = { "name" } },
  { name="addProvider",
    values = { "name", "code", "office", "support", "manager", "busquery" } },
  { name="addConsumer",
    values = { "name", "code", "office", "support", "manager", "busquery" } },
  { name="addIntegration",
    values = { "consumer", "provider", "activated" } },
  { name="addInterfaceContract",
    values = { "contract", "interface" } },
  { name="addProviderContract",
    values = { "contract", "provider" } },
  { name="addIntegrationContract",
    values = { "contract", "integration" } },

  -- DELETE
  { name="delContract",
    where = { "name" } },
  { name="delProvider",
    where = { "name" } },
  { name="delConsumer",
    where = { "name" } },
  { name="delIntegration",
    where = { "id" } },
  { name="delInterfaceContract",
    where = { "contract", "interface" } },
  { name="delProviderContract",
    where = { "contract", "provider" } },
  { name="delIntegrationContract",
    where = { "contract", "integration" } },

  -- UPDATE
  --- PROVIDER
  { name="setProviderName",
    table="provider",
    set="name",
    where="name" },
  { name="setProviderCode",
    table="provider",
    set="code",
    where="name" },
  { name="setProviderOffice",
    table="provider",
    set="office",
    where="name" },
  { name="setProviderSupport",
    table="provider",
    set="support",
    where="name" },
  { name="setProviderManager",
    table="provider",
    set="manager",
    where="name" },
  { name="setProviderBusQuery",
    table="provider",
    set="busquery",
    where="name" },
  --- CONSUMER
  { name="setConsumerName",
    table="consumer",
    set="name",
    where="name" },
  { name="setConsumerCode",
    table="consumer",
    set="code",
    where="name" },
  { name="setConsumerOffice",
    table="consumer",
    set="office",
    where="name" },
  { name="setConsumerSupport",
    table="consumer",
    set="support",
    where="name" },
  { name="setConsumerManager",
    table="consumer",
    set="manager",
    where="name" },
  { name="setConsumerBusQuery",
    table="consumer",
    set="busquery",
    where="name" },
  --- INTEGRATION
  { name="setIntegrationConsumer",
    table="integration",
    set="consumer",
    where="id" },
  { name="setIntegrationProvider",
    table="integration",
    set="provider",
    where="id" },
  { name="setIntegrationActivated",
    table="integration",
    set="activated",
    where="id" },

  -- SELECT
  { name="getContract",
    select = { "name" } },
  { name="getProvider",
    select = { "*" } },
  { name="getConsumer",
    select = { "*" } },
  { name="getIntegration",
    select = { "*" } },
  { name="getInterfaceContract",
    select = { "contract", "interface" },
    where = { "contract" } },
  { name="getProviderContract",
    select = { "provider", "contract" },
    where = { "provider" } },
  { name="getIntegrationContract",
    select = { "integration", "contract" },
    where = { "integration" } },
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
