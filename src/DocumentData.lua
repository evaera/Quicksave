local DataLayer = require(script.Parent.Layers.DataLayer)

local DocumentData = {}
DocumentData.__index = DocumentData

-- TODO: MigrationLayer
-- TODO: Schemas
-- TODO: Backups

function DocumentData.new(options)
	return setmetatable({
		_lockSession = options.lockSession;
		_readOnlyData = options.readOnlyData;
		_defaultData = options.defaultData;
		_currentData = nil;
		_dataLoaded = false;
	}, DocumentData)
end

function DocumentData:_load()
	if self._lockSession then
		return DataLayer.unpack(self._lockSession:read())
	else
		return self._readOnlyData
	end
end

function DocumentData:read()
	if self._dataLoaded == false then
		self._currentData = self:_load()
		self._dataLoaded = true

		if self._currentData == nil then
			self._currentData = self._defaultData or {}
		end
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

	self._lockSession:write(DataLayer.pack(self._currentData))
end

function DocumentData:close()
	if self._lockSession then
		self._lockSession:unlock()
	end
end

return DocumentData