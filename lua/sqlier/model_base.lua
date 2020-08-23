local base = {}
base.__index = base

function base.Model(props)
    return setmetatable(props, base)
end

function base:new()
end

function base:filter(filter, callback)
    local context = self:context()

    for key, value in pairs(filter) do
        context = context:where(key):equal(value)
    end

    return context:run(callback)
end

function base:find(filter, callback)
    local context = self:context()

    for key, value in pairs(filter) do
        context = context:where(key):equal(value)
    end

    return context:limit(1):run(callback)
end

function base:database()
    return sqlier.Database[self.Database]
end

function base:context()
    return sqlier.QueryContext(self:database(), self.Table)
end

function base:__validate()
    self:database():validateSchema(self.Table, self.Columns)
end

return base