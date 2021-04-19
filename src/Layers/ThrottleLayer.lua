local DataStoreService = require(script.Parent.Parent.Parent.MockDataStoreService)
local Promise = require(script.Parent.Parent.Parent.Promise)
local Error = require(script.Parent.Parent.Error)
local RunService = game:GetService("RunService")

local DataStoreLayer = require(script.Parent.DataStoreLayer)

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

function ThrottleLayer._perform(methodName, collectionName, ...)
	local resource = METHOD_RESOURCE_MAP[methodName]

	if DataStoreService:GetRequestBudgetForRequestType(resource) > 0 then
		return DataStoreLayer.perform(methodName, collectionName, ...)
	end

	if ThrottleLayer._queue[resource] == nil then
		ThrottleLayer._queue[resource] = {}

		coroutine.wrap(function()
			RunService.Heartbeat:Wait()
			while #ThrottleLayer._queue[resource] > 0 do
				local request = table.remove(ThrottleLayer._queue[resource], 1)

				while DataStoreService:GetRequestBudgetForRequestType(resource) == 0 do
					RunService.Heartbeat:Wait()
				end

				local ok, result = pcall(DataStoreLayer.perform, unpack(request.args))
				if ok then
					request.resolve(result)
				else
					request.reject(Error.new({
						kind = Error.Kind.DataStoreError,
						error = result
					}))
				end
			end

			ThrottleLayer._queue[resource] = nil
		end)()
	end

	local args = { methodName, collectionName, ... }
	local promise = Promise.new(function(resolve, reject)
		table.insert(ThrottleLayer._queue[resource], {
			args = args,
			resolve = resolve,
			reject = reject
		})
	end)

	return promise:expect()
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