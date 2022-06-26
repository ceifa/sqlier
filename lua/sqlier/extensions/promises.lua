if not util.Promise then
    return false
end

function sqlier.ModelBase:getAsync(identity)
    return util.Promise(function(resolve, reject)
        self:get(identity, resolve)
    end)
end

function sqlier.ModelBase:findAsync(filter)
    return util.Promise(function(resolve, reject)
        self:find(filter, resolve)
    end)
end

function sqlier.ModelBase:filterAsync(filter)
    return util.Promise(function(resolve, reject)
        self:filter(filter, resolve)
    end)
end

function sqlier.InstanceBase:saveAsync()
    return util.Promise(function(resolve, reject)
        self:save(resolve)
    end)
end

function sqlier.InstanceBase:deleteAsync()
    return util.Promise(function(resolve, reject)
        self:delete(resolve)
    end)
end