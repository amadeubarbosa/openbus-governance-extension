#!/bin/bash

export LUA_PATH="$(pwd)/lua/?.lua;$(pwd)/lua/?.luad;"

SERVICE="lua/openbus/services/governance/main.lua"

$OPENBUS_SDKLUA_HOME/bin/busconsole $SERVICE -configs config/governance.cfg
