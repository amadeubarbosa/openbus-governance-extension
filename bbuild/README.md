## Dependências

[lua](https://git.tecgraf.puc-rio.br/openbus-3rd-party/lua/tree/master)

[loop](https://git.tecgraf.puc-rio.br/engdist/loop/tree/master)

[oil](https://git.tecgraf.puc-rio.br/engdist/oil/tree/master)

[lce](https://git.tecgraf.puc-rio.br/engdist/lce/tree/master)

[libuuid](http://webserver2.tecgraf.puc-rio.br/ftp_pub/openbus/repository/libuuid-1.0.3.tar.gz) (Somente Unix)

[luuid](https://git.tecgraf.puc-rio.br/openbus-3rd-party/luuid/tree/1.0)

[luascs](https://git.tecgraf.puc-rio.br/scs/scs-core-lua/tree/SCS_CORE_LUA_v1_02_03_2012_05_10)

[scs-idl](https://git.tecgraf.puc-rio.br/scs/scs-core-idl/tree/SCS_CORE_IDL_v1_02_2010_09_21)

[luafilesystem](https://git.tecgraf.puc-rio.br/openbus-3rd-party/luafilesystem/tree/1.4.2)

[luasec](https://git.tecgraf.puc-rio.br/openbus-3rd-party/luasec/tree/master)

[luasocket](https://git.tecgraf.puc-rio.br/openbus-3rd-party/luasocket/tree/2.0.2)

[luastruct](https://git.tecgraf.puc-rio.br/openbus-3rd-party/struct/tree/1.2)

[luavararg](https://git.tecgraf.puc-rio.br/openbus-3rd-party/vararg/tree/1.1)

[luaopenbus](https://git.tecgraf.puc-rio.br/openbus/openbus-sdk-lua/tree/02_00_01)

[luasqlite3](https://git.tecgraf.puc-rio.br/openbus-3rd-party/luasqlite3/tree/master)

[openbus-idl](https://git.tecgraf.puc-rio.br/openbus/openbus-idl/tree/02_00)

[openbus-lib-idl](https://git.tecgraf.puc-rio.br/openbus/openbus-sdk-idl-lib/tree/02_00)

[openbus-legacy-idl](https://git.tecgraf.puc-rio.br/openbus/openbus-idl/tree/OB_IDL_v1_05_2010_05_13)

[openssl-1.1.0o](http://webserver2.tecgraf.puc-rio.br/ftp_pub/openbus/repository/openssl-1.0.0o.tar.gz)

[openssl.jam](https://git.tecgraf.puc-rio.br/boost-build/openssl/tree/master)

[uuid.jam](https://git.tecgraf.puc-rio.br/boost-build/uuid/tree/master)  (Somente Unix)

[boost-build](http://webserver2.tecgraf.puc-rio.br/ftp_pub/openbus/repository/boost-build-2014-10_tecgraf_28112014snapshot.tgz)

[sqlite](https://git.tecgraf.puc-rio.br/openbus-3rd-party/sqlite/tree/master)

## Build
0. É necessário ter a ferramenta Boost Build e as bibliotecas OpenSSL e UUID (i) instaladas. [Instalação da Boost Build](https://jira.tecgraf.puc-rio.br/confluence/x/vYq_B), [Instalação da OpenSSL 1.0.0] (https://jira.tecgraf.puc-rio.br/confluence/x/wYq_B) e [Instalação da UUID 1.0.3] (https://jira.tecgraf.puc-rio.br/confluence/x/1AXXB)
1. Escolher um diretório raiz para o build (`$BUILD`) e disponibilizar
cada uma das dependências como um subdiretório com o nome da
dependência conforme listado acima.Por exemplo:
`$BUILD/lua`,`$BUILD/loop`, `$BUILD/oil` e assim por diante.
2. Disparar o Boost Build em `$BUILD/openbus-governance-extension/bbuild` informando o local 
da instalação da OpenSSL e UUID (i):

(i) Somente para ambientes Unix. 

### Unix

```bash
cd $BUILD/openbus-governance-extension/bbuild
$INSTALL/boost-build/bin/b2 warnings=off \
  -sOPENSSL_INSTALL=$OPENSSL_INSTALL \
  -sUUID_INSTALL=$UUID_INSTALL
```

### Windows

```
cd %BUILD%\openbus-governance-extension\bbuild
%INSTALL%\boost-build\bin\b2 warnings=off ^
  -sOPENSSL_INSTALL=%OPENSSL_INSTALL%
```

Os locais de instalação das bibliotecas OpenSSL e UUID podem ser
informados através das variáveis `OPENSSL_INSTALL` e `UUID_INSTALL`.
Como alternativa, os diretórios `include` e `lib`
podem ser informados de forma separada através das variáveis
`OPENSSL_INC`, `OPENSSL_LIB`, `UUID_INC` e `UUID_LIB`.

As outras dependências são buscadas automaticamente no diretório pai
do pacote `openbus-governance-extension`. Para cada dependência descrita na tabela
acima, o Boost Build procura um diretório com o nome da dependência
que contenha os artefatos para compilação. É possível informar
caminhos customizados para cada uma das dependências através das
seguintes variáveis de ambiente:

`LUA`

`LOOP`

`OIL`

`LCE`

`LUUID`

`LUALDAP`

`LUAFILESYSTEM`

`LUASEC`

`LUASOCKET`

`LUASQLITE3`

`LUASTRUCT`

`LUAVARARG`

`SCSLUA`

`SCS_IDL`

`OPENBUSLUA`

`OPENBUS_IDL`

`OPENBUS_LEGACY_IDL`

`OPENBUS_LIB_IDL`

`OPENSSL_JAM`

`UUID_JAM`

`SQLITE`

As variáveis acima podem ser passadas para o Boost Build através do argumento `-sVAR=value`, por exemplo, `-sLUA=/path/to/luasrc`.

Os produtos do build são disponibilizados em 
`$BUILD\openbus-governance-extension\bbuild\install`.
