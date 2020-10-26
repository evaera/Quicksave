local LockSession = require(script.LockSession)
local MigrationLayer = require(script.Parent.MigrationLayer)

local AccessLayer = {}

function AccessLayer.acquireLockSession(collection, key, migrations)
	local lockSession = LockSession.new(collection, key, migrations)

	return lockSession:lock()
end

function AccessLayer.readWithoutLock(collection, key, migrations)
	return MigrationLayer.read(collection, key, migrations)
end

return AccessLayer