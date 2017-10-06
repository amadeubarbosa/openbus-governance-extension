#!/bin/bash

BASEPATH=$(dirname $0)
export LUA_PATH="$BASEPATH/../lua/?.lua;;"

${OPENBUS_SDKLUA_HOME}/bin/busconsole $BASEPATH/openbus/test/services/governance/Database.lua $@
