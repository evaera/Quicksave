local Error = require(script.Parent.Error)

local DocumentData = {}
DocumentData.__index = DocumentData

-- TODO: Backups

function DocumentData.new(options)
	return setmetatable({
		_lockSession = options.lockSession;
		_readOnlyData = options.readOnlyData;
		_collection = options.collection;
		_name = options.name;
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
			newData = self._collection.defaultData or {}
		end

		local schemaOk, schemaError = self._collection:validateData(newData)

		if not schemaOk then
			error(Error.new({
				kind = Error.Kind.SchemaValidationFailed,
				error = schemaError,
				context = ("Schema validation failed when loading data in collection %q key %q"):format(
					self._collection.name,
					self._name
				)
			}))
		end

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