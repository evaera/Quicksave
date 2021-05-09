local t = require(script.Parent.Parent.t)

return function()
    local Collection = require(script.Parent.Collection)

    local collection

    beforeEach(function()
        collection = Collection.new("collectionName", {
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
    
    describe("getDocument", function()
        it("should be able to get documents", function()
            local document = collection:getDocument("foobar"):expect()
    
            expect(document.collection).to.equal(collection)
            expect(document.name).to.equal("foobar")
    
            expect(collection:getDocument("foobar"):expect()).to.equal(document)
        end)
    end)

    describe("keyExists", function()
        it("should return true when the key exists", function()
            expect(collection:keyExists("foo")).to.equal(true)
        end)

        it("should return false when the key doesn't exist", function()
            expect(collection:keyExists("bar")).to.equal(false)
        end)
    end)

    describe("validateData", function()
        it("should validate correct data", function()
            expect(collection:validateData({
                ["1234"] = "foo";
            })).to.equal(true)
        end)

        it("should invalidate incorrect data", function()
            expect(collection:validateData({
                ["1234"] = "bar";
            })).to.equal(false)
        end)
    end)

    describe("validateKey", function()
        it("should return true when key validates", function()
            expect(collection:validateKey("1234", "foo")).to.equal(true)
        end)

        it("should return false when key invalidates", function()
            expect(collection:validateKey("1234", "bar")).to.equal(false)
        end)

        it("should return false when key doesn't exist", function()
            expect(collection:validateKey("bar", "baz")).to.equal(false)
        end)
    end)
end