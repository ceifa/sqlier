local db = {}

function db:initialize()
end

function db:validateSchema(table, columns, identity)
end

function db:get(table, identityKey, identity, callback)
end

function db:filter(table, filter, callback)
end

function db:find(table, filter, callback)
end

function db:update(table, identityKey, object)
end

function db:delete(table, identityKey, identity)
end

function db:insert(table, identityKey, object)
end

return db