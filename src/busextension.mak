PROJNAME= busextension
APPNAME= $(PROJNAME)
CODEREV?= $(shell git rev-parse --short HEAD)

OBJROOT = obj/$(PROJNAME)

SRC= \
  launcher.c \
  extensionlibs.c \
  $(PRELOAD_DIR)/governanceextension.c

IDLDIR= ../idl
IDLSRC= \
  $(IDLDIR)/governance-extension.idl

LUADIR= ../lua
LUASRC= \
  $(LUADIR)/openbus/services/governance/Database.lua \
  $(LUADIR)/openbus/services/governance/idl.lua \
  $(LUADIR)/openbus/services/governance/Listener.lua \
  $(LUADIR)/openbus/services/governance/string.lua \
  $(LUADIR)/openbus/services/governance/ContractRegistry.lua \
  $(LUADIR)/openbus/services/governance/ProviderRegistry.lua \
  $(LUADIR)/openbus/services/governance/main.lua \
  $(LUADIR)/openbus/services/governance/parsed.lua \
  $(LUADIR)/openbus/services/governance/messages.lua \
  $(LUADIR)/openbus/services/governance/IntegrationRegistry.lua \
  $(LUADIR)/openbus/services/governance/ConsumerRegistry.lua

include ${OIL_HOME}/openbus/base.mak

DEFINES= \
  OPENBUS_PROGNAME=\"$(APPNAME)\" \
  OPENBUS_CODEREV=\"$(CODEREV)\"

LIBS:= \
  luaopenbus \
  luastruct \
  luasocket \
  luatuple \
  loop \
  luacothread \
  luaidl \
  oil \
  luaiconv \
  luavararg \
  lfs \
  luuid \
  lce \
  luasec \
  luascs \
  lsqlite3 \
  sqlite3

INCLUDES+= . $(SRCLUADIR) \
  $(LUASTRUCT_HOME)/src \
  $(LUASOCKET_HOME)/include \
  $(LUATUPLE_HOME)/obj/$(TEC_UNAME) \
  $(LOOP_HOME)/obj/$(TEC_UNAME) \
  $(LUACOTHREAD_HOME)/obj/$(TEC_UNAME) \
  $(LUAIDL_HOME)/obj/$(TEC_UNAME) \
  $(OIL_HOME)/obj/$(TEC_UNAME) \
  $(LUAICONV_HOME)/include \
  $(LUAVARARG_HOME)/src \
  $(LUAFILESYSTEM_HOME)/include \
  $(LUUID_HOME)/include \
  $(LCE_HOME)/include \
  $(LUASEC_HOME)/include \
  $(SCS_LUA_HOME)/obj/$(TEC_UNAME) \
  $(OPENBUS_LUA_HOME)/obj/$(TEC_UNAME) \
  $(OPENBUS_LUA_HOME)/src \
  $(SQLITE_HOME) \
  $(LSQLITE3_HOME)
LDIR+= \
  $(LUASTRUCT_HOME)/lib/$(TEC_UNAME) \
  $(LUASOCKET_HOME)/lib/$(TEC_UNAME) \
  $(LUATUPLE_HOME)/lib/$(TEC_UNAME) \
  $(LOOP_HOME)/lib/$(TEC_UNAME) \
  $(LUACOTHREAD_HOME)/lib/$(TEC_UNAME) \
  $(LUAIDL_HOME)/lib/$(TEC_UNAME) \
  $(OIL_HOME)/lib/$(TEC_UNAME) \
  $(LUAICONV_HOME)/lib/$(TEC_UNAME) \
  $(LUAVARARG_HOME)/lib/$(TEC_UNAME) \
  $(LUAFILESYSTEM_HOME)/lib/$(TEC_UNAME) \
  $(LUUID_HOME)/lib/$(TEC_UNAME) \
  $(LCE_HOME)/lib/$(TEC_UNAME) \
  $(LUASEC_HOME)/lib/$(TEC_UNAME) \
  $(SCS_LUA_HOME)/lib/$(TEC_UNAME) \
  $(OPENBUS_LUA_HOME)/lib/$(TEC_UNAME) \
  $(SQLITE_HOME)/.libs \
  $(LSQLITE3_HOME)/bbuild/install

ifdef USE_LUA51
  INCLUDES+= $(LUACOMPAT52_HOME)/c-api $(LUACOMPAT52_HOME)/obj/$(TEC_UNAME)
  LDIR+= $(LUACOMPAT52_HOME)/lib/$(TEC_UNAME)
  LIBS+= luacompat52 luabit32 luacompat52c
endif

ifeq "$(TEC_SYSNAME)" "Linux"
  LFLAGS = -Wl,-E -lpthread
endif
ifeq "$(TEC_SYSNAME)" "SunOS"
  USE_CC=Yes
  CFLAGS= -g -KPIC -mt -D_REENTRANT
  ifeq ($(TEC_WORDSIZE), TEC_64)
    CFLAGS+= -m64
  endif
  LFLAGS= $(CFLAGS) -xildoff
endif

ifeq ($(findstring $(TEC_SYSNAME), Win32 Win64), )
  ifdef USE_STATIC
    SLIB:= $(foreach libname, $(LIBS) uuid ssl crypto, ${OPENBUS_HOME}/lib/lib$(libname).a)
    ifeq "$(TEC_SYSNAME)" "SunOS"
      LIBS:= rt nsl socket resolv
    else
      LIBS:= 
    endif
  else
    ifeq ($(findstring $(TEC_SYSNAME), MacOS, Darwin), )
      LIBS+= uuid
    endif
  endif
endif

ifneq ($(findstring $(TEC_SYSNAME), MacOS, Darwin), )
  LIBS+= iconv
endif

ifneq ($(findstring $(TEC_SYSNAME), Win32 Win64), )
  APPTYPE= console
  LIBS+= wsock32 rpcrt4
  ifneq ($(findstring dll, $(TEC_UNAME)), ) # USE_DLL
    ifdef DBG
      LIBS+= libeay32MDd ssleay32MDd
    else
      LIBS+= libeay32MD ssleay32MD
    endif
    LDIR+= $(OPENSSL_HOME)/lib/VC
  else
    ifdef DBG
      LIBS+= libeay32MTd ssleay32MTd
    else
      LIBS+= libeay32MT ssleay32MT
    endif
    LDIR+= $(OPENSSL_HOME)/lib/VC/static
  endif
else
  LIBS+= dl
endif

$(LUADIR)/openbus/services/governance/parsed.lua: $(IDL2LUA) $(IDLSRC)
	$(OILBIN) $(IDL2LUA) -o $@ $(IDLSRC)

$(PRELOAD_DIR)/governanceextension.c $(PRELOAD_DIR)/governanceextension.h: $(LUAPRELOADER) $(LUASRC)
	$(LOOPBIN) $(LUAPRELOADER) -l "$(LUADIR)/?.lua" \
                             -d $(PRELOAD_DIR) \
                             -h governanceextension.h \
                             -o governanceextension.c \
                             $(LUASRC)

launcher.c: $(OPENBUS_LUA_HOME)/src/launcher.c
	cp $< $@

extensionlibs.c: $(PRELOAD_DIR)/governanceextension.h
