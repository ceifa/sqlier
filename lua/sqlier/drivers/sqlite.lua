local db = {}

function db:initialize()
end

function db:validateSchema(table, columns)
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

        if options.Unique then
            query = query .. "  UNIQUE"
        elseif options.PrimaryKey then
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

local function getWhereExpression(queryContext)
    local query

    for _, clause in ipairs(queryContext.Where) do
        if not query then
            query = "WHERE " .. clause.Field .. " " .. clause.Type .. " " .. sql.SQLStr(clause.Value)
        else
            if clause.Or then
                query = query .. " OR " .. clause.Field .. " " .. clause.Type .. " " .. sql.SQLStr(clause.Value)
            else
                query = query .. " AND " .. clause.Field .. " " .. clause.Type .. " " .. sql.SQLStr(clause.Value)
            end
        end
    end

    return query
end

function db:run(queryContext, callback)
    local query

    if queryContext.Select then
        query = "SELECT " .. table.concat(queryContext.Select, ", ") .. " FROM `" .. queryContext.Table .. "`"

        if queryContext.Where then
            query = query .. " " .. getWhereQuery(queryContext.Where)
        end

        if queryContext.GroupBy then
            query = query .. " GROUP BY " .. table.concat(queryContext.GroupBy, ", ")
        end

        if queryContext.OrderBy then
            query = query .. " ORDER BY " .. queryContext.OrderBy.Field

            if queryContext.OrderBy.Desc then
                query = query .. " DESC"
            end
        end

        if queryContext.Limit then
            query = query .. " LIMIT " .. queryContext.Limit
        end
    elseif queryContext.Delete then
        query = "DELETE FROM `" .. queryContext.Table .. "` " .. getWhereExpression(queryContext.Where)
    elseif queryContext.Object then
        local keys, values, keyValues = "", "", ""

        for key, value in pairs(queryContext.Object) do
            keys = keys .. "`" .. key
            values = values .. sql.SQLStr(value)
            keyValues = keyValues .. key .. " = " .. sql.SQLStr(value)

            if next(queryContext.Object, key) ~= nil then
                keys = keys .. ", "
                values = values .. ", "
                keyValues = keyValues .. ", "
            end
        end

        query = "INSERT OR IGNORE INTO `" .. queryContext.Table .. "`(" .. keys .. ") VALUES (" .. values .. ");"
        query = query .. "UPDATE `" .. queryContext.Table .. "` SET " .. keyValues
    end

    self:query(query, callback)
end

return db