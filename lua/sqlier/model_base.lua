local model_base = {}
model_base.__index = model_base

function model_base.Model(props)
    if not props.Table then
        error("A model cannot be created without a table name")
    end

    if not props.Identity then
        error(string.format(
            "Tried to create model '%s' without an identity, please add a property 'Identity' to it", props.Table))
    end

    if not props.Database then
        if table.Count(sqlier.Database) == 0 then
            sqlier.Initialize("fallback-sqlier", "sqlite")
        end

        props.Database = next(sqlier.Database)

        local warning = string.format("Database for table '%s' not set, fallbacking to '%s'", props.Table, props.Database)
        sqlier.Logger:log("MODEL", warning, sqlier.Logger.Error)
    elseif not sqlier.Database[props.Database] then
        error(string.format("Could not find a database with key '%s', you forgot to register it?", props.Database))
    end

    return setmetatable(props, model_base)
end

function model_base:__call(props)
    local instance = setmetatable(props, sqlier.InstanceBase)
    instance.model = function() return self end

    return instance
end

function model_base:get(identity, callback)
    self:database():get(self, identity, function(item)
        callback(self:__build(item))
    end)
end

function model_base:filter(filter, callback)
    self:database():filter(self, filter, function(items)
        if not items then
            callback({})
        end

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

function model_base:update(object, callback)
    self:database():update(self, object, callback)
end

function model_base:increment(object, callback)
    self:database():increment(self, object, callback)
end

function model_base:decrement(object, callback)
    self:database():decrement(self, object, callback)
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