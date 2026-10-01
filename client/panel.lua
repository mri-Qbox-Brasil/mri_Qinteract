--[[
    Settings ao vivo, tema da suite e painel /admininteract:
    - o server manda os settings no boot e a cada save (client/state.lua aplica);
    - a pagina do prompt pega tema e destaque em getDuiConfig e recebe as mudancas;
    - o painel (ui_page; embutido no mri_Qadmin usa os mesmos callbacks).
]]

local dui = require 'client.dui'
local settings = require 'shared.settings'
local state = require 'client.state'

--- O que a pagina do prompt usa dos settings.
local function duiConfig()
    local s = state.settings
    return {
        accentColor = state.accent,
        holdLabel = locale('hold'),
        theme = s.theme,
        showIcons = s.showIcons,
        menu = { compact = s.compact, idleMs = s.compactIdleMs },
    }
end

state.onChange(function()
    dui.send('mriSettings', duiConfig())
end)

RegisterNUICallback('getDuiConfig', function(_, cb)
    cb(duiConfig())
end)

RegisterNUICallback('getUiConfig', function(_, cb)
    local uiConfig = lib.callback.await('ox_lib:getUiConfig', false)
    cb(type(uiConfig) == 'table' and uiConfig or false)
end)

RegisterNetEvent('mri_Qinteract:settingsChanged', state.setSettings)

RegisterNetEvent('mri_Qinteract:accentColorChanged', function(color)
    state.setSuiteAccent(color)
    -- Painel aberto muda junto com a suite.
    SendNUIMessage({ action = 'updateAccentColor', accentColor = color })
end)

RegisterNetEvent('mri_Qinteract:backgroundColorChanged', function(color)
    SendNUIMessage({ action = 'updateBackgroundColor', backgroundColor = color or '' })
end)

RegisterNetEvent('ox_lib:uiConfigChanged', function(newConfig)
    if type(newConfig) ~= 'table' then return end
    dui.send('applyUiConfig', newConfig)
    SendNUIMessage({ action = 'applyUiConfig', uiConfig = newConfig })
end)

CreateThread(function()
    state.setSettings(lib.callback.await('mri_Qinteract:getSettings', false))
end)

-- Painel /admininteract.
local panelOpen = false

RegisterCommand('admininteract', function()
    if panelOpen then return end

    if not lib.callback.await('mri_Qinteract:isAdmin', false) then
        lib.notify({ type = 'error', description = locale('no_permission') })
        return
    end

    panelOpen = true
    SetNuiFocus(true, true)

    -- O painel segue o fundo e o /uiconfig da suite; o prompt tem fundo proprio por tema.
    local uiConfig = lib.callback.await('ox_lib:getUiConfig', false)
    SendNUIMessage({
        action = 'openAdmin',
        accentColor = state.suiteAccent,
        backgroundColor = GetConvar('mri:backgroundColor', ''),
        uiConfig = type(uiConfig) == 'table' and uiConfig or nil,
    })
end, false)

RegisterNUICallback('adminGetSettings', function(_, cb)
    cb({
        settings = state.settings,
        defaults = settings.defaults,
        suiteAccent = state.suiteAccent,
    })
end)

RegisterNUICallback('adminSaveSettings', function(data, cb)
    local ok, result = lib.callback.await('mri_Qinteract:saveSettings', false, data)
    cb({ ok = ok, settings = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('adminClose', function(_, cb)
    panelOpen = false
    SetNuiFocus(false, false)
    cb(1)
end)
