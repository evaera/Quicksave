local makeEnum = require(script.Parent.makeEnum).makeEnum

local Error = {
	Kind = makeEnum("Quicksave.Error.Kind", {
		"DataStoreError",
		"CouldNotAcquireLock",
		"LockConsistencyViolation"
	}),
}
Error.__index = Error

function Error.new(options, parent)
	options = options or {}
	return setmetatable({
		error = tostring(options.error) or "[This error has no error text.]",
		trace = options.trace,
		context = options.context,
		kind = options.kind,
		parent = parent,
		createdTick = os.clock(),
		createdTrace = debug.traceback(),
	}, Error)
end

function Error.is(anything)
	if type(anything) == "table" then
		local metatable = getmetatable(anything)

		if type(metatable) == "table" then
			return rawget(anything, "error") ~= nil and type(rawget(metatable, "extend")) == "function"
		end
	end

	return false
end

function Error.isKind(anything, kind)
	assert(kind ~= nil, "Argument #2 to Quicksave.Error.isKind must not be nil")

	return Error.is(anything) and anything.kind == kind
end

function Error:extend(options)
	options = options or {}

	options.kind = options.kind or self.kind

	return Error.new(options, self)
end

function Error:getErrorChain()
	local runtimeErrors = { self }

	while runtimeErrors[#runtimeErrors].parent do
		table.insert(runtimeErrors, runtimeErrors[#runtimeErrors].parent)
	end

	return runtimeErrors
end

function Error:__tostring()
	local errorStrings = {
		string.format("-- Quicksave.Error(%s) --", self.kind or "?"),
	}

	for _, runtimeError in ipairs(self:getErrorChain()) do
		table.insert(errorStrings, table.concat({
			runtimeError.trace or runtimeError.error,
			runtimeError.context,
		}, "\n"))
	end

	return table.concat(errorStrings, "\n")
end

return Error