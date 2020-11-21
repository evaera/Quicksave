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

    it("should be able to get documents", function()
        local document = collection:getDocument("foobar"):expect()

        expect(document.collection).to.equal(collection)
        expect(document.name).to.equal("foobar")

        expect(collection:getDocument("foobar"):expect()).to.equal(document)
    end)
end