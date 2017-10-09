#!/bin/bash

mode=$1

if [[ "$mode" == "" ]]; then
	mode=RELEASE
elif [[ "$mode" != "RELEASE" && "$mode" != "DEBUG" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG>"
	exit 1
fi
function genkey {
	busssl="env DYLD_LIBRARY_PATH=${OPENBUS_OPENSSL_HOME}/lib LD_LIBRARY_PATH=$OPENBUS_OPENSSL_HOME/lib ${OPENBUS_OPENSSL_HOME}/bin/openssl"
        if [[ ! -e $1.key ]]; then
                $busssl genrsa -out $1.tmp 2048 > /dev/null 2> /dev/null || exit 1
                $busssl pkcs8 -topk8 -nocrypt -in $1.tmp \
                  -out $1.key -outform DER || exit 1
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
                  -out $1.crt -outform DER > /dev/null 2> /dev/null || exit 1
        fi
}

genkey $OPENBUS_TEMP/governance

export OPENBUS_TESTCFG=$OPENBUS_TEMP/test.properties
echo "bus.host.port=63699"         > $OPENBUS_TESTCFG
echo "login.lease.time=120"       >> $OPENBUS_TESTCFG
#echo "openbus.test.verbose=yes"  >> $OPENBUS_TESTCFG

runbus="source ${OPENBUS_CORE_TEST}/runbus.sh $mode"
runadmin="source ${OPENBUS_CORE_TEST}/runadmin.sh $mode"
runservice="source ${OPENBUS_GOVERNANCE_TEST}/runservice.sh $mode"
runconsole="source ${OPENBUS_SDKLUA_TEST}/runconsole.sh $mode"

bushost=`$runconsole -l openbus.test.configs -e 'print(bushost)'`
busport=`$runconsole -l openbus.test.configs -e 'print(busport)'`

$runbus BUS01 $busport || exit 1

cd $OPENBUS_TEMP
echo "Setting up bus governance data..."
$runadmin $bushost $busport --script=${OPENBUS_GOVERNANCE_TEST}/service.adm || exit 1
cd -

echo "Running basic database tests..."
source rundbtest.sh $OPENBUS_TEMP/automated.db || exit 1
rm -f $OPENBUS_TEMP/automated.db

echo "Executing the service itself..."
$runservice $bushost $busport || exit 1

echo "Running service tests..."
source runtests.sh || exit 1

echo "Terminating service..."
$runconsole ${OPENBUS_GOVERNANCE_TEST}/shutdown.lua $GOVERNANCE_CONFIG

echo "Cleaning up bus governance data..."
$runadmin $bushost $busport --undo-script=${OPENBUS_GOVERNANCE_TEST}/service.adm || exit 1

