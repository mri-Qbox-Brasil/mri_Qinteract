--[[
    Teclas (keybinds do FiveM, o jogador troca em Configuracoes > Teclas):
    - mri_interact: confirma a opcao (segurar nas que tem holdTime);
    - mri_interact_toggle: com "tecla pra mostrar/esconder" ligada no painel,
      so aparece interacao com ela (alternar ou segurar). Fica sempre
      registrada; o painel liga, desliga e troca o modo na hora.
    A letra padrao vem dos settings no carregamento (vale pra quem nunca trocou).
]]

local scan = require 'client.scan'
local state = require 'client.state'

local input = {
    -- O client/render.lua preenche.
    onPress = function() end,
    onRelease = function() end,
}

local showHeld = false
local toggledShown = false

local function hidden()
    local s = state.settings
    if not s.useShowKey then return false end
    if s.showKeyBehavior == 'hold' then return not showHeld end
    return not toggledShown
end

scan.isHidden = hidden

input.interactKey = lib.addKeybind({
    name = 'mri_interact',
    description = locale('keybind_interact'),
    defaultKey = state.settings.interactKey,
    onPressed = function() input.onPress() end,
    onReleased = function() input.onRelease() end,
})

lib.addKeybind({
    name = 'mri_interact_toggle',
    description = locale('keybind_toggle'),
    defaultKey = state.settings.showKey,
    onPressed = function()
        if not state.settings.useShowKey then return end
        showHeld = true
        if state.settings.showKeyBehavior == 'toggle' then toggledShown = not toggledShown end
        -- Na hora, sem esperar o proximo ciclo do scan.
        scan.refresh()
    end,
    onReleased = function()
        showHeld = false
        if state.settings.useShowKey and state.settings.showKeyBehavior == 'hold' then scan.refresh() end
    end,
})

-- O ox_lib devolve botao de mouse como codigo (o "b_" sai junto com o prefixo).
local MOUSE_BUTTONS = { ['100'] = 'M1', ['101'] = 'M2', ['102'] = 'M3', ['103'] = 'M4', ['104'] = 'M5' }

--- Texto da tecla de interagir como o jogador configurou.
---@return string
function input.keyLabel()
    local label = input.interactKey:getCurrentKey()
    if not label or label == '' then return state.settings.interactKey end
    return MOUSE_BUTTONS[label] or label
end

return input
