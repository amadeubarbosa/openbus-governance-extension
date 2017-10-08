#!/bin/bash

export LUA_PATH="../lua/?.lua;;"

${OPENBUS_SDKLUA_HOME}/bin/busconsole openbus/test/services/governance/Database.lua $@
