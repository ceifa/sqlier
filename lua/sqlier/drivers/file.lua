local db = {}

function db:initialize()
    if not file.IsDir("sqlier", "DATA") then
        file.CreateDir("sqlier")
    end
end

function db:validateSchema(table, columns, identity)
    if not file.IsDir("sqlier/" .. table, "DATA") then
        file.CreateDir("sqlier/" .. table)
    end
end

function db:get(schema, identity, callback)
    local content = file.Read("sqlier/" .. table .. "/" .. identity .. ".json")
    callback(content and util.JSONToTable(content))
end

function db:filter(schema, filter, callback)
    error("Filter not available on file system database driver")
end

function db:find(schema, filter, callback)
    error("Find not available on file system database driver")
end

function db:update(schema, object)
    self:get(schema, object[identityKey], function(res)
        for key, value in pairs(object) do
            res[key] = value
        end

        db:insert(schema, object)
    end)
end

function db:delete(schema, identity)
    file.Delete("sqlier/" .. table .. "/" .. identity .. ".json")
end

function db:insert(schema, object)
    file.Write("sqlier/" .. table .. "/" .. object[identityKey] .. ".json", util.TableToJSON(object))
end

return db