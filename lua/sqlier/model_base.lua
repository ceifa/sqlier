local instance_base = require("sqlier/instance_base.lua")
local model_base = {}
model_base.__index = model_base

function model_base.Model(props)
    return setmetatable(props, model_base)
end

function model_base:__call(props)
    local instance = setmetatable(props, instance_base)
    instance = setmetatable(self.Table, instance)
    instance.model = self

    return instance
end

function model_base:get(identity, callback)
    self:database():get(self.Table, self.Identity, identity, callback)
end

function model_base:filter(filter, callback)
    self:database():get(self.Table, filter, callback)
end

function model_base:find(filter, callback)
    self:database():get(self.Table, filter, callback)
end

function model_base:update(object)
end

function model_base:delete(identity)
    self:database():delete(self.Table, self.Identity, identity)
end

function model_base:insert(object)
end

function model_base:database()
    return sqlier.Database[self.Database]
end

function model_base:__validate()
    self:database():validateSchema(self.Table, self.Columns, self.Identity)
end

return model_base