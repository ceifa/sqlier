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

function sqlier.ModelBase:updateWhereAsync(setValues, whereFilter)
    return util.Promise(function(resolve, reject)
        self:updateWhere(setValues, whereFilter, resolve)
    end)
end

-- Resolves with the per-statement results on commit, rejects with the error on
-- rollback.
function sqlier.transactionAsync(buildFn)
    return util.Promise(function(resolve, reject)
        sqlier.transaction(buildFn, function(success, results)
            if success then
                resolve(results)
            else
                reject(results)
            end
        end)
    end)
end