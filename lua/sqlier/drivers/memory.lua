local db = {}

function db:initialize()
    self.Tables = {}
end

function db:validateSchema(schema)
    self.Tables[schema.Table] = {}
end

function db:get(schema, identity, callback)
    callback(self.Tables[schema.Table][identity])
end

function db:filter(schema, filter, callback)
    local items = {}

    for _, row in pairs(self.Tables[schema.Table]) do
        local matching = true

        for key, value in pairs(filter) do
            if row[key] ~= value then
                matching = false
                break
            end
        end

        if matching then
            table.insert(items, row)
        end
    end

    callback(items)
end

function db:find(schema, filter, callback)
    for _, row in pairs(self.Tables[schema.Table]) do
        local matching = true

        for key, value in pairs(filter) do
            if row[key] ~= value then
                matching = false
                break
            end
        end

        if matching then
            callback(row)
            return
        end
    end

    callback(nil)
end

function db:update(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to update using memory driver")
    end

    self:get(schema, identity, function(res)
        for key, value in pairs(object) do
            res[key] = value
        end

        db:insert(schema, object, function()
            if isfunction(callback) then
                callback()
            end
        end)
    end)
end

function db:increment(schema, object, callback)
    self:get(schema, Identity, function(res)
        for key, value in pairs(object) do
            res[key] = res[key] + value
        end

        db:insert(schema, res, function()
            if isfunction(callback) then
                callback()
            end
        end)
    end)
end

function db:decrement(schema, object, callback)
    self:get(schema, Identity, function(res)
        for key, value in pairs(object) do
            res[key] = res[key] - value
        end

        db:insert(schema, res, function()
            if isfunction(callback) then
                callback()
            end
        end)
    end)
end

function db:delete(schema, identity, callback)
    self.Tables[schema.Table][identity] = nil
    if isfunction(callback) then
        callback()
    end
end

function db:insert(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to insert using memory driver")
    end

    self.Tables[schema.Table][identity] = nil
    if isfunction(callback) then
        callback(identity)
    end
end

return db