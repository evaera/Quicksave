local Promise = require(script.Parent.Parent.Promise)
local t = require(script.Parent.Parent.t)
local Document = require(script.Parent.Document)
local stackSkipAssert = require(script.Parent.stackSkipAssert).stackSkipAssert
local getTime = require(script.Parent.getTime).getTime

local DOCUMENT_COOLDOWN = 7

local Collection = {}
Collection.__index = Collection

function Collection.new(name, options)
	options = options or {}

	stackSkipAssert(options.schema ~= nil, "You must provide a schema in options")

	local runSchema = t.strictInterface(options.schema)

	local defaultDataOk, defaultDataError = runSchema(options.defaultData)

	if not defaultDataOk then
		error(("The default data you provided for collection %q does not pass your schema requirements.\n\n%s\n"):format(
			name,
			defaultDataError
		), 2)
	end

	return setmetatable({
		name = name;
		schema = options.schema;
		runSchema = runSchema;
		defaultData = options.defaultData;
		_migrations = options.migrations or {};
		_activeDocuments = {};
		_justClosedDocuments = {};
	}, Collection)
end

function Collection:getDocument(name)
	name = tostring(name)

	if self._justClosedDocuments[name] then
		local waitTime = DOCUMENT_COOLDOWN - (getTime() - self._justClosedDocuments[name])

		if waitTime > 0 then
			warn(("Document %q in %q was recently closed. Your getDocument call will be delayed by %.1f seconds."):format(
				name,
				self.name,
				waitTime
			))
			Promise.delay(waitTime):await() -- todo:  yields
		end
	end

	if self._activeDocuments[name] == nil then
		self._activeDocuments[name] = Document.new(self, name)
	end

	local promise = self._activeDocuments[name]:readyPromise()

	promise:catch(function()
		self._activeDocuments[name] = nil
	end)

	return promise
end

function Collection:getLatestMigrationVersion()
	return #self._migrations
end

function Collection:validateData(data)
	return self.runSchema(data)
end

function Collection:keyExists(key)
	return self.schema[key] ~= nil
end

function Collection:validateKey(key, value)
	if self:keyExists(key) then
		return self.schema[key](value)
	else
		return false, ("Key %q is not present in %q's schema."):format(key, self.name)
	end
end

function Collection:_removeDocument(name)
	self._justClosedDocuments[name] = getTime()
	self._activeDocuments[name] = nil

	Promise.delay(DOCUMENT_COOLDOWN):andThen(function()
		self._justClosedDocuments[name] = nil
	end)
end

return Collection