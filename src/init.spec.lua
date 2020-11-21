local SUPER_SPEED = require(script.Parent.Constants).SUPER_SPEED

local t = require(script.Parent.Parent.t)

local MockDataStoreConstants = require(script.Parent.Parent.MockDataStoreService.MockDataStoreService.MockDataStoreConstants)

if SUPER_SPEED then
	MockDataStoreConstants.WRITE_COOLDOWN = 0
	MockDataStoreConstants.BUDGETING_ENABLED = false
end

return function()
	warn("Running tests at", SUPER_SPEED and "super speed" or "regular speed")

	local MockDataStoreManager = require(script.Parent.Parent.MockDataStoreService.MockDataStoreService.MockDataStoreManager)
	local MockDataStoreService = require(script.Parent.Parent.MockDataStoreService)
	local Quicksave = require(script.Parent)

	beforeEach(function()
		MockDataStoreManager.ResetData()

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
	end)

	describe("Quicksave", function()
		it("should be able to create collections", function()
			Quicksave.createCollection("collectionName", {
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

		it("should error when creating a collection without a schema", function()
			expect(function()
				Quicksave.createCollection("collectionName")
			end).to.throw()
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
			expect(collection.name).to.equal("collectionName")
			expect(Quicksave.getCollection("collectionName")).to.equal(collection)
		end)
	end)
end