-- Builder handed to sqlier.transaction(fn, callback). It collects operations by
-- mirroring the model verbs (insert/update/delete/increment/decrement); the
-- collected list is then run atomically by the driver.
local transaction = {}
transaction.__index = transaction

function transaction.new()
    return setmetatable({ operations = {} }, transaction)
end

function transaction:insert(model, object)
    self.operations[#self.operations + 1] = { kind = "insert", model = model, object = object }
    return self
end

function transaction:update(model, object)
    self.operations[#self.operations + 1] = { kind = "update", model = model, object = object }
    return self
end

function transaction:increment(model, object)
    self.operations[#self.operations + 1] = { kind = "increment", model = model, object = object }
    return self
end

function transaction:decrement(model, object)
    self.operations[#self.operations + 1] = { kind = "decrement", model = model, object = object }
    return self
end

function transaction:delete(model, identity)
    self.operations[#self.operations + 1] = { kind = "delete", model = model, identity = identity }
    return self
end

return transaction
