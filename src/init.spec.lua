local HttpService = game:GetService("HttpService")

return function()
	local Quicksave = require(script.Parent)

	describe("Quicksave", function()
		it("should be able to create collections", function()
			local collection = Quicksave.createCollection("playerData", {
				schema = Quicksave.t.any;
				migrations = {};
			})
		end)

		it("should not allow duplicate collections", function()
			expect(function()
				Quicksave.createCollection("playerData", {
					schema = Quicksave.t.any;
					migrations = {};
				})
			end).to.throw()
		end)

		it("should be able to get collections", function()
			local collection = Quicksave.getCollection("playerData")

			expect(collection).to.be.ok()
			print(collection.name)
			expect(collection.name).to.equal("playerData")
			expect(Quicksave.getCollection("playerData")).to.equal(collection)
		end)
	end)

	describe("Collection", function()
		it("should be able to get documents", function()
			local collection = Quicksave.getCollection("playerData")

			local document = collection:getDocument("evaera"):expect()

			expect(document.collection).to.equal(collection)
			expect(document.name).to.equal("evaera")

			expect(collection:getDocument("evaera"):expect()).to.equal(document)
		end)
	end)

	describe("Document", function()
		local document

		beforeEach(function()
			document = Quicksave.getCollection("playerData"):getDocument(HttpService:GenerateGUID()):expect()
		end)

		it("should give new keys as nil", function()
			expect(document:get("key")).to.equal(nil)
		end)

		it("should be able to retrieve keys", function()
			document:set("key", "foo")

			expect(document:get("key")).to.equal("foo")
		end)

		it("should be able to save", function()
			document:set("foo", "bar")

			document:save():expect()
		end)

		it("should convert number keys to strings", function()
			document:set(1234, "foo")

			expect(document:get("1234")).to.equal("foo")
		end)

		itSKIP("should disallow unserializable objects from being set", function()
			expect(function()
				document:set("key", workspace)
			end).to.throw()

			expect(function()
				document:set("key", {workspace})
			end).to.throw()

			expect(function()
				document:set("key", {nested = workspace})
			end).to.throw()

			expect(function()
				document:set("key", Vector3.new())
			end).to.throw()
		end)

		itSKIP("should disallow tables with metatables from being set", function()
			expect(function()
				document:set("key", setmetatable({}, {}))
			end).to.throw()

			expect(function()
				document:set("key", { nested = setmetatable({}, {}) })
			end).to.throw()
		end)
	end)
end