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

function MigrationLayer.update(collection, key, callback, migrations)
	local migrated

	DataLayer.update(collection, key, function(value)
		migrated = callback(MigrationLayer._unpack(value, migrations))

		if migrated ~= nil then
			return MigrationLayer._pack(migrated, migrations)
		else
			return nil
		end
	end)

	return migrated
end

function MigrationLayer.read(collection, key, migrations)
	return MigrationLayer._unpack(DataLayer.read(collection, key), migrations)
end

return MigrationLayer