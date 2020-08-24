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

function db:get(table, identityKey, identity, callback)
    local content = file.Read("sqlier/" .. table .. "/" .. identity .. ".json")
    callback(content and util.JSONToTable(content))
end

function db:filter(table, filter, callback)
    error("Filter not available on file system database driver")
end

function db:find(table, filter, callback)
    error("Find not available on file system database driver")
end

function db:update(table, identityKey, object)
    self:get(table, identityKey, object[identityKey], function(res)
        for key, value in pairs(object) do
            res[key] = value
        end

        db:insert(table, identityKey, object)
    end)
end

function db:delete(table, identityKey, identity)
    file.Delete("sqlier/" .. table .. "/" .. identity .. ".json")
end

function db:insert(table, identityKey, object)
    file.Write("sqlier/" .. table .. "/" .. object[identityKey] .. ".json", util.TableToJSON(object))
end

return db