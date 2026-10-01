--[[
    Responde como qb-target e qtarget (o fxmanifest faz provide dos dois). Os
    dois usam o mesmo formato: { options = { ... }, distance = 2.5 }, com
    action(entity), event + type, canInteract(entity, distance, option), job,
    gang, citizenid e item. Aqui vira o formato do ox_target.
]]

local registry = require 'client.registry'
local state = require 'client.state'
local exportAs = require 'client.compat.export'

local function citizenId()
    if GetResourceState('qbx_core') == 'started' then
        return (exports.qbx_core:GetPlayerData() or {}).citizenid
    end
    if GetResourceState('qb-core') == 'started' then
        return (exports['qb-core']:GetCoreObject().Functions.GetPlayerData() or {}).citizenid
    end
end

--- job e gang (string, lista ou { [nome] = nota }) num mapa so de grupos.
local function addGroups(map, value)
    if type(value) == 'string' then
        map[value] = 0
    elseif type(value) == 'table' then
        for key, grade in pairs(value) do
            if type(key) == 'number' then map[grade] = 0 else map[key] = tonumber(grade) or 0 end
        end
    end
end

local function hasCitizen(filter)
    local id = citizenId()
    if type(filter) == 'string' then return id == filter end
    for key, value in pairs(filter) do
        if (type(key) == 'number' and value == id) or (key == id and value) then return true end
    end
    return false
end

---@param option table opcao no formato qb
---@param distance number? distance do bloco
local function convert(option, distance)
    local converted = table.clone(option)
    converted.name = option.name or option.label
    converted.distance = option.distance or distance
    converted.items = option.item

    local groupMap
    if option.job or option.gang then
        groupMap = {}
        addGroups(groupMap, option.job)
        addGroups(groupMap, option.gang)
        -- 'all' no qb-target e sem filtro.
        if groupMap.all then groupMap = nil end
    end
    converted.groups = groupMap

    local check, citizen = option.canInteract, option.citizenid
    if check or citizen then
        converted.canInteract = function(entity, dist)
            if citizen and not hasCitizen(citizen) then return false end
            if check then return check(entity, dist, option) end
            return true
        end
    end

    -- No qb a resposta e a propria opcao com a entidade (o registry copia os campos).
    converted.onSelect = nil
    if option.action then
        local action = option.action
        converted.onSelect = function(data) action(data.entity) end
    elseif option.event then
        local kind = option.type or 'client'
        if kind == 'server' then
            converted.serverEvent, converted.event = option.event, nil
        elseif kind == 'command' then
            converted.command, converted.event = option.event, nil
        elseif kind == 'qbcommand' then
            local command = option.event
            converted.event = nil
            converted.onSelect = function(data) TriggerServerEvent('QBCore:CallCommand', command, data) end
        end
    end

    return converted
end

local function convertAll(params)
    if type(params) ~= 'table' then return {} end
    local list = {}
    for _, option in pairs(params.options or {}) do
        if type(option) == 'table' then list[#list + 1] = convert(option, params.distance) end
    end
    return list
end

local function zoneHeight(zoneOptions, center)
    if zoneOptions and zoneOptions.minZ and zoneOptions.maxZ then
        return (zoneOptions.minZ + zoneOptions.maxZ) / 2, zoneOptions.maxZ - zoneOptions.minZ
    end
    return center.z, 2.0
end

-- Zonas no formato do PolyZone, viradas ponto com forma. Devolvem o id.

local function circleZone(center, radius, list, resource)
    return registry.addPoint(center, list, { kind = 'sphere', radius = radius or 1.5 }, resource)
end

local function boxZone(center, length, width, zoneOptions, list, resource)
    local z, height = zoneHeight(zoneOptions, center)
    return registry.addPoint(vec3(center.x, center.y, z), list, {
        kind = 'box',
        size = vec3(width or 1.0, length or 1.0, height),
        rotation = zoneOptions and zoneOptions.heading or 0.0,
    }, resource)
end

local function polyZone(points, zoneOptions, list, resource)
    local sx, sy = 0.0, 0.0
    local flat = {}
    for i = 1, #points do
        sx, sy = sx + points[i].x, sy + points[i].y
        flat[i] = vec2(points[i].x, points[i].y)
    end

    local minZ = zoneOptions and zoneOptions.minZ or 0.0
    local maxZ = zoneOptions and zoneOptions.maxZ or (minZ + 4.0)
    return registry.addPoint(vec3(sx / #points, sy / #points, (minZ + maxZ) / 2), list,
        { kind = 'poly', points = flat, minZ = minZ, maxZ = maxZ }, resource)
end

--- Zona que chega pelo AddComboZone: o objeto do PolyZone vem sem metatable,
--- so com os campos, entao o tipo sai deles.
local function anyZone(zone, list, resource)
    if zone.radius then return circleZone(zone.center, zone.radius, list, resource) end
    if zone.length and zone.width then
        return boxZone(zone.center, zone.length, zone.width, {
            heading = zone.offsetRot or zone.heading, minZ = zone.minZ, maxZ = zone.maxZ,
        }, list, resource)
    end
    if zone.points then return polyZone(zone.points, zone, list, resource) end
end

-- Tipos do AddGlobalType (os do GetEntityType).
local ENTITY_TYPES = { [1] = 'ped', [2] = 'vehicle', [3] = 'object' }

-- Peds do SpawnPed (so qb-target): locais, criados na hora.
local spawned = {} -- { ped, resource, model, useModel }

local function spawnPed(data, resource)
    local model = type(data.model) == 'string' and joaat(data.model) or data.model
    local coords = data.coords
    lib.requestModel(model)

    local z = data.minusOne and coords.z - 1.0 or coords.z
    local ped = CreatePed(0, model, coords.x, coords.y, z, coords.w or 0.0, false, true)
    SetModelAsNoLongerNeeded(model)

    if data.freeze then FreezeEntityPosition(ped, true) end
    if data.invincible then SetEntityInvincible(ped, true) end
    if data.blockevents then SetBlockingOfNonTemporaryEvents(ped, true) end

    if data.animDict and data.anim then
        lib.requestAnimDict(data.animDict)
        TaskPlayAnim(ped, data.animDict, data.anim, 8.0, 0.0, -1, data.flag or 1, 0.0, false, false, false)
        RemoveAnimDict(data.animDict)
    elseif data.scenario then
        TaskStartScenarioInPlace(ped, data.scenario, 0, true)
    end

    local target = data.target
    if target then
        local list = convertAll(target)
        if target.useModel then registry.addModel(model, list, resource) else registry.addLocalEntity(ped, list, resource) end
    end

    spawned[#spawned + 1] = { ped = ped, resource = resource, model = model, useModel = target and target.useModel }
    return ped
end

local function despawn(index)
    local entry = table.remove(spawned, index)
    if not entry then return end
    if DoesEntityExist(entry.ped) then DeleteEntity(entry.ped) end
    registry.removeLocalEntity(entry.ped)
end

AddEventHandler('onClientResourceStop', function(resource)
    for i = #spawned, 1, -1 do
        if spawned[i].resource == resource then despawn(i) end
    end
end)

--- Registra os exports de um dos dois com os nomes dele.
---@param resource 'qb-target' | 'qtarget'
---@param globalNames table<string, string[]> tipo -> { export de adicionar, de remover }
local function register(resource, globalNames)
    local zones = {} -- nome -> { points = { ids } } ou { entity = handle, names = {...} }

    local function handler(name, fn) exportAs(resource, name, fn) end
    local function options(params) return convertAll(params) end

    handler('AddCircleZone', function(name, center, radius, _, params)
        zones[name] = { points = { circleZone(center, radius, options(params), GetInvokingResource()) } }
    end)

    handler('AddBoxZone', function(name, center, length, width, zoneOptions, params)
        zones[name] = { points = { boxZone(center, length, width, zoneOptions, options(params), GetInvokingResource()) } }
    end)

    handler('AddPolyZone', function(name, points, zoneOptions, params)
        zones[name] = { points = { polyZone(points, zoneOptions, options(params), GetInvokingResource()) } }
    end)

    -- Varias zonas com as mesmas opcoes, removidas juntas pelo nome.
    handler('AddComboZone', function(list, zoneOptions, params)
        local name = zoneOptions and zoneOptions.name
        local converted = options(params)
        local ids = {}
        for _, zone in pairs(list or {}) do
            local id = type(zone) == 'table' and anyZone(zone, converted, GetInvokingResource())
            if id then ids[#ids + 1] = id end
        end
        if name then zones[name] = { points = ids } end
    end)

    handler('AddEntityZone', function(name, entity, _, params)
        local list = options(params)
        local names = {}
        for i = 1, #list do names[i] = list[i].name end
        registry.addLocalEntity(entity, list, GetInvokingResource())
        zones[name] = { entity = entity, names = names }
    end)

    handler('RemoveZone', function(name)
        local zone = name ~= nil and zones[name]
        if not zone then return end
        zones[name] = nil
        if zone.points then
            for i = 1, #zone.points do registry.removePoint(zone.points[i]) end
        else
            registry.removeLocalEntity(zone.entity, zone.names)
        end
    end)

    handler('AddGlobalType', function(entityType, params)
        local kind = ENTITY_TYPES[entityType]
        if kind then registry.addGlobal(kind, options(params), GetInvokingResource()) end
    end)

    handler('RemoveGlobalType', function(entityType, labels)
        local kind = ENTITY_TYPES[entityType]
        if kind then registry.removeGlobal(kind, labels, GetInvokingResource()) end
    end)

    handler('AllowTargeting', function(allow) state.disabled = allow == false end)
    handler('IsTargetActive', function() return state.focused end)
    handler('IsTargetSuccess', function() return state.focused end)

    handler('AddTargetBone', function(bones, params)
        if type(bones) ~= 'table' then bones = { bones } end
        local list = options(params)
        for i = 1, #list do list[i].bones = bones end
        registry.addGlobal('vehicle', list, GetInvokingResource())
    end)

    handler('RemoveTargetBone', function(_, labels) registry.removeGlobal('vehicle', labels, GetInvokingResource()) end)

    handler('AddTargetEntity', function(entities, params)
        registry.addLocalEntity(entities, options(params), GetInvokingResource())
    end)
    handler('RemoveTargetEntity', function(entities, labels) registry.removeLocalEntity(entities, labels, GetInvokingResource()) end)

    handler('AddTargetModel', function(models, params)
        registry.addModel(models, options(params), GetInvokingResource())
    end)
    handler('RemoveTargetModel', function(models, labels) registry.removeModel(models, labels, GetInvokingResource()) end)

    for kind, names in pairs(globalNames) do
        handler(names[1], function(params) registry.addGlobal(kind, options(params), GetInvokingResource()) end)
        handler(names[2], function(labels) registry.removeGlobal(kind, labels, GetInvokingResource()) end)
    end
end

register('qb-target', {
    ped = { 'AddGlobalPed', 'RemoveGlobalPed' },
    vehicle = { 'AddGlobalVehicle', 'RemoveGlobalVehicle' },
    object = { 'AddGlobalObject', 'RemoveGlobalObject' },
    player = { 'AddGlobalPlayer', 'RemoveGlobalPlayer' },
})

-- Um ped ({ model, coords, ... }) ou uma lista deles.
exportAs('qb-target', 'SpawnPed', function(data)
    if type(data) ~= 'table' then return end
    local resource = GetInvokingResource()
    if data.model then return spawnPed(data, resource) end
    for _, entry in pairs(data) do
        if type(entry) == 'table' and entry.model then spawnPed(entry, resource) end
    end
end)

-- Por handle do ped, indice do SpawnPed ou lista deles; sem nada, tira todos do resource.
exportAs('qb-target', 'RemoveSpawnPed', function(peds)
    local resource = GetInvokingResource()
    if peds == nil then
        for i = #spawned, 1, -1 do
            if spawned[i].resource == resource then despawn(i) end
        end
        return
    end

    for _, value in pairs(type(peds) == 'table' and peds or { peds }) do
        for i = #spawned, 1, -1 do
            if spawned[i].ped == value then despawn(i) end
        end
    end
end)
register('qtarget', {
    ped = { 'Ped', 'RemovePed' },
    vehicle = { 'Vehicle', 'RemoveVehicle' },
    object = { 'Object', 'RemoveObject' },
    player = { 'Player', 'RemovePlayer' },
})
