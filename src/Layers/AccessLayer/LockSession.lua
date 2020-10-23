local RetryLayer = require(script.Parent.Parent.RetryLayer)
local Error = require(script.Parent.Parent.Parent.Error)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)

local HttpService = game:GetService("HttpService")

local LOCK_EXPIRE = 60 * 5

local function consistencyError()
	return Error.new({
		kind = Error.Kind.LockConsistencyViolation,
		error = "Lock was changed after we acquired it. Aborting operation."
	})
end

local LockSession = {}
LockSession.__index = LockSession

function LockSession.new(collection, key)
	return setmetatable({
		collection = collection;
		key = key;
		_lockId = HttpService:GenerateGUID();
		_locked = false;
		_value = nil;
		_lastWrite = -1;
		_pendingData = nil;
		_pendingPromise = nil;
	}, LockSession)
end

function LockSession:lock()
	if self._locked then
		error("Attempt to lock when already locked")
	end

	local success

	self._value = RetryLayer.update(self.collection, self.key, function(value)
		value = value or {
			createdAt = os.time();
			updatedAt = os.time();
		}

		if type(value.lockedAt) == "number" and os.time() - value.lockedAt < LOCK_EXPIRE then
			success = false
			return nil
		end

		value.lockId = self._lockId
		value.lockedAt = os.time()

		success = true

		return value
	end)


	if success and self._value.lockId == self._lockId then
		self._locked = true
		self._lastWrite = os.clock()
		return self
	end

	error(Error.new({
		kind = Error.Kind.CouldNotAcquireLock,
		error = "Could not acquire lock"
	}))
end

function LockSession:_checkConsistency(value)
	return value.lockId and value.lockId  == self._lockId
end

function LockSession:_ensureLocked()
	if not self._locked then
		error("Attempt to access LockSession without a lock")
	end
end

function LockSession:write(data)
	self:_ensureLocked()

	if os.clock() - self._lastWrite < 6 then
		self._pendingData = data

		if not self._pendingPromise then
			self._pendingPromise = Promise.delay(os.clock() - self._lastWrite):andThen(function()
				self._pendingData = nil
				self._pendingPromise = nil
				self:write(self._pendingData)
			end)
		end

		return self._pendingPromise:expect()
	end

	local errorVal
	self._value = RetryLayer.update(self.collection, self.key, function(value)
		if not self:_checkConsistency(value) then
			errorVal = consistencyError()
			return nil
		end

		value.updatedAt = os.time()
		value.lockedAt = os.time()
		value.data = data

		return value
	end)

	if errorVal then
		error(errorVal)
	end

	self._lastWrite = os.clock()
end

function LockSession:read()
	self:_ensureLocked()

	return self._value.data
end

function LockSession:getUpdatedTimestamp()
	self:_ensureLocked()
	return self._value.updatedAt
end

function LockSession:getCreatedTimestamp()
	self:_ensureLocked()
	return self._value.createdAt
end

function LockSession:unlock()
	self._locked = false
	self._value = nil

	RetryLayer.update(self.collection, self.key, function(value)
		if not self:_checkConsistency(value) then
			return nil
		end

		value.lockedAt = nil
		value.lockId = nil

		return value
	end)
end

return LockSession