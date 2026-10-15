--- Responde a `exports['<resource>']:<nome>(...)` em nome de outro resource
--- (o que o fxmanifest declara em provide). E o evento que o FiveM dispara
--- pra resolver o export.

local provided = {}

-- Callers cache exports by the provided name and only drop them when that name stops, not this resource.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for name in pairs(provided) do TriggerEvent('onClientResourceStop', name) end
end)

---@param resource string
---@param name string
---@param fn function
return function(resource, name, fn)
    provided[resource] = true
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
        setCB(fn)
    end)
end
