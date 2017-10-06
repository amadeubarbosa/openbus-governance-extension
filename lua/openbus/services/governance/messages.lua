local msg = require "openbus.util.messages"

msg.ServiceVersion = "1.0."..OPENBUS_CODEREV

msg.CopyrightNotice = "OpenBus Governance Extension Service "..
   msg.ServiceVersion.."  Copyright (C) 2017 Tecgraf, PUC-Rio"

msg.ServiceSuccessfullyStarted = "Governance Extension Service "..
   msg.ServiceVersion.." started successfully"

return msg
