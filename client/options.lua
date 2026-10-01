--[[
    Filtro e execucao de uma opcao. O contexto e o alvo do momento:
    { entity, coords, distance, zone, bone } (bone e o indice no modelo).
]]

local groups = require 'client.groups'
local state = require 'client.state'

local options = {}

--- Alcance da opcao: o `distance` dela ou, sem, o alcance padrao do painel.
---@param option table
---@return number
function options.range(option)
    return option.distance or state.settings.defaultDistance
end

--- Grupo, item e canInteract. A distancia fica de fora: de longe a opcao ainda
--- conta pro marcador, so nao abre o prompt.
---@param option table
---@param ctx table
---@return boolean
function options.available(option, ctx)
    if option.allowInVehicle ~= true and cache.vehicle then return false end
    if not groups.has(option.groups) then return false end
    if not groups.hasItems(option.items, option.anyItem) then return false end

    if option.canInteract then
        local ok, result = pcall(option.canInteract, ctx.entity, ctx.distance, ctx.coords, option.name, ctx.bone)
        if not ok then
            lib.print.warn(('canInteract de "%s" (%s) falhou: %s'):format(option.name, option.resource, result))
            return false
        end
        return result and true or false
    end

    return true
end

--- O que o callback recebe: os campos da opcao mais o alvo.
---@param option table
---@param ctx table
---@return table
function options.response(option, ctx)
    local data = {}
    for key, value in pairs(option) do
        if key ~= '_id' then data[key] = value end
    end

    data.entity = ctx.entity or 0
    data.coords = ctx.coords
    data.distance = ctx.distance
    data.zone = ctx.zone
    data.coordsId = ctx.zone
    data.bone = ctx.bone
    return data
end

--- O que o servidor pode receber: sem funcao e com a entidade em netId.
local function forServer(data)
    local clean = {}
    for key, value in pairs(data) do
        if type(value) ~= 'function' then clean[key] = value end
    end

    local entity = clean.entity
    clean.entity = entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity)
        and NetworkGetNetworkIdFromEntity(entity) or 0
    return clean
end

--- Mesma ordem do ox_target: onSelect, export, event, serverEvent, command.
---@param option table
---@param ctx table
function options.run(option, ctx)
    local data = options.response(option, ctx)

    local ok, err = pcall(function()
        if option.onSelect then
            option.onSelect(option.qtarget and data.entity or data)
        elseif option.export then
            exports[option.resource][option.export](nil, data)
        elseif option.event then
            TriggerEvent(option.event, data)
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, forServer(data))
        elseif option.command then
            ExecuteCommand(option.command)
        end
    end)

    if not ok then
        lib.print.error(('opcao "%s" (%s) falhou: %s'):format(option.name, option.resource, err))
    end
end

-- Animacao enquanto segura uma opcao com holdTime (`anim = { dict, clip, flag }`).
local holdingAnim

---@param option table
function options.startHold(option)
    local anim = option.anim
    if type(anim) ~= 'table' or not anim.dict or not anim.clip then return end

    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag or 49, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
    holdingAnim = anim
end

function options.endHold()
    if not holdingAnim then return end
    StopAnimTask(cache.ped, holdingAnim.dict, holdingAnim.clip, 2.0)
    holdingAnim = nil
end

return options
