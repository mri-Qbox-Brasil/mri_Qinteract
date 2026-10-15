-- Keeps client state across an ensure of this resource; unreplicated state bag, so a reconnect clears it.

local persist = {}

local PREFIX = 'mri_qinteract:'
local REF_KEY = '__mriQinteractRef'
-- Same ext type the runtime uses for function references (citizen scheduler.lua).
local EXT_FUNCREF = 10

-- Another resource's function becomes its reference id; this resource's own functions are dropped.
local function encode(value)
    if type(value) == 'function' then return nil end
    if type(value) ~= 'table' then return value end

    local ref = rawget(value, '__cfx_functionReference')
    if ref then
        -- Extra reference so the function outlives this Lua state.
        DuplicateFunctionReference(ref)
        return { [REF_KEY] = ref }
    end

    local copy = {}
    for key, item in pairs(value) do copy[key] = encode(item) end
    return copy
end

local function funcref(ref)
    local header = #ref < 256 and string.pack('>BBb', 0xC7, #ref, EXT_FUNCREF)
        or string.pack('>BI2b', 0xC8, #ref, EXT_FUNCREF)
    local proxy = msgpack.unpack(header .. ref)
    -- The unpacker took its own reference: release the one encode held.
    DeleteFunctionReference(ref)
    return proxy
end

---@param value any
---@return any
function persist.decode(value)
    if type(value) ~= 'table' then return value end

    local ref = rawget(value, REF_KEY)
    if ref then return funcref(ref) end

    for key, item in pairs(value) do value[key] = persist.decode(item) end
    return value
end

--- Gives back the references held for saved data that will not be restored.
---@param value any
function persist.release(value)
    if type(value) ~= 'table' then return end

    local ref = rawget(value, REF_KEY)
    if ref then return DeleteFunctionReference(ref) end

    for _, item in pairs(value) do persist.release(item) end
end

---@param key string
---@param data table
function persist.save(key, data)
    LocalPlayer.state:set(PREFIX .. key, encode(data), false)
end

--- Saved data still encoded (decode only what is kept) and cleared from the state bag.
---@param key string
---@return table?
function persist.take(key)
    local data = LocalPlayer.state[PREFIX .. key]
    if data == nil then return nil end
    LocalPlayer.state:set(PREFIX .. key, nil, false)
    return data
end

--- Runs `fn` when this resource stops, before its Lua state is gone.
---@param fn function
function persist.onStop(fn)
    AddEventHandler('onClientResourceStop', function(resource)
        if resource == cache.resource then fn() end
    end)
end

return persist
