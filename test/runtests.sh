#!/bin/bash

busconsole="${OPENBUS_SDKLUA_HOME}/bin/busconsole"

TEST_NAME='OpenBus Governance Extension Suite'

TEST_PRELUDE='package.path=package.path..";./lua/?.lua;./lua/?.luad;./test/?.lua;"'

TEST_RUNNER="package.path=package.path..';./?.lua'
local suite = require('openbus.test.Suite')
local Runner = require('loop.test.Results')
local path = {}
for name in string.gmatch('$2', '[^.]+') do
	path[#path+1] = name
end
local runner = Runner{
	reporter = require('loop.test.Reporter'),
	path = (#path > 0) and path or nil,
}
if not runner('$TEST_NAME', suite) then os.exit(1) end"

$busconsole -e "$TEST_PRELUDE" -e "$TEST_RUNNER" $@ || exit $?
