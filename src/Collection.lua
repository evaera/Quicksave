local Promise = require(script.Parent.Parent.Promise)
local Document = require(script.Parent.Document)

local Collection = {}
Collection.__index = Collection

function Collection.new(name, options)
	options = options or {}

	assert(options.schema ~= nil, "You must provide a schema in options")

	return setmetatable({
		name = name;
		schema = options.schema;
		defualtData = options.defaultData;
		_migrations = options.migrations or {};
		_activeDocuments = {};
	}, Collection)
end

function Collection:getDocument(name)
	name = tostring(name)

	if self._activeDocuments[name] == nil then
		self._activeDocuments[name] = Document.new(self, name)
	end

	local promise = self._activeDocuments[name]:readyPromise()

	promise:catch(function()
		self:_removeDocument(name)
	end)

	return promise
end

function Collection:getLatestMigrationVersion()
	return #self._migrations
end

function Collection:validateData(data)
	return self.schema(data)
end

function Collection:_removeDocument(name)
	self._activeDocuments[name] = nil
end

return Collection