function builder:orderBy(field, desc)
    self.OrderBy = {
        Field = field,
        Desc = desc
    }
    return self
end

function builder:limit(quantity)
    self.Limit = quantity
    return self
end

function builder:groupBy(...)
    self.GroupBy = {...}
    return self
end