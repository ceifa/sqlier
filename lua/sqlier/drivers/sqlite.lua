local db = {}

local function filterQuery(table, filter)
    local query = "SELECT * FROM `" .. table .. "`"

    if filter then
        query = query .. " WHERE "

        for key, value in pairs(filter) do
            query = query .. "`" .. key .. "` = " .. sql.SQLStr(value) .. " AND "
        end

        query = query:sub(1, -6)
    end

    return query
end

-- Pure SQL builders, shared between the direct methods and transactions.
local function buildSet(schema, object, separator)
    local clause = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            clause = clause .. "`" .. key .. "` = " .. sql.SQLStr(value) .. separator
        end
    end

    return clause:sub(1, -(#separator + 1))
end

local function buildWhere(schema, filter)
    local clause = ""

    for key, value in pairs(filter) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            clause = clause .. "`" .. key .. "` = " .. sql.SQLStr(value) .. " AND "
        end
    end

    return clause:sub(1, -6)
end

local function buildUpdate(schema, object)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = " .. sql.SQLStr(value)
            else
                keyValues = keyValues .. "`" .. key .. "`" .. " = " .. sql.SQLStr(value) .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    return string.format("UPDATE `%s` SET %s WHERE %s", schema.Table, keyValues, where)
end

local function buildArithmetic(schema, object, operator)
    local where
    local keyValues = ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = " .. sql.SQLStr(value)
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

local function buildUpdateWhere(schema, setValues, whereFilter)
    return string.format("UPDATE `%s` SET %s WHERE %s",
        schema.Table, buildSet(schema, setValues, ", "), buildWhere(schema, whereFilter))
end

local function buildDelete(schema, identity)
    return string.format("DELETE FROM `%s` WHERE `%s` = %s", schema.Table, schema.Identity, sql.SQLStr(identity))
end

local function buildInsert(schema, object)
    local keys, values = "", ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            keys = keys .. "`" .. key .. "`" .. ", "
            values = values .. sql.SQLStr(value) .. ", "
        end
    end

    keys = keys:sub(1, -3)
    values = values:sub(1, -3)

    return string.format("INSERT INTO `%s`(%s) VALUES(%s)", schema.Table, keys, values)
end

-- Builds the SQL for one queued transaction operation (see sqlier.transaction).
local function buildStatement(op)
    if op.kind == "insert" then
        return buildInsert(op.model, op.object)
    elseif op.kind == "update" then
        return buildUpdate(op.model, op.object)
    elseif op.kind == "delete" then
        return buildDelete(op.model, op.identity)
    elseif op.kind == "increment" then
        return buildArithmetic(op.model, op.object, "+")
    elseif op.kind == "decrement" then
        return buildArithmetic(op.model, op.object, "-")
    end

    error("Unknown transaction operation '" .. tostring(op.kind) .. "'")
end

function db:initialize()
end

function db:validateSchema(schema)
    schema.NormalizedColumnsCache = {}

    for key in pairs(schema.Columns) do
        schema.NormalizedColumnsCache[string.lower(key)] = true
    end

    if sql.TableExists(schema.Table) then return end

    local query = "CREATE TABLE IF NOT EXISTS `" .. schema.Table .. "` ("

    for name, options in pairs(schema.Columns) do
        query = query .. "`" .. name .. "` "
        local type = options.Type

        if type == sqlier.Type.String then
            if options.MaxLength then
                type = "VARCHAR(" .. tostring(options.MaxLength) .. ")"
            end
        elseif type == sqlier.Type.SteamId64 then
            type = "CHAR(17)"
        end

        query = query .. type

        if name == schema.Identity then
            query = query .. " PRIMARY KEY"
        end

        if options.AutoIncrement then
            query = query .. " AUTOINCREMENT"
        end

        if type == sqlier.Type.Timestamp and name == "CreateTimestamp" then
            query = query .. " DEFAULT CURRENT_TIMESTAMP"
        elseif options.Default ~= nil then
            query = query .. " DEFAULT (" .. sql.SQLStr(options.Default, not isstring(options.Default)) .. ")"
        end

        query = query .. ", "
    end

    query = query:sub(1, -3) .. ")"

    self:query(query)

    if schema.Columns.UpdateTimestamp and schema.Columns.UpdateTimestamp.Type == sqlier.Type.Timestamp then
        sql.Query(string.format([[
            CREATE TRIGGER `%s` AFTER UPDATE ON `%s`
            BEGIN
                UPDATE `%s` SET `UpdateTimestamp` = CURRENT_TIMESTAMP WHERE `%s` = NEW.%s;
            END;
        ]], schema.Table .. "_UpdateTimestamp", schema.Table, schema.Table, schema.Identity, schema.Identity))
    end
end

function db:query(query, callback)
    self:log(query)

    local result = sql.Query(query)

    if result == false then
        self:logError("Error in query: " .. query .. " ~ Error: " .. sql.LastError())
    end

    if callback then
        callback(result)
    end
end

function db:get(schema, identity, callback)
    db:find(schema, { [schema.Identity] = identity }, callback)
end

function db:filter(schema, filter, callback)
    self:query(filterQuery(schema.Table, filter), callback)
end

function db:find(schema, filter, callback)
    self:query(filterQuery(schema.Table, filter) .. " LIMIT 1", function(res)
        callback(res and res[1])
    end)
end

function db:update(schema, object, callback)
    self:query(buildUpdate(schema, object))

    if isfunction(callback) then
        callback()
    end
end

-- Conditional update returning the number of affected rows.
function db:updateWhere(schema, setValues, whereFilter, callback)
    self:query(buildUpdateWhere(schema, setValues, whereFilter))

    if isfunction(callback) then
        callback(tonumber(sql.QueryValue("SELECT changes()")) or 0)
    end
end

function db:increment(schema, object, callback)
    self:query(buildArithmetic(schema, object, "+"))

    if isfunction(callback) then
        callback()
    end
end

function db:decrement(schema, object, callback)
    self:query(buildArithmetic(schema, object, "-"))

    if isfunction(callback) then
        callback()
    end
end

function db:delete(schema, identity, callback)
    self:query(buildDelete(schema, identity))

    if isfunction(callback) then
        callback(identity)
    end
end

function db:insert(schema, object, callback)
    self:query(buildInsert(schema, object))

    if isfunction(callback) then
        callback(sql.QueryValue("SELECT last_insert_rowid()"))
    end
end

-- Runs queued operations atomically (all-or-nothing).
-- callback(success, results) where results[i] holds the per-statement
-- data / affectedRows / lastInsert. On any error the whole batch rolls back.
function db:transaction(operations, callback)
    sql.Query("BEGIN")

    local results = {}
    local failure

    for index, op in ipairs(operations) do
        local result = sql.Query(buildStatement(op))

        if result == false then
            failure = sql.LastError()
            break
        end

        local entry = { data = result }

        -- Only fetch the metadata each operation can actually produce.
        if op.kind == "insert" then
            entry.lastInsert = tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
        else
            entry.affectedRows = tonumber(sql.QueryValue("SELECT changes()"))
        end

        results[index] = entry
    end

    if failure then
        sql.Query("ROLLBACK")
        self:logError("Transaction failed (rolled back): " .. tostring(failure))
        if isfunction(callback) then callback(false, failure) end
    else
        sql.Query("COMMIT")
        if isfunction(callback) then callback(true, results) end
    end
end

return db
