local instance_base = require("sqlier/instance_base.lua")
local model_base = {}

function model_base.Model(props)
    return setmetatable(props, model_base)
end

function model_base:__call(props)
    local instance = setmetatable(props, instance_base)
    instance.model = function() return self end

    return instance
end

function model_base:get(identity, callback)
    self:database():get(self.Table, self.Identity, identity, function(item)
        callback(self(item))
    end)
end

function model_base:filter(filter, callback)
    self:database():filter(self.Table, filter, function(items)
        for key, value in items do
            items[key] = self(value)
        end

        callback(items)
    end)
end

function model_base:find(filter, callback)
    self:database():find(self.Table, filter, function(item)
        callback(self(item))
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

function model_base:update(object)
    if self.Columns.UpdateDate then
        object.UpdateDate = os.date("%Y-%m-%d")
    end

    self:database():insert(self.Table, self.Identity, object)
end

function model_base:delete(identity)
    self:database():delete(self.Table, self.Identity, identity)
end

function model_base:insert(object)
    if self.Columns.CreateDate then
        object.CreateDate = os.date("%Y-%m-%d")
    end

    self:database():insert(self.Table, self.Identity, object)
end

function model_base:database()
    return sqlier.Database[self.Database]
end

function model_base:__validate()
    self:database():validateSchema(self.Table, self.Columns, self.Identity)
end

return model_base