#!/bin/bash

BASEPATH=$(dirname $0)
export LUA_PATH="$BASEPATH/../lua/?.lua;;"

$(which busconsole) $BASEPATH/openbus/test/services/governance/Database.lua $@
