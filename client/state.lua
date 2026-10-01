--[[
    Settings em uso no client e o que sai deles pra desenhar (cores ja
    resolvidas, sprites dos marcadores). Os outros modulos leem daqui a cada
    frame, entao trocar no painel vale na hora.
]]

local settings = require 'shared.settings'

local state = {
    settings = settings.merge(nil),
    suiteAccent = GetConvar('mri:color', '#00E699'),
    -- disableTargeting / exports: some com tudo enquanto true.
    disabled = false,
    -- Tem prompt aberto num alvo agora (client/render.lua).
    focused = false,
}

local listeners = {}

--- Txd de runtime por forma, criado uma vez so (recriar com o mesmo nome nao e seguro).
local loadedShapes = {}

local function ensureShape(shape)
    if loadedShapes[shape] then return end
    CreateRuntimeTextureFromImage(CreateRuntimeTxd(settings.markerDict(shape)), 'marker', settings.markerFile(shape))
    loadedShapes[shape] = true
end

local function markerSprite(marker, accent)
    return {
        enabled = marker.enabled,
        dict = settings.markerDict(marker.shape),
        txt = 'marker',
        twist = settings.markerTwist[marker.shape] == true,
        color = settings.toRgba(marker.useAccent and accent or marker.color, marker.opacity),
        size = marker.size,
    }
end

--- Recalcula o que sai dos settings. Chamado no boot e a cada mudanca.
local function resolve()
    local s = state.settings
    local accent = settings.accent(s, state.suiteAccent)

    if s.indicator.enabled then ensureShape(s.indicator.shape) end
    if s.centerDot.enabled then ensureShape(s.centerDot.shape) end

    state.accent = accent
    state.indicator = markerSprite(s.indicator, accent)
    state.indicator.pulse = s.indicator.pulse
    state.centerDot = markerSprite(s.centerDot, accent)
    state.centerDot.react = s.centerDot.react
    state.centerDot.reactColor = settings.toRgba(accent, 1)
end

---@param saved table? settings vindos do server (passam pelo merge)
function state.setSettings(saved)
    local previous = state.settings
    state.settings = settings.merge(saved)
    resolve()

    for i = 1, #listeners do listeners[i](state.settings, previous) end
end

---@param color string
function state.setSuiteAccent(color)
    state.suiteAccent = color
    resolve()

    for i = 1, #listeners do listeners[i](state.settings, state.settings) end
end

---@param fn fun(current: table, previous: table)
function state.onChange(fn)
    listeners[#listeners + 1] = fn
end

-- Boot: o arquivo distribuido com o resource. O valor atual do server chega
-- pelo client/panel.lua logo depois.
do
    local raw = LoadResourceFile(cache.resource, 'data/config.json')
    local saved

    if raw and raw ~= '' then
        local ok, decoded = pcall(json.decode, raw)
        if ok then saved = decoded else lib.print.warn('data/config.json invalido, usando os padroes') end
    end

    state.settings = settings.merge(saved)
    resolve()
end

return state
