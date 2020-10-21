local db = {}

require("redis.core")
local redis = FindMetaTable("redis_client")

function db:initialize(options)
    redis:Send({"AUTH", options.password}, function()
        db:Log("Connected!")
    end)
end

function db:validateSchema(schema)
end

function db:get(schema, identity, callback)
    return redis:Send({"GET", identity}, callback)
end

function db:filter(schema, filter, callback)
    error("Filter not available on rediscore database driver")
end

function db:find(schema, filter, callback)
    error("Find not available on rediscore database driver")
end

function db:update(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to insert using rediscore driver")
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
    return redis:Send({"DEL", identity}, callback)
end

function db:insert(schema, object, callback)
    local identity = object[schema.Identity]

    if not identity then
        error("You should populate the identity to insert using rediscore driver")
    end

    return redis:Send({"SET", identity, object}, callback)
end

return db