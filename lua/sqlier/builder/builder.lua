local context = {}

function context.new(database, table)
    local newContext = setmetatable({}, context)
    newContext.Database = database
    newContext.Table = table

    return newContext
end

function context:select(...)
    local columns = {...}

    if #columns == 0 then
        self.Select = {"*"}
    else
        self.Select = columns
    end

    return self
end

function context:update()
end

function context:insert_update(obj)
    self.Object = obj

    return self
end

function context:delete()
    self.Delete = true

    return self
end

function context:run(callback)
    if not self.Delete and not self.Object then
        self:select()
    end

    return self.Database:run(self, callback)
end

function sqlier.QueryContext(database, table)
    return context.new(database, table)
end