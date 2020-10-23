local db = {}

function db:initialize(options)
    self.Source = sqlier.Database[options.source]
    self.Cache = sqlier.Database[options.cache]

    if not self.Source or not self.Cache then
        db:LogError("Source or cache database was not previously registered")
    end
end

function db:validateSchema(schema)
    self.Source:validateSchema(schema)
    self.Cache:validateSchema(schema)
end

function db:get(schema, identity, callback)
    self.Cache:find(schema, identity, function(cachedItem)
        if cachedItem then
            callback(cachedItem)
        else
            self.Source:find(schema, identity, function(item)
                if item then
                    -- caches the value asynchronously
                    self.Cache:insert(schema, item)
                end

                callback(item)
            end)
        end
    end)
end

function db:filter(schema, filter, callback)
    self.Source:filter(schema, filter, callback)
end

function db:find(schema, filter, callback)
    self.Source:find(schema, filter, callback)
end

function db:update(schema, object, callback)
    self.Source:update(schema, object, function()
        self.Cache:update(schema, object, callback)
    end)
end

function db:increment(schema, object, callback)
    self.Source:increment(schema, object, function()
        self.Cache:increment(schema, object, callback)
    end)
end

function db:decrement(schema, object, callback)
    self.Source:decrement(schema, object, function()
        self.Cache:decrement(schema, object, callback)
    end)
end

function db:delete(schema, identity, callback)
    self.Source:delete(schema, identity, function()
        self.Cache:delete(schema, identity, callback)
    end)
end

function db:insert(schema, object, callback)
    self.Source:insert(schema, object, function(identity)
        object[schema.Identity] = identity
        self.Cache:insert(schema, object, callback)
    end)
end

return db