# OpenBus Governance Extension

## Generate RSA keypair to authenticate in OpenBus

**You must have the OpenSSL 1.0.0 or greater to proceed next steps.**

1. Create a 2048 bit RSA private key:
```
openssl genrsa 2048 > tmp.key
```
1. Encapsulate the private key using PKCS8 with no encryption (OpenBus SDK Lua demands this):
```
openssl pkcs8 -topk8 -in tmp.key -inform DER -out governance.key -outform DER
```
1. Generate a public key encoded as X509 certificate:
```
openssl req -new -x509 -key governance.key -keyform DER -out governance.crt -outform DER
```
1. Remove the temporary RSA key file:
```
rm -f tmp.key
```

## Configuring the OpenBus to allow authentication using the new keypair

**In order to execute these steps you must have the OpenBus already running.**

1. Use the [BusAdmin utility](https://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/Manual+do+BusAdmin+2.1.0) or [BusExplorer utility](https://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/Core) to fullfil the governance data as following.
1. Define an entity name to use in service authentications, by default use `GovernanceExtensionService`.
1. Associate the `governance.crt` (created in previous section) to this new entity name.
1. Add all the following interfaces:
```
IDL:tecgraf/openbus/services/governance/v1_0/ContractRegistry:1.0
IDL:tecgraf/openbus/services/governance/v1_0/ConsumerRegistry:1.0
IDL:tecgraf/openbus/services/governance/v1_0/ProviderRegistry:1.0
IDL:tecgraf/openbus/services/governance/v1_0/IntegrationRegistry:1.0
```
1. Grant authorizations for these interfaces to the service entity name that you picked.

Now the service is granted to offer that interfaces in an OpenBus instance. See [test/service.adm](test/service.adm) to alternate way to fullfil this using `busadmin` console and [busadmdesc.lua](https://git.tecgraf.puc-rio.br/openbus/openbus-core/blob/master/lua/openbus/core/admin/scripts/busadmdesc.lua) script.

## Running the service

**In order to execute the service you must have the OpenBus already running.**

1. Download [OpenBus SDK Lua](http://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/SDK)
1. Create a directory and extract that package on it, example: `/tmp/sdklua`
1. Clone this repository somewhere, example: `git clone http://git.tecgraf.puc-rio.br/openbus/openbus-governance-extension.git /tmp/governance`
1. Execute the script [etc/runservice-template.sh](etc/runservice-template.sh) overriding `OPENBUS_SDKLUA_HOME` system variable like this:
```
export OPENBUS_SDKLUA_HOME=/tmp/sdklua
cd /tmp/governance
bash etc/runservice-template.sh
```
1. Check if you got a message (at stdout or logfile) like this:
```
13/04/2017 21:24:56 [uptime]    Governance Extension Service 1.0.0 started successfully
```

Default configuration will use OpenBus at `localhost:2089` and it'll register a service as `GovernanceExtensionService` (default service name declared in [idl/governance-extension.idl](idl/governance-extension.idl))

### Changing execution configuration

1. See default properties at [config/governance.cfg](config/governance.cfg)
1. Put something different on it and try execute it again (`runservice-template.sh` uses this configuration file by default)

## Running basic tests

**In order to execute the tests you must have the OpenBus already running.**

1. Download [OpenBus SDK Lua](http://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/SDK)
1. Create a directory and extract that package on it, example: `/tmp/sdklua`
1. Clone this repository somewhere, example: `git clone http://git.tecgraf.puc-rio.br/openbus/openbus-governance-extension.git /tmp/governance`
1. Execute [test/runtests.sh](test/runtests.sh) and [test/rundbtest.sh](test/rundbtest.sh) from your clone directory overriding `OPENBUS_SDKLUA_HOME` and `OPENBUS_IDLPATH` system variables like this:
```
export OPENBUS_SDKLUA_HOME=/tmp/sdklua
export OPENBUS_IDLPATH=../
cd /tmp/governance/test
bash runtests.sh RELEASE
bash rundbtest.sh test.db
```

It'll use a OpenBus instance at `localhost:2089` and it'll search for `GovernanceExtensionService` (default service name declared in [idl/governance-extension.idl](idl/governance-extension.idl))


You'll get a report about the test completion like this:
```
OpenBus Governance Extension Suite ... 
  OpenBus Governance Extension Suite.ContractRegistry ... 
    OpenBus Governance Extension Suite.ContractRegistry.setup ... OK (2.00 sec.)
    OpenBus Governance Extension Suite.ContractRegistry ... 
      OpenBus Governance Extension Suite.ContractRegistry.AddContract ... OK (0.00 sec.)
    OK (0.00 sec.)
    OpenBus Governance Extension Suite.ContractRegistry.teardown ... OK (0.00 sec.)
  OK (2.00 sec.)
OK (2.00 sec.)
Success Rate: 100% (3 of 3 executions)
```

### Changing test configuration

1. Create a file `test.properties` at the same directory where you're executing the tests
1. Put on there your specific configuration, check [test/openbus/test/configs.lua](test/openbus/test/configs.lua) for more details. Example:
```
bus.host.name = localhost
bus.host.port = 6669
user.entity.name = chuck
user.password = norris
```

These configurations depend how the OpenBus instance is configured (password validators, authentication domains, etc).

## Shutting down the service nicely

1. Execute [test/shutdown.lua](test/shutdown.lua) using the same `governance.cfg` used to execute the service:
```
cd /tmp/governance
/tmp/sdklua/bin/busconsole test/shutdown.lua config/governance.cfg
```

In this example, shutdown script will use the same entity and same private key used to execute the service itself. 
The service only accepts calls from the same entity name or from the special `OpenBus` entity (some cases the OpenBus administrator could use this special entity to shut down services).

