local db = {}
local dataflowFactory = include("sqlier/drivers/helpers/dataflow.lua")

require("mysqloo")

local function escape(connection, value)
    if isstring(value) then
        return connection:escape(value)
    else
        return tostring(value)
    end
end

local function filterQuery(connection, table, filter)
    local query = "SELECT * FROM `" .. table .. "`"

    if filter then
        query = query .. " WHERE "

        for key, value in pairs(filter) do
            if isstring(value) then
                value = "'" .. escape(connection, value) .. "'"
            end

            query = query .. "`" .. key .. "` = " .. tostring(value) .. " AND "
        end

        query = query:sub(1, -6)
    end

    return query
end

function db:initialize(options)
    self.Connection = mysqloo.connect(options.address, options.user, options.password, options.database, options.port)

    function self.Connection:onConnected()
        db:log("Connected!")
        db.Dataflow:start()
    end

    function self.Connection:onConnectionFailed(err)
        db:logError("Connection Failed, please check your settings: ", err)
    end

    self.Dataflow = dataflowFactory()
    self.Dataflow:action(function(query, callback)
        self:query(query, callback)
    end)

    if options.queue == true then
        self.Dataflow:degreeOfParallelism(1)
    end

    self.MaxRetries = options.maxRetries or 3
    self.Connection:connect()
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
            if options.MaxLength then
                type = "VARCHAR(" .. tostring(math.min(16383, options.MaxLength)) .. ")"
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

        query = query .. ", "
    end

    query = query:sub(1, -3) .. ")"

    self.Dataflow:enqueue(query)
end

function db:query(query, callback)
    self:log("Querying: '" .. query .. "'")

    local q = self.Connection:query(query)

    q.onSuccess = function(s, data)
        if callback then
            callback(data)
        end
    end

    local tries = 0

    q.onError = function(s, err, usedQuery)
        if self.Connection:status() ~= mysqloo.DATABASE_CONNECTED then
            self.Connection:connect()
            self.Connection:wait()

            if self.Connection:status() ~= mysqloo.DATABASE_CONNECTED then
                self:logError("Re-connection to database server failed.")
                if callback then
                    callback(false)
                end

                return
            end
        end

        if usedQuery then
            self:logError("Query failed: " .. err .. "(" .. usedQuery .. ")")
        else
            self:logError(err)
        end

        if tries < self.MaxRetries then
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

function db:filter(schema, filter, callback)
    self.Dataflow:enqueue(filterQuery(self.Connection, schema.Table, filter), callback)
end

function db:find(schema, filter, callback)
    self.Dataflow:enqueue(filterQuery(self.Connection, schema.Table, filter) .. " LIMIT 1", function(res)
        callback(res and res[1])
    end)
end

function db:update(schema, object, callback)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. escape(self.Connection, value) .. "'"
            else
                keyValues = keyValues .. "`" .. key .. "`" .. " = '" .. escape(self.Connection, value) .. "'" .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self.Dataflow:enqueue(string.format(query, schema.Table, keyValues, where))

    if isfunction(callback) then
        callback()
    end
end

function db:increment(schema, object, callback)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. escape(self.Connection, value) .. "'"
            elseif isnumber(value) then
                keyValues = keyValues .. "`" .. key .. "`" .. " = `" .. key .. "` + " .. value .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self.Dataflow:enqueue(string.format(query, schema.Table, keyValues, where))

    if isfunction(callback) then
        callback()
    end
end

function db:decrement(schema, object, callback)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. escape(self.Connection, value) .. "'"
            elseif isnumber(value) then
                keyValues = keyValues .. "`" .. key .. "`" .. " = `" .. key .. "` - " .. value .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self.Dataflow:enqueue(string.format(query, schema.Table, keyValues, where))

    if isfunction(callback) then
        callback()
    end
end

function db:delete(schema, identity)
    local query = "DELETE FROM `%s` WHERE `%s` = '%s'"
    self.Dataflow:enqueue(string.format(query, schema.Table, schema.Identity, escape(self.Connection, identity)))

    if isfunction(callback) then
        callback(identity)
    end
end

function db:insert(schema, object)
    local keys, values = "", ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            keys = keys .. "`" .. key .. "`" .. ", "
            values = values .. "'" .. escape(self.Connection, value) .. "'" .. ", "
        end
    end

    keys = keys:sub(1, -3)
    values = values:sub(1, -3)

    local query = "INSERT INTO `%s`(%s) VALUES(%s)"
    local q = self.Dataflow:enqueue(string.format(query, schema.Table, keys, values))

    if isfunction(callback) then
        callback(q:lastInsert())
    end
end

return db
