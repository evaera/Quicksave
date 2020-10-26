local function stackSkipAssert(condition, text)
	if not condition then
		error(text, 3)
	end
end

return {
	stackSkipAssert = stackSkipAssert;
}