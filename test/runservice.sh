#!/bin/bash

mode=$1
bushost=$2
busport=$3

LUA_PATH="${OPENBUS_GOVERNANCE_TEST}/../lua/?.lua;${OPENBUS_GOVERNANCE_TEST}/../lua/?.luad;${OPENBUS_GOVERNANCE_TEST}/?.lua;;"
service="env LUA_PATH=$LUA_PATH ${OPENBUS_GOVERNANCE_HOME}/bin/busextension"

if [[ "$mode" == "DEBUG" ]]; then
	service="$service $mode"
elif [[ "$mode" != "RELEASE" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG> <args>"
	exit 1
fi

export GOVERNANCE_CONFIG=$OPENBUS_TEMP/governance.cfg
echo "bushost = \"$bushost\""                         > $GOVERNANCE_CONFIG
echo "busport = $busport"                            >> $GOVERNANCE_CONFIG
echo "privatekey = \"$OPENBUS_TEMP/governance.key\"" >> $GOVERNANCE_CONFIG
echo "database = \"$OPENBUS_TEMP/governance.db\""    >> $GOVERNANCE_CONFIG
echo "logfile = \"$OPENBUS_TEMP/governance.log\""    >> $GOVERNANCE_CONFIG

$service -configs $GOVERNANCE_CONFIG 2>&1 > $OPENBUS_TEMP/governance.out &
pid="$!"
trap "kill $pid > /dev/null 2>&1" 0

