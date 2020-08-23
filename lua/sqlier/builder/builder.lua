local context = {}

function context.new(database, table)
    local newContext = setmetatable({}, context)
    newContext.Database = database
    newContext.Table = table

    return newContext
end

function context:select(...)
    local columns = {...}

    if #columns > 0 then
        self.Select = columns
    end

    return self
end

function context:insert(obj)
    self.Insert = obj
    return self
end

function context:update(obj)
    self.Update = obj
    return self
end

function context:delete()
    self.Delete = true
    return self
end

function context:run()
    if not self.Insert and not self.Update and not self.Delete then
        self.Select = {"*"}
    end

    return self.Database:run(self, callback)
end

function sqlier.QueryContext(database, table)
    return context.new(database, table)
end