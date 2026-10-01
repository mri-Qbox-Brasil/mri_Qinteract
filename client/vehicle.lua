--[[
    Opcoes padrao em todo veiculo: abrir e fechar portas, capo e porta-malas,
    cada uma no osso dela. So com o veiculo destrancado e a porta inteira.
]]

local registry = require 'client.registry'

local DOORS = {
    { bone = 'door_dside_f', index = 0, label = 'toggle_front_driver_door' },
    { bone = 'door_pside_f', index = 1, label = 'toggle_front_passenger_door' },
    { bone = 'door_dside_r', index = 2, label = 'toggle_rear_driver_door' },
    { bone = 'door_pside_r', index = 3, label = 'toggle_rear_passenger_door' },
    { bone = 'bonnet', index = 4, label = 'toggle_hood' },
    { bone = 'boot', index = 5, label = 'toggle_trunk' },
}

-- Trancado (2) e os outros estados de tranca (4 em diante) bloqueiam.
local function unlocked(vehicle)
    local status = GetVehicleDoorLockStatus(vehicle)
    return status == 0 or status == 1
end

local function toggleDoor(vehicle, index)
    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = GetGameTimer() + 500
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < timeout do Wait(0) end
    end

    if GetVehicleDoorAngleRatio(vehicle, index) > 0.0 then
        SetVehicleDoorShut(vehicle, index, false)
    else
        SetVehicleDoorOpen(vehicle, index, false, false)
    end
end

local options = {}
for _, door in ipairs(DOORS) do
    options[#options + 1] = {
        name = 'mri_' .. door.label,
        label = locale(door.label),
        icon = 'fa-solid fa-car',
        bones = { door.bone },
        distance = 1.5,
        canInteract = function(vehicle)
            return unlocked(vehicle) and not IsVehicleDoorDamaged(vehicle, door.index)
                and GetIsDoorValid(vehicle, door.index)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, door.index)
        end,
    }
end

registry.addGlobal('vehicle', options, cache.resource)
