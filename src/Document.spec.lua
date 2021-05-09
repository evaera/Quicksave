local SUPER_SPEED = require(script.Parent.Constants).SUPER_SPEED

local progressTime = require(script.Parent.progressTime)
local t = require(script.Parent.Parent.t)

return function()
    local MockDataStoreService = require(script.Parent.Parent.MockDataStoreService)
    local Quicksave = require(script.Parent)

    local collection = Quicksave.createCollection("playerData", {
        schema = {
            foo = t.optional(t.string);
            key = t.optional(t.string);
            oldKey = t.none;
            newKey = t.optional(t.string);
            ["1234"] = t.optional(t.exactly("foo"));
        };
        defaultData = {};
    })

    local document

    beforeEach(function()
        collection._activeDocuments = {}
		collection._justClosedDocuments = {}

        document = collection:getDocument("document"):expect()
    end)

    it("should be able to load new document with default data", function()
        local testCollection = Quicksave.createCollection("testCollection", {
            schema = {
                foo = t.string;
            };
            defaultData = {
                foo = "data";
            };
        })

        local testDocument = testCollection:getDocument("testDocument"):expect()

        expect(testDocument:get("foo")).to.equal("data")
    end)

    it("should not be able to load a locked document", function()
        local ok, err = collection:getDocument("locked"):await()

        expect(ok).to.equal(false)
        expect(err.kind).to.equal(Quicksave.Error.Kind.CouldNotAcquireLock)
    end)

    it("should be able to load existing data", function()
        local doc = collection:getDocument("evaera"):expect()

        expect(doc:get("foo")).to.equal("bar")
    end)

    it("should compress large data", function()
        local doc = collection:getDocument("large"):expect()

        doc:set("foo", string.rep("a", 2000))
        progressTime(7)
        doc:close():expect()

        if SUPER_SPEED then
            -- otherwise budgets are enabled and this could throttle
            local raw = MockDataStoreService:GetDataStore("playerData", "_package/eryn.io/quicksave"):GetAsync("large")

            expect(#raw < 2000).to.equal(true)
        end

        progressTime(7)

        doc = collection:getDocument("large"):expect()
        expect(doc:get("foo")).to.equal(string.rep("a", 2000))
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

        local document2 = collection:getDocument("document"):expect()

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
end