--[[
    Exports proprios do mri_Qinteract. As opcoes seguem o formato do ox_target
    (ver client/registry.lua). Os resources que usam ox_target, qb-target ou
    qtarget nao precisam disto: as compats em client/compat/ respondem por eles.
]]

local registry = require 'client.registry'
local state = require 'client.state'

local api = {}

---@param coords vector3
---@param options table
---@return integer id
function api.addCoords(coords, options)
    return registry.addPoint(coords, options, nil, GetInvokingResource())
end

---@param id integer
---@param names? string | string[]
function api.removeCoords(id, names)
    registry.removePoint(id, names, GetInvokingResource())
end

for _, kind in ipairs({ 'Vehicle', 'Ped', 'Object', 'Player' }) do
    local key = kind:lower()
    api['addGlobal' .. kind] = function(options) registry.addGlobal(key, options, GetInvokingResource()) end
    api['removeGlobal' .. kind] = function(names) registry.removeGlobal(key, names, GetInvokingResource()) end
end

function api.addModel(models, options) registry.addModel(models, options, GetInvokingResource()) end
function api.removeModel(models, names) registry.removeModel(models, names, GetInvokingResource()) end
function api.addEntity(netIds, options) registry.addEntity(netIds, options, GetInvokingResource()) end
function api.removeEntity(netIds, names) registry.removeEntity(netIds, names, GetInvokingResource()) end
function api.addLocalEntity(entities, options) registry.addLocalEntity(entities, options, GetInvokingResource()) end
function api.removeLocalEntity(entities, names) registry.removeLocalEntity(entities, names, GetInvokingResource()) end

--- Liga ou desliga todas as interacoes (cutscene, menu aberto...).
---@param disabled boolean
function api.disable(disabled)
    state.disabled = disabled == true
end

function api.isDisabled()
    return state.disabled
end

for name, fn in pairs(api) do exports(name, fn) end

return api
