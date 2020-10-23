local LockSession = require(script.LockSession)
local RetryLayer = require(script.Parent.RetryLayer)

local AccessLayer = {}

function AccessLayer.acquireLockSession(collection, key)
	local lockSession = LockSession.new(collection, key)

	return lockSession:lock()
end

function AccessLayer.readWithoutLock(collection, key)
	local value = RetryLayer.read(collection, key) or {}

	return value.data
end

return AccessLayer