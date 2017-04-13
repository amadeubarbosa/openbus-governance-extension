# OpenBus Governance Extension

## Running the service

**In order to execute the service you must have the OpenBus already running.**

1. Download [OpenBus SDK Lua](http://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/SDK)
1. Create a directory and extract that package on it, example: `/tmp/sdklua`
1. Clone this repository somewhere, example: `git clone http://git.tecgraf.puc-rio.br/openbus/openbus-governance-extension.git /tmp/governance`
1. Execute the script `runservice.sh` from your clone directory overriding `OPENBUS_SDKLUA_HOME` system variable like this:
```
cd /tmp/governance
export OPENBUS_SDKLUA_HOME=/tmp/sdklua
bash runservice.sh
```
1. Check if you got a message (at stdout or logfile) like this:
```
13/04/2017 21:24:56 [uptime]    Governance Extension Service 1.0.0.0 started successfully
```

Default configuration will use OpenBus at `localhost:2089` and it'll register a service as `GovernanceExtensionService` (default service name declared in [idl/governance-extension.idl](idl/governance-extension.idl))

### Changing execution configuration

1. See default properties at [config/governance.cfg](config/governance.cfg)
1. Put something different on it and try execute it again (`runservice.sh` is already using this configuration file)

## Running basic tests

**In order to execute the tests you must have the OpenBus already running.**

1. Download [OpenBus SDK Lua](http://jira.tecgraf.puc-rio.br/confluence/display/OPENBUS021/SDK)
1. Create a directory and extract that package on it, example: `/tmp/sdklua`
1. Clone this repository somewhere, example: `git clone http://git.tecgraf.puc-rio.br/openbus/openbus-governance-extension.git /tmp/governance`
1. Execute the script `test/runtests.sh` from your clone directory overriding `OPENBUS_SDKLUA_HOME` system variable like this:
```
cd /tmp/governance
export OPENBUS_SDKLUA_HOME=/tmp/sdklua
bash test/runtests.sh
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
