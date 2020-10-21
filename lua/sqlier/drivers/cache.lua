local db = {}
local source, cache

function db:initialize(options)
    source = sqlier.Database[options.source]
    cache = sqlier.Database[options.cache]

    if not source or not cache then
        db:LogError("Source or cache database was not previously registered")
    end
end

function db:validateSchema(schema)
    source:validateSchema(schema)
    cache:validateSchema(schema)
end

function db:get(schema, identity, callback)
    cache:find(schema, identity, function(cachedItem)
        if cachedItem then
            callback(cachedItem)
        else
            source:find(schema, identity, function(item)
                if item then
                    -- caches the value asynchronously
                    cache:insert(schema, item)
                end

                callback(item)
            end)
        end
    end)
end

function db:filter(schema, filter, callback)
    source:filter(schema, filter, callback)
end

function db:find(schema, filter, callback)
    source:find(schema, filter, callback)
end

function db:update(schema, object, callback)
    source:update(schema, object, function()
        cache:update(schema, object, callback)
    end)
end

function db:delete(schema, identity, callback)
    source:delete(schema, identity, function()
        cache:delete(schema, identity, callback)
    end)
end

function db:insert(schema, object, callback)
    source:insert(schema, object, function(identity)
        object[schema.Identity] = identity
        cache:insert(schema, object, callback)
    end)
end

return db