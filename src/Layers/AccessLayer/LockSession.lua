local MigrationLayer = require(script.Parent.Parent.MigrationLayer)
local Error = require(script.Parent.Parent.Parent.Error)
local Promise = require(script.Parent.Parent.Parent.Parent.Promise)
local getTime = require(script.Parent.Parent.Parent.getTime).getTime

local HttpService = game:GetService("HttpService")

local LOCK_EXPIRE = 60 * 5
local WRITE_MAX_INTERVAL = 7

local function consistencyError()
	return Error.new({
		kind = Error.Kind.LockConsistencyViolation,
		error = "Lock was changed after we acquired it. Aborting operation."
	})
end

local LockSession = {}
LockSession.__index = LockSession

function LockSession.new(collection, key, migrations)
	assert(migrations ~= nil, "migrations is nil")

	return setmetatable({
		collection = collection;
		key = key;
		_lockId = HttpService:GenerateGUID();
		_locked = false;
		_value = nil;
		_lastWrite = -1;
		_pendingData = nil;
		_pendingPromise = nil;
		_pendingClose = false;
		_migrations = migrations;
	}, LockSession)
end

function LockSession:lock()
	if self._locked then
		error("Attempt to lock when already locked")
	end

	local success

	self._value = MigrationLayer.update(self.collection, self.key, function(value)
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
	end, self._migrations)

	if success and self._value.lockId == self._lockId then
		self._locked = true
		self._lastWrite = getTime()
		return self
	end

	error(Error.new({
		kind = Error.Kind.CouldNotAcquireLock,
		error = "Could not acquire lock"
	}))
end

function LockSession:_checkConsistency(value)
	return value.lockId and value.lockId == self._lockId
end

function LockSession:_ensureLocked()
	if not self._locked then
		error("Attempt to access LockSession without a lock")
	end
end

function LockSession:write(data)
	self:_ensureLocked()

	if self._pendingClose then
		error("Attempt to write to a LockSession that is pending to be closed.")
	end

	if data == nil then
		warn("[Debug, remove for release] LockSession:write data is nil!")
	end


	if getTime() - self._lastWrite < WRITE_MAX_INTERVAL then
		warn("Queueing key =", self.collection, self.key)
		self._pendingData = data

		if not self._pendingPromise then
			self._pendingPromise = Promise.delay(WRITE_MAX_INTERVAL - (getTime() - self._lastWrite)):andThen(function()
				self._pendingPromise = nil

				if self._pendingClose then
					self._pendingClose = false
					self:unlock()
				else
					local pendingData = self._pendingData
					self._pendingData = nil
					self:write(pendingData)
				end
			end)
		end

		return self._pendingPromise:expect()
	end

	local errorVal
	self._value = MigrationLayer.update(self.collection, self.key, function(value)
		if not self:_checkConsistency(value) then
			errorVal = consistencyError()
			return nil
		end

		value.updatedAt = os.time()
		value.lockedAt = os.time()
		value.data = data

		return value
	end, self._migrations)

	if errorVal then
		error(errorVal)
	end

	self._lastWrite = getTime()
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

function LockSession:unlockWithFinalData(data)
	self._pendingData = data

	return self:unlock()
end

function LockSession:unlock()
	if getTime() - self._lastWrite < WRITE_MAX_INTERVAL or self._pendingPromise then
		self._pendingClose = true

		if self._pendingPromise == nil then
			self._pendingPromise = Promise.delay(WRITE_MAX_INTERVAL - (getTime() - self._lastWrite)):andThen(function()
				self._pendingPromise = nil
				self:unlock()
			end)
		end

		return self._pendingPromise:expect()
	end

	self._locked = false
	self._value = nil

	MigrationLayer.update(self.collection, self.key, function(value)
		if not self:_checkConsistency(value) then
			return nil
		end

		if self._pendingData then
			value.data = self._pendingData
			self._pendingData = nil
		end

		value.lockedAt = nil
		value.lockId = nil

		return value
	end, self._migrations)
end

return LockSession