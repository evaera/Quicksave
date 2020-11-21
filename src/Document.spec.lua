local Quicksave = require(script.Parent)
local MockDataStoreManager = require(script.Parent.Parent.MockDataStoreService.MockDataStoreService.MockDataStoreManager)

return function()
    -- readyPromise
    -- get
    -- set
    -- save
    -- close
    -- isClosed

    -- TODO: Test default data?

    --[[
    local collection = Quicksave.createCollection("collection", {
        schema = {};
    })
    --]]

    --[[
    beforeEach(function()
        MockDataStoreManager.ResetData()
    end)

    it("should not be able to load a locked document", function()
        local ok, err = collection:getDocument("locked"):await()

        expect(ok).to.equal(false)
        expect(err.kind).to.equal(Quicksave.Error.Kind.CouldNotAcquireLock)
    end)
    --]]
end