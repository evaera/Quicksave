local SUPER_SPEED = require(script.Parent.Constants).SUPER_SPEED

local progressTime do
	if SUPER_SPEED then
		local getTimeModule = require(script.Parent.getTime)

		local currentTime = 0
		getTimeModule.getTime = function()
			return currentTime
		end

		getTimeModule.testProgressTime = function(amount)
			currentTime = currentTime + amount
		end

		progressTime = getTimeModule.testProgressTime
	else
		progressTime = function() end
	end
end

return progressTime