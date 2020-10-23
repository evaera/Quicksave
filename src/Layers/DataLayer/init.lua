local HttpService = game:GetService("HttpService")

local RawSchemes = require(script.Schemes.raw)

local MINIMUM_LENGTH_TO_COMPRESS = 1000

local DataLayer = {
	schemes = {
		["raw/1"] = RawSchemes["raw/1"]
	}
}

function DataLayer.unpack(value)
	if value == nil then
		return nil
	end

	local scheme = value.scheme

	if not DataLayer.schemes[scheme] then
		error(("Unknown scheme: %q"):format(scheme))
	end

	return HttpService:JSONDecode(DataLayer.schemes[scheme].unpack(value.data))
end

function DataLayer.pack(value)
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

return DataLayer