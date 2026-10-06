--[[
    Opcoes padrao em todo veiculo: abrir e fechar portas, capo e porta-malas,
    portas no osso delas; capo e porta-malas na ponta da frente e de tras da
    caixa do modelo (o osso deles e a dobradica). So com o veiculo destrancado
    e a porta inteira.
    Abrir e fechar sao opcoes separadas: o prompt mostra so a que vale agora.
    Texto so com o verbo (a posicao ja diz a peca) e o icone mostra a peca.
]]

local registry = require 'client.registry'

local DOORS = {
    { bone = 'door_dside_f', index = 0, name = 'front_driver_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_pside_f', index = 1, name = 'front_passenger_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_dside_r', index = 2, name = 'rear_driver_door', icon = 'fa-solid fa-car-side' },
    { bone = 'door_pside_r', index = 3, name = 'rear_passenger_door', icon = 'fa-solid fa-car-side' },
    { offset = vec3(0.5, 1.0, 0.5), index = 4, name = 'hood', icon = 'fa-solid fa-car', distance = 2.0 },
    { offset = vec3(0.5, 0.0, 0.5), index = 5, name = 'trunk', icon = 'fa-solid fa-car-rear', distance = 2.0 },
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

local options = {}
for _, door in ipairs(DOORS) do
    for _, open in ipairs({ true, false }) do
        local action = open and 'open' or 'close'
        options[#options + 1] = {
            name = ('mri_%s_%s'):format(action, door.name),
            label = locale(action),
            icon = door.icon,
            bones = door.bone and { door.bone },
            offset = door.offset,
            distance = door.distance or 1.5,
            canInteract = function(vehicle)
                return usable(vehicle, door.index) and isOpen(vehicle, door.index) ~= open
            end,
            onSelect = function(data)
                setDoor(data.entity, door.index, open)
            end,
        }
    end
end

registry.addGlobal('vehicle', options, cache.resource)
