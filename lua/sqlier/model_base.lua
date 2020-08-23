local ModelInstance = getmetatable("ModelInstance")

local model_base = {}
model_base.__index = model_base

function model_base.Model(props)
    return setmetatable(props, model_base)
end

function model_base:__call(props)
    local instance = setmetatable(props, ModelInstance)
    instance = setmetatable(self.Table, instance)

    function instance:model()
        return self
    end

    return instance
end

function model_base:filter(filter, callback)
    local context = self:context()

    for key, value in pairs(filter) do
        context = context:where(key):equal(value)
    end

    return context:run(callback)
end

function model_base:find(filter, callback)
    local context = self:context()

    for key, value in pairs(filter) do
        context = context:where(key):equal(value)
    end

    return context:limit(1):run(callback)
end

function model_base:database()
    return sqlier.Database[self.Database]
end

function model_base:context()
    return sqlier.QueryContext(self:database(), self.Table)
end

function model_base:__validate()
    self:database():validateSchema(self.Table, self.Columns)
end

return model_base