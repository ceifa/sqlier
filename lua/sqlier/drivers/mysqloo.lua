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

-- Pure SQL builders, shared between the direct (Dataflow) methods and transactions.
local function buildSet(connection, schema, object, separator)
    local clause = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            clause = clause .. "`" .. key .. "` = '" .. escape(connection, value) .. "'" .. separator
        end
    end

    return clause:sub(1, -(#separator + 1))
end

local function buildWhere(connection, schema, filter)
    local clause = ""

    for key, value in pairs(filter) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            clause = clause .. "`" .. key .. "` = '" .. escape(connection, value) .. "' AND "
        end
    end

    return clause:sub(1, -6)
end

local function buildUpdate(connection, schema, object)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. escape(connection, value) .. "'"
            else
                keyValues = keyValues .. "`" .. key .. "`" .. " = '" .. escape(connection, value) .. "'" .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    return string.format("UPDATE `%s` SET %s WHERE %s", schema.Table, keyValues, where)
end

local function buildArithmetic(connection, schema, object, operator)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = '" .. escape(connection, value) .. "'"
            elseif isnumber(value) then
                keyValues = keyValues .. "`" .. key .. "`" .. " = `" .. key .. "` " .. operator .. " " .. value .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    return string.format("UPDATE `%s` SET %s WHERE %s", schema.Table, keyValues, where)
end

local function buildUpdateWhere(connection, schema, setValues, whereFilter)
    return string.format("UPDATE `%s` SET %s WHERE %s",
        schema.Table, buildSet(connection, schema, setValues, ", "), buildWhere(connection, schema, whereFilter))
end

local function buildDelete(connection, schema, identity)
    return string.format("DELETE FROM `%s` WHERE `%s` = '%s'", schema.Table, schema.Identity, escape(connection, identity))
end

local function buildInsert(connection, schema, object)
    local keys, values = "", ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            keys = keys .. "`" .. key .. "`" .. ", "
            values = values .. "'" .. escape(connection, value) .. "'" .. ", "
        end
    end

    keys = keys:sub(1, -3)
    values = values:sub(1, -3)

    return string.format("INSERT INTO `%s`(%s) VALUES(%s)", schema.Table, keys, values)
end

-- Builds the SQL for one queued transaction operation (see sqlier.transaction).
local function buildStatement(connection, op)
    if op.kind == "insert" then
        return buildInsert(connection, op.model, op.object)
    elseif op.kind == "update" then
        return buildUpdate(connection, op.model, op.object)
    elseif op.kind == "delete" then
        return buildDelete(connection, op.model, op.identity)
    elseif op.kind == "increment" then
        return buildArithmetic(connection, op.model, op.object, "+")
    elseif op.kind == "decrement" then
        return buildArithmetic(connection, op.model, op.object, "-")
    end

    error("Unknown transaction operation '" .. tostring(op.kind) .. "'")
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
            -- Pass the query object as the second argument so callers can read
            -- s:lastInsert() / s:affectedRows() (used by insert and updateWhere).
            callback(data, s)
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
    self.Dataflow:enqueue(buildUpdate(self.Connection, schema, object))

    if isfunction(callback) then
        callback()
    end
end

-- Conditional update returning the number of affected rows, e.g. an atomic claim
-- like "set buyer where the listing is still unsold".
function db:updateWhere(schema, setValues, whereFilter, callback)
    self.Dataflow:enqueue(buildUpdateWhere(self.Connection, schema, setValues, whereFilter), function(_, q)
        if isfunction(callback) then
            callback(q and q:affectedRows() or 0)
        end
    end)
end

function db:increment(schema, object, callback)
    self.Dataflow:enqueue(buildArithmetic(self.Connection, schema, object, "+"))

    if isfunction(callback) then
        callback()
    end
end

function db:decrement(schema, object, callback)
    self.Dataflow:enqueue(buildArithmetic(self.Connection, schema, object, "-"))

    if isfunction(callback) then
        callback()
    end
end

function db:delete(schema, identity, callback)
    self.Dataflow:enqueue(buildDelete(self.Connection, schema, identity))

    if isfunction(callback) then
        callback(identity)
    end
end

function db:insert(schema, object, callback)
    self.Dataflow:enqueue(buildInsert(self.Connection, schema, object), function(_, q)
        if isfunction(callback) then
            callback(q and q:lastInsert())
        end
    end)
end

-- Runs queued operations atomically (all-or-nothing) on a single connection.
-- callback(success, results) where results[i] holds the per-statement
-- data / affectedRows / lastInsert. On any error the whole batch rolls back.
function db:transaction(operations, callback)
    if self.Connection:status() ~= mysqloo.DATABASE_CONNECTED then
        self:logError("Cannot start a transaction while disconnected.")
        if isfunction(callback) then callback(false, "not connected") end
        return
    end

    local transaction = self.Connection:createTransaction()
    local queries = {}

    for index, op in ipairs(operations) do
        local query = self.Connection:query(buildStatement(self.Connection, op))
        queries[index] = query
        transaction:addQuery(query)
    end

    transaction.onSuccess = function()
        if not isfunction(callback) then return end

        local results = {}

        for index, query in ipairs(queries) do
            results[index] = {
                data = query:getData(),
                affectedRows = query:affectedRows(),
                lastInsert = query:lastInsert()
            }
        end

        callback(true, results)
    end

    transaction.onError = function(_, err)
        self:logError("Transaction failed (rolled back): " .. tostring(err))
        if isfunction(callback) then callback(false, err) end
    end

    transaction:start()
end

return db
