#!/bin/bash

mode=$1

if [[ "$mode" == "" ]]; then
	mode=RELEASE
elif [[ "$mode" != "RELEASE" && "$mode" != "DEBUG" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG>"
	exit 1
fi
function genkey {
	busssl="env LD_LIBRARY_PATH=$OPENBUS_OPENSSL_HOME/lib ${OPENBUS_OPENSSL_HOME}/bin/openssl"
        if [[ ! -e $1.key ]]; then
                export DYLD_LIBRARY_PATH="${OPENBUS_OPENSSL_HOME}/lib:${DYLD_LIBRARY_PATH}"
                $busssl genrsa -out $1.tmp 2048 > /dev/null 2> /dev/null
                $busssl pkcs8 -topk8 -nocrypt -in $1.tmp \
                  -out $1.key -outform DER
                rm -f $1.tmp > /dev/null 2> /dev/null
                echo "BR
Rio de Janeiro
Rio de Janeiro
PUC-Rio
Tecgraf
${1:0:64}
openbus@tecgraf.puc-rio.br
" | $busssl req -config ${OPENBUS_OPENSSL_HOME}/openssl/openssl.cnf -new -x509 \
                  -key $1.key -keyform DER \
                  -out $1.crt -outform DER > /dev/null 2> /dev/null
        fi
}

genkey $OPENBUS_TEMP/governance

busport=66699
leasetime=120

export OPENBUS_TESTCFG=$OPENBUS_TEMP/test.properties
echo "bus.host.port=$busport"         > $OPENBUS_TESTCFG
echo "login.lease.time=$leasetime"   >> $OPENBUS_TESTCFG
#echo "openbus.test.verbose=yes"     >> $OPENBUS_TESTCFG

runbus="source ${OPENBUS_CORE_TEST}/runbus.sh $mode"
runadmin="source ${OPENBUS_CORE_TEST}/runadmin.sh $mode"
runservice="source ${OPENBUS_GOVERNANCE_TEST}/runservice.sh $mode"
runconsole="source ${OPENBUS_SDKLUA_TEST}/runconsole.sh $mode"

$runbus BUS01 $busport

cd $OPENBUS_TEMP
echo "Setting up bus governance data..."
$runadmin localhost $busport --script=${OPENBUS_GOVERNANCE_TEST}/service.adm
cd -

echo "Running basic database tests..."
source rundbtests.sh $OPENBUS_TEMP/automated.db
rm -f $OPENBUS_TEMP/automated.db

echo "Executing the service itself..."
$runservice $busport

echo "Running service tests..."
source runtests.sh $mode

echo "Terminating service..."
source runconsole ${OPENBUS_GOVERNANCE_TEST}/shutdown.lua -configs $GOVERNANCE_CONFIG

echo "Cleaning up bus governance data..."
$runadmin localhost $busport --undo-script=${OPENBUS_GOVERNANCE_TEST}/service.adm

