--- Responde a `exports['<resource>']:<nome>(...)` em nome de outro resource
--- (o que o fxmanifest declara em provide). E o evento que o FiveM dispara
--- pra resolver o export.
---@param resource string
---@param name string
---@param fn function
return function(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
        setCB(fn)
    end)
end
