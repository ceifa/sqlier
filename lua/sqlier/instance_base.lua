local instance_base = {}
instance_base.__index = instance_base

function instance_base:save(callback)
    if self.deleted and self:deleted() then
        error("Tried to update a deleted instance")
    end

    if self.CreateTimestamp then
        self.model():update(self, callback)
    else
        local identity = self[self.model().Identity]

        if identity then
            self.model():get(identity, function(item)
                if item then
                    self.model():update(self, callback)
                else
                    self.model():insert(self, callback)
                end
            end)
        else
            self.model():insert(self, function(createdId)
                if createdId then
                    self[self.model().Identity] = createdId
                end
                if isfunction(callback) then
                    callback(createdId)
                end
            end)
        end
    end
end

function instance_base:delete(callback)
    self.model():delete(self[self.model().Identity], callback)
    self.deleted = function()
        return true
    end
end

return instance_base
