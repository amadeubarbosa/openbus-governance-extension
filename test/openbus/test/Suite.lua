local Suite = require "loop.test.Suite"

local Cases = {}
for _, name in ipairs{ 
	"ContractRegistry",
	--[["ProviderRegistry",
	"ConsumerRegistry",
	"IntegrationRegistry",]]
} do
	Cases[name] = require ("openbus.test.services.governance."..name)
end

return Suite(Cases)
