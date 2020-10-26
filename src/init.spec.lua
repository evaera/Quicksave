local SUPER_SPEED = true

local HttpService = game:GetService("HttpService")

local t = require(script.Parent.Parent.t)

local MockDataStoreConstants = require(script.Parent.Parent.MockDataStoreService.MockDataStoreService.MockDataStoreConstants)

if SUPER_SPEED then
	MockDataStoreConstants.WRITE_COOLDOWN = 0
	MockDataStoreConstants.BUDGETING_ENABLED = false
end

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

local MockDataStoreService = require(script.Parent.Parent.MockDataStoreService)

MockDataStoreService:ImportFromJSON([[
	{
		"DataStore": {
			"playerData": {
				"_package/eryn.io/quicksave": {
					"evaera": {"data":"{\"generation\":1,\"data\":{\"lockedAt\":1603680426,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"foo\":\"bar\"},\"createdAt\":1603680426}}","scheme":"raw/1"},
					"locked": {"data":"{\"generation\":1,\"data\":{\"lockedAt\":9999999999,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"foo\":\"bar\"},\"createdAt\":1603680426}}","scheme":"raw/1"}
				}
			},
			"migrationTests": {
				"_package/eryn.io/quicksave": {
					"migrationTest": {"data":"{\"generation\":0,\"data\":{\"lockedAt\":1603680426,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"oldKey\":\"foobar\"},\"createdAt\":1603680426}}","scheme":"raw/1"}
				}
			}
		}
	}
]])

return function()
	warn("Running tests at", SUPER_SPEED and "super speed" or "regular speed")

	local Quicksave = require(script.Parent)

	describe("Quicksave", function()
		it("should be able to create collections", function()
			local collection = Quicksave.createCollection("collectionName", {
				schema = {
					foo = t.optional(t.string);
					key = t.optional(t.string);
					oldKey = t.none;
					newKey = t.optional(t.string);
					["1234"] = t.optional(t.exactly("foo"));
				};
				defaultData = {};
			})
		end)

		it("should not allow duplicate collections", function()
			expect(function()
				Quicksave.createCollection("collectionName", {
					schema = {};
					migrations = {};
				})
			end).to.throw()
		end)

		it("should be able to get collections", function()
			local collection = Quicksave.getCollection("collectionName")

			expect(collection).to.be.ok()
			print(collection.name)
			expect(collection.name).to.equal("collectionName")
			expect(Quicksave.getCollection("collectionName")).to.equal(collection)
		end)
	end)

	describe("Collection", function()
		it("should be able to get documents", function()
			local collection = Quicksave.getCollection("collectionName")

			local document = collection:getDocument("foobar"):expect()

			expect(document.collection).to.equal(collection)
			expect(document.name).to.equal("foobar")

			expect(collection:getDocument("foobar"):expect()).to.equal(document)
		end)
	end)

	describe("Document", function()
		Quicksave.createCollection("playerData", {
			schema = {
				foo = t.optional(t.string);
				key = t.optional(t.string);
				oldKey = t.none;
				newKey = t.optional(t.string);
				["1234"] = t.optional(t.exactly("foo"));
			};
			defaultData = {};
		})

		local document, guid

		beforeEach(function()
			guid = HttpService:GenerateGUID()
			document = Quicksave.getCollection("playerData"):getDocument(guid):expect()
		end)

		it("should not be able to load a locked document", function()
			local ok, err = Quicksave.getCollection("playerData"):getDocument("locked"):await()

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Quicksave.Error.Kind.CouldNotAcquireLock)
		end)

		it("should compress large data", function()
			local doc = Quicksave.getCollection("playerData"):getDocument("large"):expect()

			doc:set("foo", string.rep("a", 2000))
			progressTime(7)
			doc:close():expect()

			if SUPER_SPEED then
				-- otherwise budgets are enabled and this could throttle
				local raw = MockDataStoreService:GetDataStore("playerData", "_package/eryn.io/quicksave"):GetAsync("large")

				expect(#raw < 2000).to.equal(true)
			end

			progressTime(7)

			local doc = Quicksave.getCollection("playerData"):getDocument("large"):expect()
			expect(doc:get("foo")).to.equal(string.rep("a", 2000))
		end)

		it("should be able to load existing data", function()
			local doc = Quicksave.getCollection("playerData"):getDocument("evaera"):expect()

			expect(doc:get("foo")).to.equal("bar")
		end)

		it("should be able to load existing data with a migration", function()
			Quicksave.createCollection("migrationTests", {
				schema = {
					oldKey = t.none;
					newKey = t.string;
				};
				defaultData = {
					newKey = "hi"
				};
				migrations = {
					function(oldData)
						return {
							newKey = oldData.oldKey
						}
					end
				};
			})

			local doc = Quicksave.getCollection("migrationTests"):getDocument("migrationTest"):expect()

			expect(doc:get("newKey")).to.equal("foobar")
			expect(doc:get("oldKey")).to.never.be.ok()
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

			progressTime(7)

			document:save():expect()
		end)

		it("should error when writing to a closed document", function()
			document:set("foo", "bar")

			document:close()

			expect(function()
				document:set("foo", "not bar")
			end).to.throw()

			expect(function()
				document:save():expect()
			end).to.throw()
		end)

		it("should be able to save, unlock, relock and load the same data", function()
			document:set("foo", "bar")

			progressTime(7)

			document:close():expect()

			progressTime(7)

			local document2 = Quicksave.getCollection("playerData"):getDocument(guid):expect()

			expect(document).to.never.equal(document2)

			expect(document2:get("foo")).to.equal("bar")
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