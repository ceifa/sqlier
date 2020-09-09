local db = {}

function db:initialize()
end

function db:validateSchema(schema)
    if sql.TableExists(schema.Table) then return end
    local query = "CREATE TABLE IF NOT EXISTS `" .. schema.Table .. "` ("

    for name, options in pairs(schema.Columns) do
        query = query .. "`" .. name .. "` "
        local type = options.Type

        if type == sqlier.StringType then
            if options.MaxLenght and isnumber(options.MaxLenght) then
                type = "VARCHAR(" .. tostring(options.MaxLenght) .. ")"
            end
        elseif type == sqlier.SteamIdType then
            type = "BIGINT"
        end

        query = query .. type

        if name == schema.Identity then
            query = query .. " PRIMARY KEY"
        end

        if options.AutoIncrement then
            query = query .. "AUTOINCREMENT"
        end

        if type == sqlier.Type.Date and name == "CreateDate" then
            query = query .. " DEFAULT CURRENT_DATE"
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

    if schema.Columns.UpdateDate then
        sql.Query(string.format([[
            CREATE TRIGGER `%s` AFTER UPDATE ON `%s`
            BEGIN
                UPDATE `%s` SET `UpdateDate` = CURRENT_DATE WHERE `%s` = NEW.%s;
            END;
        ]], schema.Table .. "_UpdateDate", schema.Table, schema.Table, schema.Identity, schema.Identity))
    end
end

function db:query(query, callback)
    self:Log(query)

    local result = sql.Query(query)

    if result == false then
        self:LogError("Error in query: " .. query .. " ~ Error: " .. sql.LastError())
    end

    if callback then
        callback(result)
    end
end

function db:get(schema, identity, callback)
    db:find(schema, { [schema.Identity] = identity }, callback)
end

local function filterQuery(table, filter)
    local query = "SELECT * FROM `" .. table .. "`"

    if filter then
        query = query .. " WHERE "

        for key, value in pairs(filter) do
            query = query .. "`" .. key .. "` = " .. sql.SQLStr(value)

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

function db:update(schema, object, callback)
    local where
    local keyValues = ""

    if not schema.NormalizedColumnsCache then
        schema.NormalizedColumnsCache = {}

        for key in pairs(schema.Columns) do
            schema.NormalizedColumnsCache[string.lower(key)] = true
        end
    end

    for key, value in pairs(object) do
        if schema.NormalizedColumnsCache[string.lower(key)] then
            if key == schema.Identity then
                where = "`" .. key .. "` = " .. sql.SQLStr(value)
            else
                keyValues = keyValues .. "`" .. key .. "`" .. " = " .. sql.SQLStr(value)

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
        -- can be optimized
        local found = false
        for ckey in pairs(schema.Columns) do
            if string.lower(ckey) == string.lower(key) then
                found = true
            end
        end

        if found then
            keys = keys .. "`" .. key .. "`"
            values = values .. sql.SQLStr(value)

            if next(object, key) ~= nil then
                keys = keys .. ", "
                values = values .. ", "
            end
        end
    end

    local query = "INSERT INTO `%s`(%s) VALUES(%s)"
    self:query(string.format(query, schema.Table, keys, values))

    if isfunction(callback) then
        callback(sql.QueryValue("SELECT last_insert_rowid()"))
    end
end

return db