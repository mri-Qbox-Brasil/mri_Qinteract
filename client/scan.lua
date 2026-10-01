--[[
    Varredura do que esta por perto (a cada SCAN_MS ou na hora com
    scan.refresh). Cada alvo e um lugar onde o prompt pode abrir: um ponto, o
    centro de uma entidade, um osso dela ou um offset. Um alvo guarda as opcoes
    que valem pra ele:
    - available: passaram grupo, item e canInteract (contam pro marcador);
    - reach: dessas, as que estao no alcance (abrem o prompt).
]]

local registry = require 'client.registry'
local options = require 'client.options'
local state = require 'client.state'

local scan = {
    targets = {},
}

local SCAN_MS = 200
-- Veiculo e objeto grande: a origem fica longe da borda, entao busca um pouco alem.
local SEARCH_MARGIN = 3.0
-- Linha de visao: o raio parou ate essa distancia antes do alvo e ainda conta.
local LOS_TOLERANCE = 0.35
local LOS_FLAGS = 1 | 16 -- mundo e objetos
local LOS_MAX_TARGETS = 8
-- Caps the scan when some resource registers a huge option distance.
local MAX_SCAN_RADIUS = 15.0

-- Caixa do modelo (min, max), em offset da origem (cache por modelo).
local modelBoxes = {}

local function modelBox(model)
    local box = modelBoxes[model]
    if not box then
        local min, max = GetModelDimensions(model)
        box = { min = min, max = max }
        modelBoxes[model] = box
    end
    return box
end

--- Ponto da caixa do modelo em proporcao (0 a 1 em cada eixo; 0.5 e o meio).
local function modelPoint(model, ratio)
    local box = modelBox(model)
    return box.min + (box.max - box.min) * ratio
end

--- Onde o alvo esta agora (entidade anda, entao e recalculado a cada frame).
---@param target table
---@return vector3?
function scan.anchorOf(target)
    if target.point then return target.point.coords end

    local entity = target.entity
    if not DoesEntityExist(entity) then return nil end

    if target.bone then return GetWorldPositionOfEntityBone(entity, target.bone) end
    if target.offsetKind == 'world' then return GetEntityCoords(entity) + target.offset end

    local offset = target.offset
    if target.offsetKind == 'ratio' then
        offset = modelPoint(GetEntityModel(entity), offset)
    elseif not offset then
        offset = modelPoint(GetEntityModel(entity), vec3(0.5, 0.5, 0.5))
    end
    return GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)
end

-- Distancia ate a zona (zero dentro dela).

local function boxDistance(pos, center, shape)
    local rad = math.rad(-(shape.rotation or 0.0))
    local dx, dy = pos.x - center.x, pos.y - center.y
    local lx = dx * math.cos(rad) - dy * math.sin(rad)
    local ly = dx * math.sin(rad) + dy * math.cos(rad)
    local lz = pos.z - center.z
    local half = shape.size * 0.5

    local ox = math.max(math.abs(lx) - half.x, 0.0)
    local oy = math.max(math.abs(ly) - half.y, 0.0)
    local oz = math.max(math.abs(lz) - half.z, 0.0)
    return math.sqrt(ox * ox + oy * oy + oz * oz)
end

local function segmentDistance2d(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local len = abx * abx + aby * aby
    local t = len > 0 and math.min(math.max(((px - ax) * abx + (py - ay) * aby) / len, 0.0), 1.0) or 0.0
    local cx, cy = ax + abx * t - px, ay + aby * t - py
    return math.sqrt(cx * cx + cy * cy)
end

local function polyDistance(pos, shape)
    local points = shape.points
    local inside = false
    local edge = math.huge

    local j = #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if (a.y > pos.y) ~= (b.y > pos.y) and pos.x < (b.x - a.x) * (pos.y - a.y) / (b.y - a.y) + a.x then
            inside = not inside
        end
        edge = math.min(edge, segmentDistance2d(pos.x, pos.y, a.x, a.y, b.x, b.y))
        j = i
    end

    local flat = inside and 0.0 or edge
    local over = math.max(shape.minZ - pos.z, pos.z - shape.maxZ, 0.0)
    return math.sqrt(flat * flat + over * over)
end

local function pointDistance(pos, point)
    local shape = point.shape
    if not shape then return #(pos - point.coords) end
    if shape.kind == 'sphere' then return math.max(#(pos - point.coords) - shape.radius, 0.0) end
    if shape.kind == 'box' then return boxDistance(pos, point.coords, shape) end
    return polyDistance(pos, shape)
end

-- Montagem dos alvos

--- Onde a opcao fica na entidade, como no ox_target:
--- - offset: proporcao da caixa do modelo (0.5, 0.5, 0.5 e o centro);
--- - offsetAbsolute: metros a partir da origem, girando com a entidade;
--- - offsetWorld: metros a partir da origem nos eixos do mundo (compat).
local function offsetOf(option)
    local kind, value
    if option.offsetWorld then
        kind, value = 'world', option.offsetWorld
    elseif type(option.offsetAbsolute) ~= 'boolean' and option.offsetAbsolute then
        kind, value = 'local', option.offsetAbsolute
    elseif option.offset then
        kind, value = 'ratio', option.offset
    else
        return nil
    end
    return kind, vec3(value.x, value.y, value.z)
end

--- Separa as opcoes de uma entidade por lugar: osso, offset ou centro.
local function addEntityTargets(list, entity, optionLists)
    local byKey = {}

    for i = 1, #optionLists do
        local opts = optionLists[i]
        for j = 1, #opts do
            local option = opts[j]

            if option.bones then
                for _, boneName in ipairs(option.bones) do
                    local bone = GetEntityBoneIndexByName(entity, boneName)
                    if bone ~= -1 then
                        local key = 'b' .. bone
                        byKey[key] = byKey[key] or { entity = entity, bone = bone, options = {} }
                        table.insert(byKey[key].options, option)
                    end
                end
            elseif offsetOf(option) then
                local kind, offset = offsetOf(option)
                local key = ('o%s%.3f,%.3f,%.3f'):format(kind, offset.x, offset.y, offset.z)
                byKey[key] = byKey[key] or { entity = entity, offset = offset, offsetKind = kind, options = {} }
                table.insert(byKey[key].options, option)
            else
                byKey.c = byKey.c or { entity = entity, options = {} }
                table.insert(byKey.c.options, option)
            end
        end
    end

    for key, target in pairs(byKey) do
        target.key = ('e%d:%s'):format(entity, key)
        list[#list + 1] = target
    end
end

local function entityOptionLists(entity, kind)
    local lists = {}

    local own = registry.localEntities[entity]
    if own then lists[#lists + 1] = own end

    if NetworkGetEntityIsNetworked(entity) then
        local networked = registry.entities[NetworkGetNetworkIdFromEntity(entity)]
        if networked then lists[#lists + 1] = networked end
    end

    local model = registry.models[GetEntityModel(entity)]
    if model then lists[#lists + 1] = model end

    local global = registry.globals[kind]
    if global and #global > 0 then lists[#lists + 1] = global end

    return lists
end

local function collect(pos, radius)
    local list = {}

    -- Opcoes "em todo lugar" so entram em alvo que ja tem as proprias: senao
    -- todo objeto por perto viraria alvo.
    local everywhere = registry.everywhere

    for _, point in pairs(registry.points) do
        if pointDistance(pos, point) <= radius then
            local opts = point.options
            if #everywhere > 0 then
                opts = table.clone(opts)
                for i = 1, #everywhere do opts[#opts + 1] = everywhere[i] end
            end
            list[#list + 1] = { key = 'p' .. point.id, point = point, zone = point.id, options = opts }
        end
    end

    local search = radius + SEARCH_MARGIN
    local function addAll(entities, kind)
        for i = 1, #entities do
            local entity = entities[i]
            local lists = entityOptionLists(entity, kind)
            if #lists > 0 then
                if #everywhere > 0 then lists[#lists + 1] = everywhere end
                addEntityTargets(list, entity, lists)
            end
        end
    end

    local vehicles, peds, objects, players = {}, {}, {}, {}
    for _, v in ipairs(lib.getNearbyVehicles(pos, search, true)) do vehicles[#vehicles + 1] = v.vehicle end
    for _, v in ipairs(lib.getNearbyPeds(pos, search)) do peds[#peds + 1] = v.ped end
    for _, v in ipairs(lib.getNearbyObjects(pos, search)) do objects[#objects + 1] = v.object end
    for _, v in ipairs(lib.getNearbyPlayers(pos, search, false)) do players[#players + 1] = v.ped end

    addAll(vehicles, 'vehicle')
    addAll(peds, 'ped')
    addAll(objects, 'object')
    addAll(players, 'player')

    return list
end

local function inSight(target, anchor)
    local from = GetFinalRenderedCamCoord()
    local probe = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, anchor.x, anchor.y, anchor.z,
        LOS_FLAGS, cache.ped, 7)
    local _, hit, hitCoords, _, hitEntity = GetShapeTestResult(probe)

    if hit == 0 then return true end
    if target.entity and hitEntity == target.entity then return true end
    return #(hitCoords - anchor) <= LOS_TOLERANCE
end

--- Monta os alvos de agora. Fica vazio com o interact desligado ou escondido.
---@param hidden boolean
local function build(hidden)
    if state.disabled or hidden or IsPauseMenuActive() then
        scan.targets = {}
        return
    end

    local pos = GetEntityCoords(cache.ped)
    local s = state.settings
    local targets = {}

    local radius = math.min(math.max(s.markerDistance, s.defaultDistance, registry.maxOptionDistance), MAX_SCAN_RADIUS)

    for _, target in ipairs(collect(pos, radius)) do
        local anchor = scan.anchorOf(target)
        if anchor then
            local distance = target.point and pointDistance(pos, target.point) or #(pos - anchor)

            if distance <= radius then
                local ctx = { entity = target.entity or 0, coords = anchor, distance = distance, zone = target.zone, bone = target.bone }
                local available, reach = {}, {}

                for _, option in ipairs(target.options) do
                    if options.available(option, ctx) then
                        available[#available + 1] = option
                        if distance <= options.range(option) then reach[#reach + 1] = option end
                    end
                end

                -- Past the marker distance, only targets already in some option's reach stay.
                if #available > 0 and (distance <= s.markerDistance or #reach > 0) then
                    target.distance = distance
                    target.available = available
                    target.reach = reach
                    targets[#targets + 1] = target
                end
            end
        end
    end

    table.sort(targets, function(a, b) return a.distance < b.distance end)

    if s.requireLos then
        for i = #targets, 1, -1 do
            if i <= LOS_MAX_TARGETS then
                local anchor = scan.anchorOf(targets[i])
                if not anchor or not inSight(targets[i], anchor) then table.remove(targets, i) end
            else
                table.remove(targets, i)
            end
        end
    end

    scan.targets = targets
end

-- Quem decide se esta escondido e o client/input.lua (tecla de mostrar).
scan.isHidden = function() return false end

local wake = false

--- Refaz agora em vez de esperar o proximo ciclo (tecla de mostrar apertada).
function scan.refresh()
    build(scan.isHidden())
    wake = true
end

CreateThread(function()
    while true do
        build(scan.isHidden())

        local waited = 0
        wake = false
        while waited < SCAN_MS and not wake do
            Wait(50)
            waited = waited + 50
        end
    end
end)

return scan
