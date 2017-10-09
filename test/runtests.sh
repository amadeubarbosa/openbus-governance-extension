#!/bin/bash

mode=$1
restrict=${@:2}

busconsole="${OPENBUS_SDKLUA_HOME}/bin/busconsole"

if [[ "$mode" == "DEBUG" ]]; then
	busconsole="$busconsole DEBUG"
elif [[ "$mode" != "RELEASE" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG> [space separated tests path]"
	exit 1
fi

TEST_NAME='OpenBus Governance Extension Suite'

TEST_PRELUDE='package.path=package.path..";../lua/?.lua;../lua/?.luad"'

TEST_RUNNER="package.path=package.path..';./?.lua;'
local suite = require('openbus.test.Suite')
local Runner = require('loop.test.Results')
local path = {}
for name in string.gmatch('$restrict', '[^.]+') do
	path[#path+1] = name
end
local runner = Runner{
	reporter = require('loop.test.Reporter'),
	path = (#path > 0) and path or nil,
}
if not runner('$TEST_NAME', suite) then os.exit(1) end"

$busconsole -e "$TEST_PRELUDE" -e "$TEST_RUNNER" || exit $?
