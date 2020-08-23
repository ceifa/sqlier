local db = {}

function db:initialize()
end

function db:validateSchema(table, columns, identity)
    if sql.TableExists(table) then return end
    local query = "CREATE TABLE IF NOT EXISTS `" .. table .. "` ("

    for name, options in pairs(columns) do
        query = query .. "`" .. name .. "` "
        type = options.Type

        if type == sqlier.StringType then
            if options.MaxLenght and isnumber(options.MaxLenght) then
                type = "VARCHAR(" .. tostring(options.MaxLenght) .. ")"
            end
        elseif type == sqlier.SteamIdType then
            type = "BIGINT"
        end

        query = query .. type

        if name == identity then
            query = query .. " PRIMARY KEY"
        end

        if options.AutoIncrement then
            query = query .. "AUTOINCREMENT"
        end

        query = query .. ", "
    end

    self:query(query)
end

function db:query(query, callback)
    local result = sql.Query(query)

    if result == false then
        error("Error in query: " .. query .. " ~ Error: " .. sql.LastError())
    end

    if callback then
        callback(result)
    end
end

function db:get(table, identityKey, identity, callback)
    local query = "SELECT * FROM `%s` WHERE %s = %s"
    self:query(string.format(query, table, identityKey, sql.SQLStr(identity)), callback)
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

function db:filter(table, filter, callback)
    self:query(filterQuery(table, filter), callback)
end

function db:find(table, filter, callback)
    self:query(filterQuery(table, filter) .. " LIMIT 1", function(res)
        callback(res and res[1])
    end)
end

function db:update(table, object)
end

function db:delete(table, identityKey, identity)
    local query = "DELETE FROM `%s` WHERE %s = %s"
    self:query(string.format(query, table, identityKey, sql.SQLStr(identity)))
end

function db:insert(object)
end

return db