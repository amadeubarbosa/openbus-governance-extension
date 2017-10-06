#!/bin/bash

export LUA_PATH="$(pwd)/lua/?.lua;$(pwd)/lua/?.luad;"

$OPENBUS_SDKLUA_HOME/bin/busconsole -e "require('openbus.services.governance.main')(table.unpack(arg))" $@ 
