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

    sql.Query(query)
end

function db:run(queryContext, callback)
end

return db