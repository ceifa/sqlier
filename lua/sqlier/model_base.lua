local instance_base = include("sqlier/instance_base.lua")
local model_base = {}
model_base.__index = model_base

function model_base.Model(props)
    return setmetatable(props, model_base)
end

function model_base:__call(props)
    local instance = setmetatable(props, instance_base)
    instance.model = function() return self end

    return instance
end

function model_base:get(identity, callback)
    self:database():get(self, identity, function(item)
        callback(item and self:__build(item) or nil)
    end)
end

function model_base:filter(filter, callback)
    self:database():filter(self, filter, function(items)
        for key, value in ipairs(items) do
            items[key] = self:__build(value)
        end

        callback(items)
    end)
end

function model_base:find(filter, callback)
    self:database():find(self, filter, function(item)
        callback(self:__build(item))
    end)
end

-- Promise support
function model_base:getAsync(identity, callback)
    if not util.Promise then
        error("Promise API not found!")
    end

    return util.Promise(function(resolve, reject)
        self:get(identity, resolve)
    end)
end

function model_base:findAsync(filter, callback)
    if not util.Promise then
        error("Promise API not found!")
    end

    return util.Promise(function(resolve, reject)
        self:find(filter, resolve)
    end)
end

function model_base:filterAsync(filter, callback)
    if not util.Promise then
        error("Promise API not found!")
    end

    return util.Promise(function(resolve, reject)
        self:filter(filter, resolve)
    end)
end

function model_base:update(object, callback)
    self:database():update(self, object, callback)
end

function model_base:delete(identity, callback)
    self:database():delete(self,  identity, callback)
end

function model_base:insert(object, callback)
    self:database():insert(self, object, callback)
end

function model_base:database()
    return sqlier.Database[self.Database]
end

function model_base:__validate()
    self:database():validateSchema(self)
end

function model_base:__build(model)
    if not istable(model) then
        return nil
    end

    for k, v in pairs(model) do
        if self.Columns[k].Type == sqlier.Type.Integer or self.Columns[k].Type == sqlier.Type.Float then
            model[k] = tonumber(v)
        elseif self.Columns[k].Type == sqlier.Type.Bool then
            model[k] = tobool(v)
        elseif v == "NULL" then
            model[k] = nil
        end
    end

    return self(model)
end

return model_base