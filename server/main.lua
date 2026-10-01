--[[
    Server do mri_Qinteract:
    - settings do painel /admininteract em data/config.json (salvar com ACE,
      repassar ao vivo pra todos);
    - registro do painel como plugin do mri_Qadmin;
    - repasse da convar mri:color quando muda.
]]

local settings = require 'shared.settings'

local CONFIG_FILE = 'data/config.json'
local current

local function load()
    local raw = LoadResourceFile(cache.resource, CONFIG_FILE)
    local saved

    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok then
            saved = decoded
        else
            lib.print.warn(('%s invalido, usando os padroes'):format(CONFIG_FILE))
        end
    end

    current = settings.merge(saved)
end

local function isAdmin(source)
    return IsPlayerAceAllowed(source, 'mri_Qinteract.admin') or IsPlayerAceAllowed(source, 'command')
end

load()

lib.callback.register('mri_Qinteract:getSettings', function()
    return current
end)

lib.callback.register('mri_Qinteract:isAdmin', function(source)
    return isAdmin(source)
end)

lib.callback.register('mri_Qinteract:saveSettings', function(source, payload)
    if not isAdmin(source) then return false, 'sem permissao' end
    if type(payload) ~= 'table' then return false, 'payload invalido' end

    local merged = settings.merge(payload)

    if not SaveResourceFile(cache.resource, CONFIG_FILE, json.encode(merged, { indent = true }), -1) then
        return false, 'falha ao salvar'
    end

    current = merged
    TriggerClientEvent('mri_Qinteract:settingsChanged', -1, current)

    return true, current
end)

AddConvarChangeListener('mri:color', function(name)
    if name ~= 'mri:color' then return end

    local color = GetConvar('mri:color', '#00E699')
    if not color:match('^#%x%x%x%x%x%x$') then return end

    TriggerClientEvent('mri_Qinteract:accentColorChanged', -1, color)
end)

-- So o painel usa o fundo (o prompt tem fundo proprio por tema).
AddConvarChangeListener('mri:backgroundColor', function(name)
    if name ~= 'mri:backgroundColor' then return end

    local color = GetConvar('mri:backgroundColor', '')
    if color ~= '' and not color:match('^#%x%x%x%x%x%x$') then return end

    TriggerClientEvent('mri_Qinteract:backgroundColorChanged', -1, color)
end)

-- Painel como plugin do mri_Qadmin (mesmo padrao do mri_Qspawn). Sem o Qadmin,
-- o /admininteract continua funcionando sozinho. RegisterPlugin e idempotente
-- por id, entao os tres caminhos abaixo juntos sao seguros.
local function registerPlugin()
    if GetResourceState('mri_Qadmin') ~= 'started' then return end

    exports['mri_Qadmin']:RegisterPlugin({
        id = 'interact',
        label = 'Interação',
        icon = 'hand',
        resource = cache.resource,
        htmlPath = 'web/build/admin.html',
        requiredPerms = { 'mri_Qinteract.admin', 'command' },
        description = 'Visual, comportamento, alcance e marcadores do mri_Qinteract',
    })
end

AddEventHandler('mri_Qadmin:server:pluginsReady', registerPlugin)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == 'mri_Qadmin' then registerPlugin() end
end)

CreateThread(registerPlugin)
