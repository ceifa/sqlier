local db = {}
local tables = {}

function db:initialize()
end

function db:validateSchema(schema)
    tables[schema.Table] = {}
end

function db:get(schema, identity, callback)
    callback(tables[schema.Table][identity])
end

function db:filter(schema, filter, callback)
    local items = {}

    for _, row in pairs(tables[schema.Table]) do
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
    for _, row in pairs(tables[schema.Table]) do
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
            callback()
        end)
    end)
end

function db:delete(schema, identity, callback)
    tables[schema.Table][identity] = nil
    callback()
end

function db:insert(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to insert using memory driver")
    end

    tables[schema.Table][identity] = nil
    callback(identity)
end

return db