local RetryLayer = require(script.Parent.RetryLayer)

local HttpService = game:GetService("HttpService")

local RawSchemes = require(script.Schemes.raw)
local CompressedSchemes = require(script.Schemes.compressed)

local MINIMUM_LENGTH_TO_COMPRESS = 1000

local DataLayer = {
	schemes = {
		["raw/1"] = RawSchemes["raw/1"];
		["compressed/1"] = CompressedSchemes["compressed/1"];
	}
}

function DataLayer._unpack(value)
	if value == nil then
		return nil
	end

	local scheme = value.scheme

	if not DataLayer.schemes[scheme] then
		error(("Unknown scheme: %q"):format(scheme))
	end

	return HttpService:JSONDecode(DataLayer.schemes[scheme].unpack(value.data))
end

function DataLayer._pack(value)
	value = HttpService:JSONEncode(value)

	local scheme
	if #value > MINIMUM_LENGTH_TO_COMPRESS then
		scheme = "compressed/1"
	else
		scheme = "raw/1"
	end

	return {
		scheme = scheme;
		data = DataLayer.schemes[scheme].pack(value)
	}
end

function DataLayer.update(collection, key, callback)
	local decompressed

	RetryLayer.update(collection, key, function(value)
		decompressed = callback(DataLayer._unpack(value))

		if decompressed ~= nil then
			return DataLayer._pack(decompressed)
		else
			return nil
		end
	end)

	return decompressed
end

function DataLayer.read(collection, key)
	return DataLayer._unpack(RetryLayer.read(collection, key))
end

return DataLayer