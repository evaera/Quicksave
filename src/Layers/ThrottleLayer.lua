local DataStoreService = require(script.Parent.Parent.Parent.MockDataStoreService)
local RunService = game:GetService("RunService")

local METHOD_RESOURCE_MAP = {
	GetAsync = Enum.DataStoreRequestType.GetAsync;
	UpdateAsync = Enum.DataStoreRequestType.UpdateAsync,
	RemoveAsync = Enum.DataStoreRequestType.SetIncrementAsync,
	SetAsync = Enum.DataStoreRequestType.SetIncrementAsync,
}

local ThrottleLayer = {
	_queue = {};
	_dataStores = {};
}

function ThrottleLayer._getDataStore(collection)
	if ThrottleLayer._dataStores[collection] == nil then
		ThrottleLayer._dataStores[collection] = DataStoreService:GetDataStore(collection, "_package/eryn.io/quicksave")
	end

	return ThrottleLayer._dataStores[collection]
end

function ThrottleLayer._performNow(methodName, collection, ...)
	local dataStore = ThrottleLayer._getDataStore(collection)

	return dataStore[methodName](dataStore, ...)
end

function ThrottleLayer._perform(methodName, ...)
	local resource = METHOD_RESOURCE_MAP[methodName]

	if DataStoreService:GetRequestBudgetForRequestType(resource) > 0 then
		return ThrottleLayer._performNow(methodName, ...)
	end

	if ThrottleLayer._queue[resource] == nil then
		ThrottleLayer._queue[resource] = {}

		local connection
		connection = RunService.Heartbeat:Connect(function()
			for _, thread in ipairs(ThrottleLayer._queue[resource]) do
				if DataStoreService:GetRequestBudgetForRequestType(resource) > 0 then
					ThrottleLayer._performNow(unpack(thread))
				else
					break
				end
			end

			if #ThrottleLayer._queue[resource] == 0 then
				connection:Disconnect()
				ThrottleLayer._queue[resource] = nil
			end
		end)
	end

	table.insert(ThrottleLayer._queue[resource], { methodName, ... })
end

function ThrottleLayer.update(collection, key, callback)
	return ThrottleLayer._perform("UpdateAsync", collection, key, callback)
end

function ThrottleLayer.read(collection, key)
	return ThrottleLayer._perform("GetAsync", collection, key)
end

function ThrottleLayer.write(collection, key, value)
	return ThrottleLayer._perform("SetAsync", collection, key, value)
end

function ThrottleLayer.remove(collection, key)
	return ThrottleLayer._perform("RemoveAsync", collection, key)
end

return ThrottleLayer