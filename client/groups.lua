--[[
    Filtros de grupo e item das opcoes (campos `groups`, `items` e `anyItem`
    do formato do ox_target). Grupo pelo qbx_core (ou qb-core); item pelo
    ox_inventory (ou o inventario do qb-core).
]]

local groups = {}

local playerData = {}

local function useQbx()
    return GetResourceState('qbx_core') == 'started'
end

local function refreshPlayerData()
    if useQbx() then
        playerData = exports.qbx_core:GetPlayerData() or {}
    elseif GetResourceState('qb-core') == 'started' then
        playerData = exports['qb-core']:GetCoreObject().Functions.GetPlayerData() or {}
    end
end

-- O qbx_core dispara os mesmos eventos do qb-core.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', refreshPlayerData)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() playerData = {} end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) playerData = data or {} end)
CreateThread(refreshPlayerData)

---@param name string
---@param grade integer?
---@return boolean
local function inGroup(name, grade)
    for _, field in ipairs({ 'job', 'gang' }) do
        local group = playerData[field]
        if group and group.name == name then
            local level = type(group.grade) == 'table' and group.grade.level or group.grade or 0
            if not grade or level >= grade then return true end
        end
    end

    return false
end

--- string, lista de nomes ou mapa { [nome] = nota minima }.
---@param filter string | string[] | table<string, integer> | nil
---@return boolean
function groups.has(filter)
    if not filter then return true end

    if useQbx() then
        return exports.qbx_core:HasGroup(filter) == true
    end

    if type(filter) == 'string' then return inGroup(filter) end

    for key, value in pairs(filter) do
        if type(key) == 'number' then
            if inGroup(value) then return true end
        elseif inGroup(key, tonumber(value)) then
            return true
        end
    end

    return false
end

---@param name string
---@return integer
local function itemCount(name)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Search('count', name) or 0
    end

    local count = 0
    for _, item in pairs(playerData.items or {}) do
        if item.name == name then count = count + (item.amount or item.count or 0) end
    end

    return count
end

--- string, lista de nomes ou mapa { [nome] = quantidade }. Sem `any`, precisa de todos.
---@param filter string | string[] | table<string, integer> | nil
---@param any boolean?
---@return boolean
function groups.hasItems(filter, any)
    if not filter then return true end
    if type(filter) == 'string' then return itemCount(filter) > 0 end

    for key, value in pairs(filter) do
        local name, needed = key, tonumber(value) or 1
        if type(key) == 'number' then name, needed = value, 1 end

        local ok = itemCount(name) >= needed
        if any and ok then return true end
        if not any and not ok then return false end
    end

    return not any
end

return groups
