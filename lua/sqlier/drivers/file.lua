local db = {}

function db:initialize()
end

function db:validateSchema(schema)
    if not file.IsDir("sqlier/" .. schema.Table, "DATA") then
        file.CreateDir("sqlier/" .. schema.Table)
    end
end

local function escapeIdentity(identity)
    return identity:gsub("([^%w ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

function db:get(schema, identity, callback)
    local content = file.Read("sqlier/" .. schema.Table .. "/" .. escapeIdentity(identity) .. ".json")
    callback(content and util.JSONToTable(content))
end

function db:filter(schema, filter, callback)
    error("Filter not available on file system database driver")
end

function db:find(schema, filter, callback)
    error("Find not available on file system database driver")
end

function db:update(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to update using file system driver")
    end

    self:get(schema, identity, function(res)
        for key, value in pairs(object) do
            res[key] = value
        end

        db:insert(schema, res, function()
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
    file.Delete("sqlier/" .. schema.Table .. "/" .. escapeIdentity(identity) .. ".json")
        if isfuction(callback) then
                callback()
            end
end

function db:insert(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to insert using file system driver")
    end

    file.Write("sqlier/" .. schema.Table .. "/" .. escapeIdentity(identity) .. ".json", util.TableToJSON(object))
    if isfunction(callback) then
        callback(identity)
    end
end

return db