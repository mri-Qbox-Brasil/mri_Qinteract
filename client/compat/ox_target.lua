--[[
    Responde como ox_target (o fxmanifest faz provide dele). Mesmo formato de
    opcao; zona vira ponto com forma (client/scan.lua mede ate a borda).
]]

local registry = require 'client.registry'
local state = require 'client.state'
local exportAs = require 'client.compat.export'

local function handler(name, fn) exportAs('ox_target', name, fn) end

-- Nome da zona -> id, e o inverso pra limpar quando removem pelo id.
local zoneNames = {}
local idNames = {}

local function track(id, name)
    if name then
        zoneNames[name] = id
        idNames[id] = name
    end
    return id
end

local function zoneId(id)
    if id == nil then return nil end
    return zoneNames[id] or id
end

handler('disableTargeting', function(disabled) state.disabled = disabled == true end)
handler('isActive', function() return state.focused end)

-- No ox_target aparecem em tudo que se mira; aqui, em todo alvo que ja tem
-- opcao propria (por aproximacao, todo objeto por perto viraria alvo).
handler('addGlobalOption', function(options) registry.addEverywhere(options, GetInvokingResource()) end)
handler('removeGlobalOption', function(names) registry.removeEverywhere(names, GetInvokingResource()) end)

-- Opcoes registradas pra uma entidade, separadas pela origem.
handler('getTargetOptions', function(entity, kind, model)
    local result = { global = registry.everywhere }

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        model = model or GetEntityModel(entity)
        result.localEntity = registry.localEntities[entity]
        if NetworkGetEntityIsNetworked(entity) then
            result.entity = registry.entities[NetworkGetNetworkIdFromEntity(entity)]
        end

        if not kind then
            local entityType = GetEntityType(entity)
            kind = entityType == 2 and 'vehicle' or entityType == 3 and 'object'
                or (entityType == 1 and (IsPedAPlayer(entity) and 'player' or 'ped')) or nil
        end
    end

    if model then result.model = registry.models[model] end
    if kind and registry.globals[kind] then result[kind] = registry.globals[kind] end

    return result
end)

for _, kind in ipairs({ 'Object', 'Ped', 'Player', 'Vehicle' }) do
    local key = kind:lower()
    handler('addGlobal' .. kind, function(options) registry.addGlobal(key, options, GetInvokingResource()) end)
    handler('removeGlobal' .. kind, function(names) registry.removeGlobal(key, names, GetInvokingResource()) end)
end

handler('addModel', function(models, options) registry.addModel(models, options, GetInvokingResource()) end)
handler('removeModel', function(models, names) registry.removeModel(models, names, GetInvokingResource()) end)
handler('addEntity', function(netIds, options) registry.addEntity(netIds, options, GetInvokingResource()) end)
handler('removeEntity', function(netIds, names) registry.removeEntity(netIds, names, GetInvokingResource()) end)
handler('addLocalEntity', function(entities, options) registry.addLocalEntity(entities, options, GetInvokingResource()) end)
handler('removeLocalEntity', function(entities, names) registry.removeLocalEntity(entities, names, GetInvokingResource()) end)

handler('addSphereZone', function(data)
    local id = registry.addPoint(data.coords, data.options,
        { kind = 'sphere', radius = data.radius or 2.0 }, GetInvokingResource())
    return track(id, data.name)
end)

handler('addBoxZone', function(data)
    local size = data.size or vec3(2.0, 2.0, 2.0)
    local id = registry.addPoint(data.coords, data.options,
        { kind = 'box', size = vec3(size.x, size.y, size.z), rotation = data.rotation or 0.0 }, GetInvokingResource())
    return track(id, data.name)
end)

handler('addPolyZone', function(data)
    local points = data.points
    local thickness = data.thickness or 4.0
    local sx, sy, sz = 0.0, 0.0, 0.0
    local flat = {}

    for i = 1, #points do
        local p = points[i]
        sx, sy, sz = sx + p.x, sy + p.y, sz + (p.z or 0.0)
        flat[i] = vec2(p.x, p.y)
    end

    local n = #points
    local z = sz / n
    local id = registry.addPoint(vec3(sx / n, sy / n, z), data.options,
        { kind = 'poly', points = flat, minZ = z - thickness / 2, maxZ = z + thickness / 2 }, GetInvokingResource())
    return track(id, data.name)
end)

-- Zona que nunca foi criada chega como nil (o ox_compat manda assim): ignora.
handler('removeZone', function(id)
    local resolved = zoneId(id)
    if resolved == nil then return end
    if idNames[resolved] then
        zoneNames[idNames[resolved]] = nil
        idNames[resolved] = nil
    end
    registry.removePoint(resolved)
end)

handler('zoneExists', function(id)
    local resolved = zoneId(id)
    return resolved ~= nil and registry.points[resolved] ~= nil
end)
