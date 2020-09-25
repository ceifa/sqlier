local db = {}
local connection

require("mysqloo")

function db:initialize(options)
    connection = mysqloo.connect(options.address, options.user, options.password, options.database, options.port)

    function connection:onConnected()
        db:Log("Connected!")
    end

    function connection:onConnectionFailed(err)
        db:LogError("Connection Failed, please check your settings: ", err)
    end

    connection:connect()
end

function db:validateSchema(schema)
    schema.NormalizedColumnsCache = {}

    for key in pairs(schema.Columns) do
        schema.NormalizedColumnsCache[string.lower(key)] = true
    end

    local query = "CREATE TABLE IF NOT EXISTS `" .. schema.Table .. "` ("

    for name, options in pairs(schema.Columns) do
        query = query .. "`" .. name .. "` "
        local type = options.Type

        if type == sqlier.Type.String then
            if options.MaxLenght then
                type = "VARCHAR(" .. tostring(math.min(16383, options.MaxLenght)) .. ")"
            else
                type = "TEXT"
            end
        elseif type == sqlier.Type.SteamId64 then
            type = "CHAR(17)"
        end

        query = query .. type

        if name == schema.Identity then
            query = query .. " PRIMARY KEY"
        end

        if options.AutoIncrement then
            query = query .. " AUTO_INCREMENT"
        end

        if type == sqlier.Type.Timestamp and name == "CreateTimestamp" then
            query = query .. " DEFAULT CURRENT_TIMESTAMP"
        elseif type == sqlier.Type.Timestamp and name == "UpdateTimestamp" then
            query = query .. " DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
        elseif options.Default ~= nil then
            query = query .. " DEFAULT (" .. sql.SQLStr(options.Default, not isstring(options.Default)) .. ")"
        end

        if next(schema.Columns, name) == nil then
            query = query .. ")"
        else
            query = query .. ", "
        end
    end

    self:query(query)
end

function db:query(query, callback)
    self:Log(query)

    local q = connection:query(query)

    q.onSuccess = function(s, data)
        if callback then
            callback(data)
        end
    end

    local tries = 0

    q.onError = function(s, err, usedQuery)
        if connection:status() ~= mysqloo.DATABASE_CONNECTED then
            connection:connect()
            connection:wait()

            if connection:status() ~= mysqloo.DATABASE_CONNECTED then
                self:LogError("Re-connection to database server failed.")
                if callback then
                    callback(false)
                end

                return
            end
        end

        self:LogError("Query Failed: " .. err .. "(" .. usedQuery .. ")\n")

        if tries < 3 then
            tries = tries + 1
            q:start()
        end
    end

    q:start()

    return q
end

function db:get(schema, identity, callback)
    db:find(schema, { [schema.Identity] = identity }, callback)
end

local function filterQuery(table, filter)
    local query = "SELECT * FROM `" .. table .. "`"

    if filter then
        query = query .. " WHERE "

        for key, value in pairs(filter) do
            query = query .. "`" .. key .. "` = '" .. connection:escape(value) .. "'"

            if next(filter, key) ~= nil then
                query = query .. " AND "
            end
        end
    end

    return query
end

function db:filter(schema, filter, callback)
    self:query(filterQuery(schema.Table, filter), callback)
end

function db:find(schema, filter, callback)
    self:query(filterQuery(schema.Table, filter) .. " LIMIT 1", function(res)
        callback(res and res[1])
    end)
end

function db:update(schema, object)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. connection:escape(value) .. "'"
            else
                keyValues = keyValues .. "`" .. key .. "`" .. " = '" .. connection:escape(value) .. "'"

                if next(object, key) ~= nil then
                    keyValues = keyValues .. ", "
                end
            end
        end
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self:query(string.format(query, schema.Table, keyValues, where))

    if isfunction(callback) then
        callback()
    end
end

function db:delete(schema, identity)
    local query = "DELETE FROM `%s` WHERE `%s` = '%s'"
    self:query(string.format(query, schema.Table, schema.Identity, connection:escape(identity)))

    if isfunction(callback) then
        callback(identity)
    end
end

function db:insert(schema, object)
    local keys, values = "", ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            keys = keys .. "`" .. key .. "`"
            values = values .. "'" .. connection:escape(value) .. "'"

            if next(object, key) ~= nil then
                keys = keys .. ", "
                values = values .. ", "
            end
        end
    end

    local query = "INSERT INTO `%s`(%s) VALUES(%s)"
    local q = self:query(string.format(query, schema.Table, keys, values))

    if isfunction(callback) then
        callback(q:lastInsert())
    end
end

return db
