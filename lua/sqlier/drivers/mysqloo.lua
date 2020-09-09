local db = {}

function db:initialize(options)
    connection = mysqloo.connect(options.address, options.user, options.password, options.database, options.port)

    function connection:onConnected()
        self:Log("Connected!")
    end

    function connection:onConnectionFailed(err)
        self:LogError("Connection Failed, please check your settings: ", err)
    end

    connection:connect()
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