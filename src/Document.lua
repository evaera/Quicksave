local Promise = require(script.Parent.Parent.Promise)
local AccessLayer = require(script.Parent.Layers.AccessLayer)
local DocumentData = require(script.Parent.DocumentData)
local stackSkipAssert = require(script.Parent.stackSkipAssert).stackSkipAssert

local Document = {}
Document.__index = Document

function Document.new(collection, name)
	return setmetatable({
		collection = collection;
		name = name;
		_data = nil;
	}, Document)
end

function Document:readyPromise()
	if self._readyPromise == nil then
		self._readyPromise = Promise.new(function(resolve)
			self._data = DocumentData.new({
				lockSession = AccessLayer.acquireLockSession(self.collection.name, self.name, self.collection._migrations);
				collection = self.collection;
				name = self.name;
			})

			resolve(self)
		end)
	end

	-- Wrap in Promise.resolve to track unique consumers
	return Promise.resolve(self._readyPromise)
end

function Document:get(key)
	key = tostring(key)

	stackSkipAssert(self.collection:keyExists(key), ("Key %q does not appear in %q's schema."):format(
		key,
		self.collection.name
	))

	return self._data:read()[key]
end

function Document:set(key, value)
	stackSkipAssert(self._data:isClosed() == false, "Attempt to call :set() on a closed Document")

	key = tostring(key)

	stackSkipAssert(self.collection:validateKey(key, value))

	local current = self._data:read()
	current[key] = value
	self._data:write(current)
end

function Document:save()
	stackSkipAssert(self._data:isClosed() == false, "Attempt to call :save() on a closed Document")

	return Promise.new(function(resolve)
		self._data:save()
		resolve()
	end)
end

function Document:close()
	stackSkipAssert(self._data:isClosed() == false, "Attempt to call :close() on a closed Document")

	return Promise.new(function(resolve)
		self._data:close()
		resolve()
	end):finally(function()
		self.collection:_removeDocument(self.name)
	end)
end

function Document:isClosed()
	return self._data:isClosed()
end

return Document