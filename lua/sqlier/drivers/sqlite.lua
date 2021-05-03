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
            query = query .. "AUTOINCREMENT"
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

    local query = "UPDATE `%s` SET %s WHERE %s"
    self:query(string.format(query, schema.Table, keyValues, where))

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
                where = "`" .. key .. "` = " .. sql.SQLStr(value)
            elseif isnumber(value) then
                keyValues = keyValues .. "`" .. key .. "`" .. " = `" .. key .. "` - " .. value .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self:query(string.format(query, schema.Table, keyValues, where))

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
                where = "`" .. key .. "` = " .. sql.SQLStr(value)
            elseif isnumber(value) then
                keyValues = keyValues .. "`" .. key .. "`" .. " = `" .. key .. "` - " .. value .. ", "
            end
        end
    end

    if #keyValues > 0 then
        keyValues = keyValues:sub(1, -3)
    end

    local query = "UPDATE `%s` SET %s WHERE %s"
    self:query(string.format(query, schema.Table, keyValues, where))

    if isfunction(callback) then
        callback()
    end
end

function db:delete(schema, identity, callback)
    local query = "DELETE FROM `%s` WHERE `%s` = %s"
    self:query(string.format(query, schema.Table, schema.Identity, sql.SQLStr(identity)))

    if isfunction(callback) then
        callback(identity)
    end
end

function db:insert(schema, object, callback)
    local keys, values = "", ""

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            keys = keys .. "`" .. key .. "`" .. ", "
            values = values .. sql.SQLStr(value) .. ", "
        end
    end

    keys = keys:sub(1, -3)
    values = values:sub(1, -3)

    local query = "INSERT INTO `%s`(%s) VALUES(%s)"
    self:query(string.format(query, schema.Table, keys, values))

    if isfunction(callback) then
        callback(sql.QueryValue("SELECT last_insert_rowid()"))
    end
end

return db
