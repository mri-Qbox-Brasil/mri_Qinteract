--[[
    Responde como sleepless_interact (o fxmanifest faz provide dele), pra quem
    chama exports.sleepless_interact. Os nomes dos exports sao os mesmos da API
    propria (client/api.lua); muda so:
    - offset la e em metros (aqui e offsetAbsolute) e offsetAbsolute la e nos
      eixos do mundo (aqui e offsetWorld);
    - addCoords aceita uma lista de posicoes e devolve a lista de ids;
    - disableInteract no lugar de disable.
    cooldown, onActive, onInactive e whileActive na opcao valem igual
    (client/render.lua).
]]

local registry = require 'client.registry'
local state = require 'client.state'
local exportAs = require 'client.compat.export'

local function handler(name, fn) exportAs('sleepless_interact', name, fn) end

local function convertOne(option)
    if type(option) ~= 'table' or not (option.offset or option.offsetAbsolute) then return option end
    option = table.clone(option)
    option.offsetWorld = option.offsetAbsolute
    option.offsetAbsolute = option.offset
    option.offset = nil
    return option
end

--- Uma opcao ou uma lista delas.
local function convert(options)
    if type(options) ~= 'table' then return options end
    if options[1] == nil then return convertOne(options) end

    local list = {}
    for i = 1, #options do list[i] = convertOne(options[i]) end
    return list
end

handler('disableInteract', function(disabled) state.disabled = disabled == true end)

handler('addCoords', function(coords, options)
    local resource = GetInvokingResource()
    options = convert(options)

    if type(coords) == 'table' and coords[1] then
        local ids = {}
        for i = 1, #coords do ids[i] = registry.addPoint(coords[i], options, nil, resource) end
        return ids
    end

    return registry.addPoint(coords, options, nil, resource)
end)

handler('removeCoords', function(id, names)
    if id == nil then return end
    registry.removePoint(tonumber(id) or id, names, GetInvokingResource())
end)

for _, kind in ipairs({ 'Ped', 'Vehicle', 'Object', 'Player' }) do
    local key = kind:lower()
    handler('addGlobal' .. kind, function(options) registry.addGlobal(key, convert(options), GetInvokingResource()) end)
    handler('removeGlobal' .. kind, function(names) registry.removeGlobal(key, names, GetInvokingResource()) end)
end

handler('addModel', function(models, options) registry.addModel(models, convert(options), GetInvokingResource()) end)
handler('removeModel', function(models, names) registry.removeModel(models, names, GetInvokingResource()) end)
handler('addEntity', function(netIds, options) registry.addEntity(netIds, convert(options), GetInvokingResource()) end)
handler('removeEntity', function(netIds, names) registry.removeEntity(netIds, names, GetInvokingResource()) end)
handler('addLocalEntity', function(entities, options) registry.addLocalEntity(entities, convert(options), GetInvokingResource()) end)
handler('removeLocalEntity', function(entities, names) registry.removeLocalEntity(entities, names, GetInvokingResource()) end)
