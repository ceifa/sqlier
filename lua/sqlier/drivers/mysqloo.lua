local db = {}

function db:initialize()
end

function db:validateSchema(schema)
end

function db:get(schema, identity, callback)
end

function db:filter(schema, filter, callback)
end

function db:find(schema, filter, callback)
end

function db:update(schema, object)
end

function db:delete(schema, identity)
end

function db:insert(schema, object)
end

return db