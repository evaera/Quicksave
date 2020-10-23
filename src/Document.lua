local Promise = require(script.Parent.Parent.Promise)
local AccessLayer = require(script.Parent.Layers.AccessLayer)
local DocumentData = require(script.Parent.DocumentData)

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
		self._readyPromise = Promise.new(function(resolve, reject)
			self._data = DocumentData.new({
				lockSession = AccessLayer.acquireLockSession(self.collection.name, self.name);
				defaultData = self.collection.defaultData;
			})

			resolve(self)
		end)
	end

	-- Wrap in Promise.resolve to track unique consumers
	return Promise.resolve(self._readyPromise)
end

function Document:get(key)
	key = tostring(key)

	return self._data:read()[key]
end

function Document:set(key, value)
	key = tostring(key)

	local current = self._data:read()
	current[key] = value
	self._data:write(current)
end

function Document:save()
	return Promise.new(function(resolve)
		self._data:save()
		resolve()
	end)
end

function Document:close()
	self.collection:_removeDocument(self.name)

	coroutine.wrap(function()
		self._data:close()
	end)()
end

return Document