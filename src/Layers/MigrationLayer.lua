local DataLayer = require(script.Parent.DataLayer)

local MigrationLayer = {}

function MigrationLayer._unpack(value, migrations)
	value = value or {
		generation = #migrations;
		data = nil;
	}

	local data = value.data
	local generation = value.generation

	if generation < #migrations then
		for i = generation + 1, #migrations do
			data.data = migrations[i](data.data)
		end
	end

	return data
end

function MigrationLayer._pack(value, migrations)
	return {
		data = value;
		generation = #migrations;
	}
end

-- Todo: Prevent unpacking twice
function MigrationLayer.update(collection, key, callback, migrations)
	return MigrationLayer._unpack(DataLayer.update(collection, key, function(value)
		return MigrationLayer._pack(callback(MigrationLayer._unpack(value, migrations)), migrations)
	end), migrations)
end

function MigrationLayer.read(collection, key, migrations)
	return MigrationLayer._unpack(DataLayer.read(collection, key), migrations)
end

return MigrationLayer