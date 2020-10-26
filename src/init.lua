local t = require(script.Parent.t)
local Promise = require(script.Parent.Promise)
local Collection = require(script.Collection)
local Error = require(script.Error)

local Quicksave = {
	t = t;
	Promise = Promise;
	Error = Error;

	_collections = {};
}

function Quicksave.createCollection(name, options)
	if Quicksave._collections[name] then
		error(("Collection %q already exists"):format(name))
	end

	Quicksave._collections[name] = Collection.new(name, options)

	return Quicksave._collections[name]
end

function Quicksave.getCollection(name)
	return Quicksave._collections[name] or error(("Collection %q hasn't been created yet!"):format(name))
end

return Quicksave