--[[
    Animacao dos marcadores (marcador distante e ponto central). Cada um tem um
    estado { from, to, start } que vai de 0 (escondido) a 1 (visivel):
    - alpha: sobe e desce em easeOutCubic (FADE_IN_MS / FADE_OUT_MS);
    - pop: tamanho e giro. Na entrada nasce pequeno, passa do tamanho (mola) e
      assenta, com um giro curto; na saida encolhe junto com o alpha.
    Trocar de direcao no meio parte do valor atual, sem salto.
]]

local markers = {}

local FADE_IN_MS = 140
local FADE_OUT_MS = 160
local ENTER_MS = 380
local EXIT_MS = FADE_OUT_MS
local TWIST_DEG = 35.0

local function clamp01(t)
    return t < 0.0 and 0.0 or (t > 1.0 and 1.0 or t)
end

local function easeOut(t)
    local u = 1.0 - t
    return 1.0 - u * u * u
end

-- easeOutBack: passa de 1 e volta (uns 20% a mais no pico, saindo do 0).
local function backOut(t)
    local c1 = 2.6
    local u = t - 1.0
    return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u
end

---@return table
function markers.new()
    return { from = 0.0, to = 0.0, start = 0, value = 0.0 }
end

--- Alpha agora (0 a 1).
---@param st table
---@param now number GetGameTimer()
---@return number
function markers.alpha(st, now)
    local duration = st.to > st.from and FADE_IN_MS or FADE_OUT_MS
    local t = easeOut(clamp01((now - st.start) / duration))
    st.value = st.from + (st.to - st.from) * t
    return st.value
end

--- Muda o destino (0 ou 1). Parte do alpha atual.
---@param st table
---@param now number
---@param to number
function markers.target(st, now, to)
    if st.to == to then return end
    st.from = markers.alpha(st, now)
    st.to = to
    st.start = now
end

---Multiplicador de escala e giro extra (graus) agora.
---@param st table
---@param now number
---@param min number escala de onde nasce e pra onde some (0 a 1)
---@return number scale, number rotation
function markers.pop(st, now, min)
    -- Direcao nova: parte do tamanho atual.
    if st.popStart ~= st.start then
        st.popStart = st.start
        st.popFrom = st.popScale or min
    end

    local entering = st.to > 0
    local t = clamp01((now - st.start) / (entering and ENTER_MS or EXIT_MS))

    local scale, rotation
    if entering then
        scale = st.popFrom + (1.0 - st.popFrom) * backOut(t)
        rotation = -TWIST_DEG * (1.0 - easeOut(t)) * (1.0 - st.popFrom)
    else
        scale = st.popFrom + (min - st.popFrom) * easeOut(t)
        rotation = 0.0
    end

    st.popScale = scale
    return scale, rotation
end

--- Terminou de sumir (pode ser descartado).
function markers.gone(st, now)
    return st.to == 0 and markers.alpha(st, now) <= 0.01
end

local PULSE_PERIOD_MS = 1800
local PULSE_SCALE = 0.1
local PULSE_ALPHA = 0.25

---Respiracao lenta do marcador parado: multiplicadores de escala e alpha.
---@param now number
---@return number scale, number alpha
function markers.pulse(now)
    local wave = (math.sin(now * 2.0 * math.pi / PULSE_PERIOD_MS) + 1.0) * 0.5
    return 1.0 + PULSE_SCALE * wave, 1.0 - PULSE_ALPHA * (1.0 - wave)
end

return markers
