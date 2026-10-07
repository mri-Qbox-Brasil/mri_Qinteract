--[[
    Pagina do prompt (web/build/index.html) numa DUI, desenhada como textura no
    mundo. A textura tem o tamanho do prompt na tela (promptScale), com o dobro
    de pixels pra ficar nitida.

    Mensagens pra pagina: { action, value } (web/src/dui/DuiApp.tsx).

    Tema liquid: o prompt vai pra ui_page (overlay por cima da tela, com o jogo
    desfocado atras pelo startGameGlass), posicionado no alvo a cada frame.
    As mensagens levam target = 'prompt' (a pagina e dividida com o painel).
]]

local state = require 'client.state'

local dui = {
    ready = false,
    overlayReady = false,
    -- Centro da tecla dentro da textura (0 a 1); a pagina manda o real em promptAnchor.
    anchorX = 0.07,
    anchorY = 0.5,
}

local URL = ('nui://%s/web/build/index.html'):format(cache.resource)
local TXD = 'mri_qinteract_prompt'
local ASPECT = 2.4
local SUPERSAMPLE = 2
local MAX_EDGE = 2048

local OVERLAY_THEME = 'liquid'

local txd
local generation = 0

--- Tema desenhado no overlay da ui_page em vez da textura no mundo.
---@return boolean
function dui.isOverlay()
    return state.theme == OVERLAY_THEME
end

--- A superficie atual ja carregou.
function dui.isReady()
    if dui.isOverlay() then return dui.overlayReady end
    return dui.ready
end

local function size()
    local _, screenH = GetActiveScreenResolution()
    local height = math.floor(screenH * state.settings.promptScale * SUPERSAMPLE + 0.5)
    local width = math.floor(height * ASPECT + 0.5)

    local fit = math.min(1.0, MAX_EDGE / math.max(width, height))
    width = math.max(2, math.floor(width * fit) // 2 * 2)
    height = math.max(2, math.floor(height * fit) // 2 * 2)
    return width, height
end

--- Cria (ou recria, quando o tamanho muda) a DUI. A pagina responde em 'load'.
function dui.create()
    if dui.object then DestroyDui(dui.object) end

    generation = generation + 1
    dui.ready = false
    dui.width, dui.height = size()
    dui.object = CreateDui(URL, dui.width, dui.height)

    txd = txd or CreateRuntimeTxd(TXD)
    -- Nome novo a cada recriacao: textura de runtime nao pode ser trocada no lugar.
    dui.dict = TXD
    dui.txt = ('prompt_%d'):format(generation)
    CreateRuntimeTextureFromDuiHandle(txd, dui.txt, GetDuiHandle(dui.object))
end

--- Manda pra uma superficie especifica (troca de tema com prompt aberto).
---@param overlay boolean
---@param action string
---@param value any
function dui.sendTo(overlay, action, value)
    if overlay then
        if dui.overlayReady then SendNUIMessage({ target = 'prompt', action = action, value = value }) end
        return
    end
    if not dui.ready then return end
    SendDuiMessage(dui.object, json.encode({ action = action, value = value }))
end

---@param action string
---@param value any
function dui.send(action, value)
    dui.sendTo(dui.isOverlay(), action, value)
end

--- Roda e setas viram scroll da lista (a pagina troca a opcao).
---@param down boolean
function dui.scroll(down)
    if dui.isOverlay() then return dui.send('scroll', down) end
    if not dui.ready then return end
    SendDuiMouseMove(dui.object, dui.width // 2, dui.height // 2)
    SendDuiMouseWheel(dui.object, down and -120 or 120, 0)
end

local placed = { x = -1, y = -1, on = false }

--- Overlay: posicao do alvo na tela pra pagina, so quando muda.
---@param coords vector3
function dui.place(coords)
    local on, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if on == placed.on and math.abs(x - placed.x) < 0.0002 and math.abs(y - placed.y) < 0.0002 then return end
    placed.on, placed.x, placed.y = on, x, y
    SendNuiMessage(('{"target":"prompt","action":"position","value":{"x":%.5f,"y":%.5f,"on":%s}}'):format(x, y, on and 'true' or 'false'))
end

local readyListeners = {}

---@param fn fun()
function dui.onReady(fn)
    readyListeners[#readyListeners + 1] = fn
end

local function notifyReady(overlay)
    if overlay ~= dui.isOverlay() then return end
    for i = 1, #readyListeners do readyListeners[i]() end
end

RegisterNUICallback('load', function(_, cb)
    dui.ready = true
    cb(1)
    notifyReady(false)
end)

RegisterNUICallback('overlayLoad', function(_, cb)
    dui.overlayReady = true
    placed.x = -1
    cb(1)
    notifyReady(true)
end)

RegisterNUICallback('promptAnchor', function(data, cb)
    if type(data) == 'table' then
        dui.anchorX = tonumber(data.x) or dui.anchorX
        dui.anchorY = tonumber(data.y) or dui.anchorY
    end
    cb(1)
end)

-- Prompt maior ou menor no painel: a textura precisa de outro tamanho.
state.onChange(function(current, previous)
    if dui.object and current.promptScale ~= previous.promptScale then dui.create() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and dui.object then DestroyDui(dui.object) end
end)

dui.create()

return dui
