function context:where(field)
    self.Where = self.Where or {}

    self.CurrentWhere = table.insert(self.Where, {
        Field = field
    })

    return self
end

function context:whereOr(field)
    self.CurrentWhere = table.insert(self.Where, {
        Field = field,
        Or = true
    })

    return self
end

function context:equal(value)
    context:__condition(sqlier.Where.Equal, value)

    return self
end

function context:notequal(value)
    context:__condition(sqlier.Where.NotEqual, value)

    return self
end

function context:like(value)
    context:__condition(sqlier.Where.Like, value)

    return self
end

function context:greaterThan(value)
    context:__condition(sqlier.Where.GreaterThan, value)

    return self
end

function context:lessThan(value)
    context:__condition(sqlier.Where.LessThan, value)

    return self
end

function context:greaterOrEqual(value)
    context:__condition(sqlier.Where.GreaterOrEqual, value)

    return self
end

function context:lessOrEqual(value)
    context:__condition(sqlier.Where.LessOrEqual, value)

    return self
end

function context:__condition(type, value)
    self.Where[self.CurrentWhere].Type = type
    self.Where[self.CurrentWhere].Value = value
end