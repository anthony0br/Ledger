-- Test that immutable types for reducers work correctly
--!strict

local Ledger = require("../src")

local Players = game:GetService("Players")

type Profile = {
    Gold: number,
    Items: { string },
    Files: {
        Message: string
    }
}
type Ops = {
    SpendGold: { Amount: number },
    BeSilly: { Message: string }
}

type function immut(t: type): type
    assert(t:is("table"), "t must be table")
    local t2 = types.newtable()
    for k, v in t:properties() do
        t2:setreadproperty(k, v.read)
    end
    return t2
end

type function deep_immut(t: type): type
    assert(t:is("table"), "t must be table")
    local t2 = types.newtable()
    -- todo: handle union and intersection types
    for k, v in t:properties() do
        local value = v.read
        if value and value:is("table") then
            value = deep_immut(value)
        end
        t2:setreadproperty(k, value)
    end
    local i = t:indexer()
    if i then
        t2:setindexer(i.index, i.readresult)
    end
    return t2
end

type function deep_mut(t: type): type
    assert(t:is("table"), "t must be table")
    local t2 = types.newtable()
    for k, v in t:properties() do
        local value = v.read
        if value and value:is("table") then
            value = deep_mut(value)
        end
        t2:setproperty(k, value)
    end
    return t2
end

type function mut(t: type): type
    assert(t:is("table"), "t must be table")
    local t2 = types.newtable()
    for k, v in t:properties() do
        t2:setproperty(k, v.read)
    end
    return t2
end

type function is_frozen(t: type)
    assert(t:is("table"), "t must be table")
    -- todo: handle union and intersection types
    for k, v in t:properties() do
        local value = v.read
        if value and value:is("table") then
            if value == v.write then
                error("Not frozen")
            end
            value = deep_immut(value)
        end
    end
    return types.singleton(true)
end

local function clone<T>(t: T & {})
    return table.clone(t) :: mut<T>
end

local Store = Ledger.NewTyped<<Profile, Ops>>({
    Name = "PlayerData",
    Default = { Gold = 100, Items = {}, Files = { Message = "" } },
    Reducer = function(state, op)
        local _is_frozen: is_frozen<typeof(state)> 
        state = clone(state)

        if op.Kind == "SpendGold" then
            if op.Amount > state.Gold then
                return nil
            end
            
            state.Gold -= op.Amount

            return state
        end

        if op.Kind == "BeSilly" then
            local files = clone(state.Files)
            files.Message = op.Message
            state.Files = files
            return state
        end

        return nil
    end,
})

Players.PlayerAdded:Connect(function(player)
    Store:Load(player)
    Store:Expect(player):Apply("SpendGold", { Amount = 25 })
    Store:Expect(player):Apply("BeSilly", { Message = "30" })
end)
