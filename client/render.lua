--[[
    Loop por frame: escolhe o alvo em foco, desenha o prompt nele, os
    marcadores dos outros alvos e o ponto central, e passa roda/setas e a
    tecla pra pagina do prompt.

    Foco: entre os alvos com opcao no alcance, o mais perto do centro da tela.
    Com "exigir olhar pro alvo", so conta quem esta dentro da area de mira
    (lookRadius, em fracao da altura da tela).
]]

local dui = require 'client.dui'
local input = require 'client.input'
local markers = require 'client.markers'
local options = require 'client.options'
local scan = require 'client.scan'
local state = require 'client.state'
local settings = require 'shared.settings'

-- Depois de confirmar, a tecla espera isso antes de aceitar outra (o loader na pagina).
local COOLDOWN_MS = 750
-- O prompt continua desenhado no ultimo lugar enquanto a pagina anima a saida.
local HIDE_MS = 250
-- Marcador distante: de longe fica com essa fracao do tamanho.
local FAR_SCALE = 0.72
-- Ponto central mirando algo: cresce isso (com mola).
local REACT_GROW = 0.45
local PROMPT_ASPECT = 2.4
-- Any focused NUI (inventory, phone, menus) hides the world layer.
local NO_TARGETS = {}
-- Keeps hiding a bit after the action ends, so it doesn't flicker between shots or sprints.
local ACTION_GRACE_MS = 400

-- Screen width in px this frame, to pick the marker texture level.
local screenWidth = 1920

local focus -- { key, target, options = { ... } }
local lastAnchor
local hideUntil = 0
local cooldownUntil = 0
-- Recolher quando parado: desde quando o prompt esta parado e se ja recolheu.
local shownAt = 0
local dormant = false
local pressing = false
local actionUntil = 0
-- Targets hidden by the dismiss key until they leave interaction reach.
local dismissed = {}
-- Only claim the E controls when the player's interact key is E (set on each new focus).
local keyIsE = false

local indicatorFades = {}
local dotFade = markers.new()
local dotReact = markers.new()

local function payload(list)
    local out = {}
    for i = 1, #list do
        local option = list[i]
        out[i] = {
            label = option.label or option.name,
            icon = option.icon,
            iconColor = option.iconColor,
            holdTime = option.holdTime,
            hideButton = option.hideButton,
            color = option.color,
        }
    end
    return { main = out }
end

local function sameOptions(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i]._id ~= b[i]._id then return false end
    end
    return true
end

local function focusContext()
    local target = focus.target
    return {
        entity = target.entity or 0,
        coords = scan.anchorOf(target) or (target.point and target.point.coords),
        distance = target.distance,
        zone = target.zone,
        bone = target.bone,
    }
end

-- Opcao destacada no prompt e os ganchos dela (onActive, onInactive, whileActive).
local active

local function callHook(option, hook)
    local fn = option[hook]
    if not fn then return end
    local ok, err = pcall(fn, options.response(option, focusContext()))
    if not ok then lib.print.error(('%s de "%s" (%s) falhou: %s'):format(hook, option.name, option.resource, err)) end
end

local function updateActive()
    local option = focus and focus.options[focus.index]
    if option == active then return end
    if active and focus then callHook(active, 'onInactive') end
    active = option
    if active then callHook(active, 'onActive') end
end

local function setFocus(target)
    if not target then
        if focus then
            if active then callHook(active, 'onInactive') end
            active = nil
            dui.send('visible', false)
            options.endHold()
            hideUntil = GetGameTimer() + HIDE_MS
            dormant = false
            focus = nil
            state.focused = false
        end
        return
    end

    if focus and focus.key == target.key then
        focus.target = target
        if not sameOptions(focus.options, target.reach) then
            focus.options = target.reach
            focus.index = math.min(focus.index, #focus.options)
            dui.send('setOptions', { options = payload(focus.options) })
        end
        updateActive()
        return
    end

    if active and focus then callHook(active, 'onInactive') end
    active = nil
    focus = { key = target.key, target = target, options = target.reach, index = 1 }
    state.focused = true
    shownAt = GetGameTimer()
    -- The page may still be dormant from the last target (it fades out as is).
    dormant = false
    dui.send('dormant', false)
    local keyLabel = input.keyLabel()
    keyIsE = keyLabel == 'E'
    dui.send('setKey', keyLabel)
    dui.send('setOptions', { options = payload(focus.options), resetIndex = true })
    dui.send('visible', true)
    updateActive()
end

local function screenDistanceSq(coords, aspect)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return nil end
    local dx = (sx - 0.5) * aspect
    local dy = sy - 0.5
    return dx * dx + dy * dy
end

--- Melhor alvo agora e as posicoes de quem aparece (pra nao recalcular no desenho).
local function pickFocus(targets, aspect)
    local s = state.settings
    local radiusSq = s.lookRadius * s.lookRadius
    local best, bestSq
    local anchors = {}

    for i = 1, #targets do
        local target = targets[i]
        -- Only focus candidates and the first markers need a position this frame.
        local anchor = (#target.reach > 0 or i <= s.maxIndicators + 1) and scan.anchorOf(target) or nil
        anchors[target.key] = anchor

        if anchor and #target.reach > 0 and not dismissed[target.key] then
            local sq = screenDistanceSq(anchor, aspect)
            if sq and (not s.requireLookAt or sq <= radiusSq) and (not bestSq or sq < bestSq) then
                best, bestSq = target, sq
            end
        end
    end

    return best, anchors
end

local function drawPrompt(anchor, aspect)
    if dui.isOverlay() then return dui.place(anchor) end

    local height = state.settings.promptScale
    local width = height * PROMPT_ASPECT / aspect

    SetDrawOrigin(anchor.x, anchor.y, anchor.z, 0)
    DrawSprite(dui.dict, dui.txt, width * (0.5 - dui.anchorX), height * (0.5 - dui.anchorY), width, height,
        0.0, 255, 255, 255, 255)
    ClearDrawOrigin()
end

local function drawMarker(sprite, coords, size, rotation, r, g, b, a, aspect)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawSprite(sprite.dict, settings.markerTexture(size * screenWidth), 0.0, 0.0, size, size * aspect, rotation, r, g, b, a)
    ClearDrawOrigin()
end

local function drawIndicators(targets, anchors, now, aspect)
    local sprite = state.indicator
    local s = state.settings
    local shown = {}

    if sprite.enabled then
        local count = 0
        for i = 1, #targets do
            if count >= s.maxIndicators then break end
            local target = targets[i]
            if (not focus or focus.key ~= target.key) and not dismissed[target.key] then
                local anchor = anchors[target.key]
                if anchor then
                    count = count + 1
                    shown[target.key] = true
                    local fade = indicatorFades[target.key] or markers.new()
                    indicatorFades[target.key] = fade
                    fade.coords = anchor
                    fade.distance = target.distance
                    markers.target(fade, now, 1)
                end
            end
        end
    end

    local color = sprite.color
    for key, fade in pairs(indicatorFades) do
        if not shown[key] then markers.target(fade, now, 0) end

        if markers.gone(fade, now) then
            indicatorFades[key] = nil
        elseif sprite.enabled then
            local alpha = markers.alpha(fade, now)
            local pop, twist = markers.pop(fade, now, 0.35)
            if sprite.pulse then
                local pulseScale, pulseAlpha = markers.pulse(now)
                pop = pop * pulseScale
                alpha = alpha * pulseAlpha
            end

            local far = math.min((fade.distance or 0.0) / s.markerDistance, 1.0)
            local size = sprite.size * (1.0 - (1.0 - FAR_SCALE) * far) * pop
            drawMarker(sprite, fade.coords, size, sprite.twist and twist or 0.0, color[1], color[2], color[3],
                math.floor(color[4] * alpha + 0.5), aspect)
        end
    end
end

local function drawCenterDot(inRange, now, aspect)
    local dot = state.centerDot
    markers.target(dotFade, now, (dot.enabled and inRange) and 1 or 0)
    markers.target(dotReact, now, (dot.react and focus) and 1 or 0)

    local alpha = markers.alpha(dotFade, now)
    if alpha <= 0.01 then return end

    local pop, twist = markers.pop(dotFade, now, 0.0)
    local react = markers.pop(dotReact, now, 0.0)
    local color = dot.color
    local r, g, b = color[1], color[2], color[3]

    if react > 0.0 then
        local k = math.min(react, 1.0)
        local to = dot.reactColor
        r = math.floor(r + (to[1] - r) * k + 0.5)
        g = math.floor(g + (to[2] - g) * k + 0.5)
        b = math.floor(b + (to[3] - b) * k + 0.5)
    end

    local size = dot.size * pop * (1.0 + REACT_GROW * react)
    DrawSprite(dot.dict, settings.markerTexture(size * screenWidth), 0.5, 0.5, size, size * aspect, dot.twist and twist or 0.0, r, g, b,
        math.floor(color[4] * alpha + 0.5))
end

-- Default E controls (pickup, talk, context; horn in a vehicle): with a prompt open, other scripts can't take the same press.
local KEY_CONTROLS = { 38, 46, 51 }
local VEHICLE_KEY_CONTROL = 86

local function claimKey()
    if not keyIsE then return end
    for i = 1, #KEY_CONTROLS do DisableControlAction(0, KEY_CONTROLS[i], true) end
    if cache.vehicle then DisableControlAction(0, VEHICLE_KEY_CONTROL, true) end
end

-- Roda do mouse e setas trocam a opcao (sem trocar de arma).
local SCROLL_UP = { 15, 17, 241, 172 }
local SCROLL_DOWN = { 14, 16, 242, 173 }

local function handleScroll()
    for i = 1, #SCROLL_UP do DisableControlAction(0, SCROLL_UP[i], true) end
    for i = 1, #SCROLL_DOWN do DisableControlAction(0, SCROLL_DOWN[i], true) end

    for i = 1, #SCROLL_UP do
        if IsDisabledControlJustPressed(0, SCROLL_UP[i]) then return dui.scroll(false) end
    end
    for i = 1, #SCROLL_DOWN do
        if IsDisabledControlJustPressed(0, SCROLL_DOWN[i]) then return dui.scroll(true) end
    end
end

local function setDormant(value)
    dormant = value
    shownAt = GetGameTimer()
    dui.send('dormant', value)
end

--- Jogador fazendo outra coisa (painel: actionHide): some com tudo do mundo.
local function inAction(now)
    local hide = state.settings.actionHide
    local ped = cache.ped
    local busy = (hide.aiming and IsPlayerFreeAiming(cache.playerId))
        or (hide.combat and (IsPedInMeleeCombat(ped) or IsPedShooting(ped)))
        or (hide.sprinting and IsPedSprinting(ped))
        or (hide.vehicle and cache.vehicle and GetEntitySpeed(cache.vehicle) * 3.6 > hide.vehicleSpeed)

    if busy then actionUntil = now + ACTION_GRACE_MS end
    return now < actionUntil
end

input.onPress = function()
    if not focus then return end
    -- Recolhido: a tecla so traz o prompt de volta, sem confirmar nada.
    if dormant then return setDormant(false) end
    if GetGameTimer() < cooldownUntil then return end
    pressing = true
    dui.send('interact')
end

input.onDismiss = function()
    if not focus then return end
    dismissed[focus.key] = true
    -- Sem foco nao chega o release: a tecla de interagir nao fica presa.
    pressing = false
end

--- Libera quem saiu do alcance (sem opcao em reach) ou sumiu do scan.
local function releaseDismissed()
    if not next(dismissed) then return end
    local inReach = {}
    local targets = scan.targets
    for i = 1, #targets do
        if #targets[i].reach > 0 then inReach[targets[i].key] = true end
    end
    for key in pairs(dismissed) do
        if not inReach[key] then dismissed[key] = nil end
    end
end

input.onRelease = function()
    pressing = false
    shownAt = GetGameTimer()
    dui.send('release')
end

--- Opcao que a pagina mandou ([tipo, indice]), ainda valendo pro foco atual.
local function optionFrom(data)
    if not focus or type(data) ~= 'table' then return end
    return focus.options[tonumber(data[2])]
end

RegisterNUICallback('select', function(data, cb)
    cb(1)
    local option = optionFrom(data)
    if not option then return end

    local ctx = focusContext()

    -- cooldown na opcao troca o padrao.
    local cooldown = tonumber(option.cooldown) or COOLDOWN_MS
    cooldownUntil = GetGameTimer() + cooldown
    dui.send('setCooldown', true)
    SetTimeout(cooldown, function() dui.send('setCooldown', false) end)

    if state.settings.confirmSound then
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end

    options.endHold()
    options.run(option, ctx)
end)

RegisterNUICallback('startHoldAnim', function(data, cb)
    cb(1)
    local option = optionFrom(data)
    if option then options.startHold(option) end
end)

RegisterNUICallback('endHoldAnim', function(_, cb)
    cb(1)
    options.endHold()
end)

RegisterNUICallback('currentOption', function(data, cb)
    cb(1)
    local index = type(data) == 'table' and tonumber(data[1])
    if focus and index then
        focus.index = index
        shownAt = GetGameTimer()
        updateActive()
    end
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local targets = (IsNuiFocused() or IsPauseMenuActive() or inAction(now)) and NO_TARGETS or scan.targets
        releaseDismissed()
        local busy = #targets > 0 or focus or now < hideUntil or next(indicatorFades) or dotFade.value > 0.01

        if not busy then
            Wait(100)
        else
            Wait(0)
            now = GetGameTimer()
            local aspect = GetAspectRatio(true)
            screenWidth = GetActiveScreenResolution()
            local best, anchors = pickFocus(targets, aspect)
            setFocus(best)

            local inRange = false
            for i = 1, #targets do
                if #targets[i].reach > 0 then inRange = true break end
            end

            drawIndicators(targets, anchors, now, aspect)

            local s = state.settings
            if focus and not pressing then
                if dormant and not s.dormant then
                    setDormant(false)
                elseif not dormant and s.dormant and now - shownAt >= s.dormantMs then
                    setDormant(true)
                end
            end

            if focus then
                lastAnchor = anchors[focus.key] or lastAnchor
                if lastAnchor and dui.isReady() then drawPrompt(lastAnchor, aspect) end
                claimKey()
                if not dormant and #focus.options > 1 then handleScroll() end
                if active and active.whileActive then callHook(active, 'whileActive') end
            elseif now < hideUntil and lastAnchor and dui.isReady() then
                drawPrompt(lastAnchor, aspect)
            end

            drawCenterDot(inRange, now, aspect)
        end
    end
end)

--- Prompt aberto de novo na superficie atual (pagina recarregada ou troca de tema).
local function resendFocus()
    dui.send('setLabel', locale('interact'))
    if not focus then return end
    dui.send('setKey', input.keyLabel())
    dui.send('setOptions', { options = payload(focus.options), resetIndex = true })
    dui.send('dormant', dormant)
    dui.send('visible', true)
end

dui.onReady(resendFocus)

-- Tema liquid fica no overlay e os outros na DUI: trocar com prompt aberto muda de superficie.
local overlayMode = dui.isOverlay()

state.onChange(function()
    local was = overlayMode
    overlayMode = dui.isOverlay()
    if was == overlayMode then return end
    dui.sendTo(was, 'visible', false)
    resendFocus()
end)
