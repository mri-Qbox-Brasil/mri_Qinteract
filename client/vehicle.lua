--[[
    Opcoes padrao em todo veiculo: abrir e fechar portas, capo e porta-malas,
    portas na macaneta (o osso da porta e a dobradica); capo e porta-malas na
    ponta da caixa do modelo do lado da dobradica deles. So com o veiculo
    destrancado e a porta inteira.
    Abrir e fechar sao opcoes separadas: o prompt mostra so a que vale agora.
    Texto so com o verbo (a posicao ja diz a peca) e o icone mostra a peca.
]]

local registry = require 'client.registry'

local DOORS = {
    { bone = 'door_dside_f', handle = 'handle_dside_f', index = 0, name = 'front_driver_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_pside_f', handle = 'handle_pside_f', index = 1, name = 'front_passenger_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_dside_r', handle = 'handle_dside_r', index = 2, name = 'rear_driver_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_pside_r', handle = 'handle_pside_r', index = 3, name = 'rear_passenger_door', icon = 'fa-solid fa-car-side' },
    { lid = 'bonnet', front = true, index = 4, name = 'hood', icon = 'fa-solid fa-car', distance = 2.0 },
    { lid = 'boot', front = false, index = 5, name = 'trunk', icon = 'fa-solid fa-car-rear', distance = 2.0 },
}

-- Trancado (2) e os outros estados de tranca (4 em diante) bloqueiam.
local function unlocked(vehicle)
    local status = GetVehicleDoorLockStatus(vehicle)
    return status == 0 or status == 1
end

local function isOpen(vehicle, index)
    return GetVehicleDoorAngleRatio(vehicle, index) > 0.0
end

local function setDoor(vehicle, index, open)
    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = GetGameTimer() + 500
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do Wait(0) end
    end

    if open then
        SetVehicleDoorOpen(vehicle, index, false, false)
    else
        SetVehicleDoorShut(vehicle, index, false)
    end
end

local function usable(vehicle, index)
    return unlocked(vehicle) and not IsVehicleDoorDamaged(vehicle, index) and GetIsDoorValid(vehicle, index)
end

-- Door state read once per scan refresh, shared by its open and close options.
local doorCache, doorCacheAt = {}, 0

local function doorState(vehicle, index)
    local now = GetGameTimer()
    if now - doorCacheAt > 50 then doorCache, doorCacheAt = {}, now end

    local key = vehicle * 8 + index
    local door = doorCache[key]
    if not door then
        local ok = usable(vehicle, index)
        door = { usable = ok, open = ok and isOpen(vehicle, index) }
        doorCache[key] = door
    end
    return door
end

local handleCache = {}

local function hasHandle(vehicle, handle)
    local key = ('%d:%s'):format(GetEntityModel(vehicle), handle)
    local found = handleCache[key]
    if found == nil then
        found = GetEntityBoneIndexByName(vehicle, handle) ~= -1
        handleCache[key] = found
    end
    return found
end

-- The lid bone is the hinge too: it only tells which end the lid is on and how high it sits.
local lidCache = {}
-- Meters from the bottom of the model box to where a hatch or trunk lid usually closes.
local LATCH_HEIGHT = 0.9

local function lidAnchor(lid, front)
    return function(vehicle)
        local model = GetEntityModel(vehicle)
        local key = ('%d:%s'):format(model, lid)
        local offset = lidCache[key]
        if offset then return offset end

        local min, max = GetModelDimensions(model)
        local middle = (min + max) / 2
        local y, z = front and max.y or min.y, middle.z
        local bone = GetEntityBoneIndexByName(vehicle, lid)
        if bone ~= -1 then
            local world = GetWorldPositionOfEntityBone(vehicle, bone)
            local hinge = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
            -- Rear-engine cars carry the boot in front: follow the hinge, not the lid name.
            local edge = hinge.y > middle.y and max.y or min.y
            -- Lid edge: box end (it can reach past the bumper) at latch height, never above the hinge.
            local latch = math.min(hinge.z, min.z + LATCH_HEIGHT)
            y, z = (hinge.y + edge) / 2, (hinge.z + latch) / 2
        end

        offset = vec3(middle.x, y, z)
        lidCache[key] = offset
        return offset
    end
end

local options = {}
for _, door in ipairs(DOORS) do
    -- The door bone is the hinge: anchor on the handle, hinge only for models without one.
    local anchors = door.handle and { door.handle, door.bone } or { door.bone or false }
    local anchor = door.lid and lidAnchor(door.lid, door.front)
    for _, open in ipairs({ true, false }) do
        local action = open and 'open' or 'close'
        for _, bone in ipairs(anchors) do
            local hingeFallback = door.handle and bone == door.bone
            options[#options + 1] = {
                name = ('mri_%s_%s'):format(action, door.name),
                label = locale(action),
                icon = door.icon,
                bones = bone and { bone } or nil,
                anchor = anchor,
                distance = door.distance or 1.5,
                canInteract = function(vehicle)
                    if hingeFallback and hasHandle(vehicle, door.handle) then return false end
                    local current = doorState(vehicle, door.index)
                    return current.usable and current.open ~= open
                end,
                onSelect = function(data)
                    setDoor(data.entity, door.index, open)
                end,
            }
        end
    end
end

registry.addGlobal('vehicle', options, cache.resource)
