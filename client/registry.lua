--[[
    Onde ficam as interacoes registradas, por tipo de alvo:
    - points: posicao fixa ou zona (esfera, caixa, poligono);
    - entities: entidade de rede, pelo netId;
    - localEntities: entidade local, pelo handle;
    - models: todo objeto, ped ou veiculo daquele modelo;
    - globals: todo veiculo, ped, objeto ou jogador.

    As opcoes seguem o formato do ox_target (label, icon, distance, groups,
    items, canInteract, onSelect/export/event/serverEvent/command, bones,
    offset...) mais holdTime, hideButton e color do prompt.
]]

local registry = {
    points = {},
    entities = {},
    localEntities = {},
    models = {},
    globals = { vehicle = {}, ped = {}, object = {}, player = {} },
    -- Opcoes que entram em todo alvo que ja existe (addGlobalOption do ox_target).
    everywhere = {},
    -- Sobe a cada mudanca: o scan refaz a lista na hora.
    version = 0,
    -- Largest option distance ever registered, so the scan never cuts an option short.
    maxOptionDistance = 0.0,
}

local nextOptionId = 0
local nextPointId = 0

local function changed()
    registry.version = registry.version + 1
end

--- Uma opcao ou uma lista delas, normalizadas (copia rasa, com dono e id).
---@param options table
---@param resource string?
---@return table[]
local function normalize(options, resource)
    if type(options) ~= 'table' then return {} end
    -- Uma opcao solta (sem indice numerico) vira lista de uma.
    if options[1] == nil and (options.label or options.name or options.onSelect or options.export
            or options.event or options.serverEvent or options.command) then
        options = { options }
    end

    local list = {}
    for _, option in pairs(options) do
        if type(option) == 'table' then
            nextOptionId = nextOptionId + 1
            local copy = table.clone(option)
            copy.resource = copy.resource or resource or GetInvokingResource() or cache.resource
            copy.name = copy.name or copy.label or ('option_%d'):format(nextOptionId)
            copy._id = nextOptionId
            if type(copy.bones) == 'string' then copy.bones = { copy.bones } end
            if type(copy.distance) == 'number' and copy.distance > registry.maxOptionDistance then
                registry.maxOptionDistance = copy.distance
            end
            list[#list + 1] = copy
        end
    end

    return list
end

---@param names string | string[] | nil
---@return table<string, true> | nil
local function nameSet(names)
    if names == nil then return nil end
    if type(names) ~= 'table' then return { [names] = true } end

    local set = {}
    for _, name in pairs(names) do set[name] = true end
    return set
end

--- Tira de `list` as opcoes com esses nomes (nil tira todas). Com `resource`,
--- so as dele (como no ox_target: um resource nao tira opcao de outro).
--- Devolve se sobrou alguma.
local function removeFrom(list, names, resource)
    local set = nameSet(names)
    for i = #list, 1, -1 do
        local option = list[i]
        if (not set or set[option.name] or set[option.label]) and (not resource or option.resource == resource) then
            table.remove(list, i)
        end
    end
    return #list > 0
end

local function append(list, options)
    for i = 1, #options do list[#list + 1] = options[i] end
end

---@param value any
---@return any[]
local function asList(value)
    if type(value) == 'table' then return value end
    return { value }
end

-- Pontos e zonas

--- Interacao num ponto fixo. `shape` faz dele uma zona: a distancia passa a
--- ser ate a borda e o prompt fica no centro.
---@param coords vector3
---@param options table
---@param shape? { kind: 'sphere', radius: number } | { kind: 'box', size: vector3, rotation: number } | { kind: 'poly', points: vector2[], minZ: number, maxZ: number }
---@param resource? string
---@return integer id
function registry.addPoint(coords, options, shape, resource)
    nextPointId = nextPointId + 1
    registry.points[nextPointId] = {
        id = nextPointId,
        coords = vec3(coords.x, coords.y, coords.z),
        shape = shape,
        options = normalize(options, resource),
    }
    changed()
    return nextPointId
end

---@param id integer
---@param names? string | string[]
function registry.removePoint(id, names, resource)
    local point = registry.points[id]
    if not point then return end
    if not removeFrom(point.options, names, resource) then registry.points[id] = nil end
    changed()
end

-- Globais

---@param kind 'vehicle' | 'ped' | 'object' | 'player'
function registry.addGlobal(kind, options, resource)
    append(registry.globals[kind], normalize(options, resource))
    changed()
end

function registry.removeGlobal(kind, names, resource)
    removeFrom(registry.globals[kind], names, resource)
    changed()
end

function registry.addEverywhere(options, resource)
    append(registry.everywhere, normalize(options, resource))
    changed()
end

function registry.removeEverywhere(names, resource)
    removeFrom(registry.everywhere, names, resource)
    changed()
end

-- Por chave (modelo, netId, handle)

local function addKeyed(store, keys, options, resource, toKey)
    local normalized = normalize(options, resource)
    for _, key in pairs(asList(keys)) do
        key = toKey and toKey(key) or key
        store[key] = store[key] or {}
        append(store[key], normalized)
    end
    changed()
end

local function removeKeyed(store, keys, names, resource, toKey)
    for _, key in pairs(asList(keys)) do
        key = toKey and toKey(key) or key
        local list = store[key]
        if list and not removeFrom(list, names, resource) then store[key] = nil end
    end
    changed()
end

local function modelHash(model)
    return type(model) == 'string' and joaat(model) or model
end

function registry.addModel(models, options, resource) addKeyed(registry.models, models, options, resource, modelHash) end
function registry.removeModel(models, names, resource) removeKeyed(registry.models, models, names, resource, modelHash) end
function registry.addEntity(netIds, options, resource) addKeyed(registry.entities, netIds, options, resource) end
function registry.removeEntity(netIds, names, resource) removeKeyed(registry.entities, netIds, names, resource) end
function registry.addLocalEntity(entities, options, resource) addKeyed(registry.localEntities, entities, options, resource) end
function registry.removeLocalEntity(entities, names, resource) removeKeyed(registry.localEntities, entities, names, resource) end

-- Resource que parou leva as opcoes dele junto.
AddEventHandler('onClientResourceStop', function(resource)
    local function drop(list)
        for i = #list, 1, -1 do
            if list[i].resource == resource then table.remove(list, i) end
        end
        return #list > 0
    end

    for id, point in pairs(registry.points) do
        if not drop(point.options) then registry.points[id] = nil end
    end
    for _, list in pairs(registry.globals) do drop(list) end
    drop(registry.everywhere)
    for _, store in ipairs({ registry.models, registry.entities, registry.localEntities }) do
        for key, list in pairs(store) do
            if not drop(list) then store[key] = nil end
        end
    end

    changed()
end)

return registry
