local function copyDeep(dictionary)
	local new = {}

	for key, value in pairs(dictionary) do
		if type(value) == "table" then
			new[key] = copyDeep(value)
		else
			new[key] = value
		end
	end

	return new
end

local DocumentData = {}
DocumentData.__index = DocumentData

-- TODO: Backups

function DocumentData.new(options)
	return setmetatable({
		_lockSession = options.lockSession;
		_readOnlyData = options.readOnlyData;
		_collection = options.collection;
		_currentData = nil;
		_dataLoaded = false;
		_closed = false;
	}, DocumentData)
end

function DocumentData:isClosed()
	return self._closed
end

function DocumentData:_load()
	if self._lockSession then
		return self._lockSession:read()
	else
		return self._readOnlyData
	end
end

function DocumentData:read()
	if self._dataLoaded == false then
		local newData = self:_load()

		if newData == nil then
			local defaultData = self._collection.defaultData
			newData = defaultData and copyDeep(defaultData) or {}
		end

		assert(self._collection:validateData(newData))

		self._currentData = newData
		self._dataLoaded = true
	end

	return self._currentData
end

function DocumentData:write(value)
	if self._lockSession == nil then
		error("Can't write to a readonly DocumentData")
	end

	self._currentData = value
end

function DocumentData:save()
	if self._lockSession == nil then
		error("Can't save on a readonly DocumentData")
	end

	self._lockSession:write(self._currentData)
end

function DocumentData:close()
	self._closed = true

	if self._lockSession then
		self._lockSession:unlockWithFinalData(self._currentData)
	end
end

return DocumentData