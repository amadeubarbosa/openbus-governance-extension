#!/bin/bash

export LUA_PATH="./lua/?.lua;./lua/?.luad;"

$OPENBUS_SDKLUA_HOME/bin/busconsole -e "require('openbus.services.governance.main')(table.unpack(arg))" -- $@ 
