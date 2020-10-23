local LZW = require(script.Parent.Parent.LZW)

return {
	["compressed/1"] = {
		pack = function(value)
			return LZW.compress(value)
		end;
		unpack = function(value)
			return LZW.decompress(value);
		end;
	}
}