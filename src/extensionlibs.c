#include "extralibraries.h"

#include <lua.h>
#include <lauxlib.h>

#include "governanceextension.h"


const char const* OPENBUS_MAIN = "openbus.services.governance.main";

void luapreload_extralibraries(lua_State *L)
{
  luapreload_governanceextension(L);
}
