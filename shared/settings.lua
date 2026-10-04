--[[
    Settings do painel /admininteract: padroes, validacao e o que o client usa
    pra desenhar. Usado pelo server (salvar e servir) e pelo client (aplicar no
    boot e ao vivo).
]]

local settings = {}

settings.themes = { block = true, glass = true, outline = true, round = true }

-- Formas dos marcadores: markers/<shape>_<px>.png (geradas de web/src/markers/shapes.ts).
settings.markerShapes = {
    target = true, dot = true, ring = true, diamond = true, rhombus = true, square = true,
    eye = true, hand = true, arrow = true, crosshair = true,
}

-- Formas que giram na entrada (client/markers.lua). Nas redondas o giro nao
-- aparece; olho, mao e seta ficariam tortos.
settings.markerTwist = { diamond = true, rhombus = true, square = true, crosshair = true }

settings.defaults = {
    -- Visual do prompt
    theme = 'block',
    accentColor = '#FFFFFF', -- vazio segue a convar mri:color
    showIcons = true,
    promptScale = 0.2, -- fracao da altura da tela ocupada pela textura do prompt

    -- Comportamento
    compact = false,
    compactIdleMs = 2500,
    interactKey = 'E', -- padrao do keybind; so vale no restart e pra quem nunca trocou
    useShowKey = false,
    showKey = 'LMENU',
    showKeyBehavior = 'toggle',
    confirmSound = false, -- som curto do GTA ao escolher uma opcao

    -- Alcance e mira
    markerDistance = 5.0, -- how far the distant marker shows
    defaultDistance = 3.0, -- reach of options without their own distance
    maxIndicators = 2,
    requireLookAt = true,
    -- Distancia do alvo ao centro da tela que conta como mirando, em fracao da altura.
    lookRadius = 0.1,
    requireLos = false,

    -- Marcadores
    -- useAccent: pinta com a cor de destaque do prompt (a do painel ou a mri:color).
    -- pulse: so o marcador distante; respira devagar enquanto esta parado.
    indicator = { enabled = true, shape = 'target', color = '#FFFFFF', useAccent = false, pulse = true, opacity = 0.8, size = 0.0085 },
    -- react: mirando algo interagivel, cresce e vai pra cor de destaque.
    centerDot = { enabled = false, shape = 'arrow', color = '#FFFFFF', useAccent = false, react = true, opacity = 1.0, size = 0.002 },
}

-- Limites dos numeros (min, max).
local ranges = {
    promptScale = { 0.1, 0.35 },
    compactIdleMs = { 500, 10000 },
    markerDistance = { 1.0, 15.0 },
    defaultDistance = { 1.0, 15.0 },
    maxIndicators = { 0, 20 },
    lookRadius = { 0.02, 0.3 },
    ['indicator.opacity'] = { 0, 1 },
    ['indicator.size'] = { 0.003, 0.03 },
    ['centerDot.opacity'] = { 0, 1 },
    ['centerDot.size'] = { 0.001, 0.012 },
}

local function isHex(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

local function isKey(value)
    return type(value) == 'string' and #value > 0 and #value <= 20
end

---@param path string
---@param default any
---@param value any
---@return any
local function sanitize(path, default, value)
    if type(value) ~= type(default) then return default end

    if type(default) == 'number' then
        local range = ranges[path]
        if range then value = math.min(math.max(value, range[1]), range[2]) end
        return value
    end

    if type(default) == 'string' then
        if path == 'theme' then return settings.themes[value] and value or default end
        if path == 'accentColor' then return (value == '' or isHex(value)) and value:upper() or default end
        if path == 'showKeyBehavior' then return (value == 'toggle' or value == 'hold') and value or default end
        if path == 'interactKey' or path == 'showKey' then return isKey(value) and value:upper() or default end
        if path:find('%.color$') then return isHex(value) and value:upper() or default end
        if path:find('%.shape$') then return settings.markerShapes[value] and value or default end
        return value
    end

    return value
end

--- Junta o que foi salvo com os padroes, validando tipo e limite de cada campo.
--- Campo desconhecido e descartado; campo faltando ou invalido volta pro padrao.
---@param saved table?
---@return table
function settings.merge(saved)
    saved = type(saved) == 'table' and saved or {}
    local result = {}

    for key, default in pairs(settings.defaults) do
        if type(default) == 'table' then
            local group = type(saved[key]) == 'table' and saved[key] or {}
            result[key] = {}

            for field, fieldDefault in pairs(default) do
                result[key][field] = sanitize(key .. '.' .. field, fieldDefault, group[field])
            end
        else
            result[key] = sanitize(key, default, saved[key])
        end
    end

    return result
end

--- Cor de destaque do prompt: a do painel ou, vazia, a da suite (mri:color).
---@param s table settings ja passados pelo merge
---@param suiteAccent string
---@return string
function settings.accent(s, suiteAccent)
    if s.accentColor ~= '' then return s.accentColor end
    return isHex(suiteAccent) and suiteAccent:upper() or '#00E699'
end

--- Cada forma e um txd de runtime proprio, criado sob demanda (client/markers.lua).
function settings.markerDict(shape)
    return 'mri_marker_' .. shape
end

-- Pre-rendered sizes in px (web/scripts/markers.mjs): runtime textures have no mipmaps.
settings.markerLevels = { 8, 12, 16, 24, 32, 48, 64, 96, 128 }

settings.markerTextures = {}
for i, px in ipairs(settings.markerLevels) do settings.markerTextures[i] = ('marker_%d'):format(px) end

function settings.markerFile(shape, px)
    return ('markers/%s_%d.png'):format(shape, px)
end

--- Texture of the smallest level that covers px on screen.
---@param px number
---@return string
function settings.markerTexture(px)
    local levels = settings.markerLevels
    for i = 1, #levels do
        if levels[i] >= px then return settings.markerTextures[i] end
    end
    return settings.markerTextures[#levels]
end

---@param hex string #RRGGBB
---@param opacity number 0 a 1
---@return integer[] { r, g, b, a }
function settings.toRgba(hex, opacity)
    return {
        tonumber(hex:sub(2, 3), 16),
        tonumber(hex:sub(4, 5), 16),
        tonumber(hex:sub(6, 7), 16),
        math.floor(opacity * 255 + 0.5),
    }
end

return settings
