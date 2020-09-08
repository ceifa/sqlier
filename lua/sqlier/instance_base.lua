local instance_base = {}
instance_base.__index = instance_base

function instance_base:save()
    if self.deleted and self:deleted() then
        error("Tried to update a deleted instance")
    end

    if self.CreateDate then
        self.model():update(self)
    else
        local identity = self[self.model().Identity]

        if identity then
            self.model():get(identity, function(item)
                if item then
                    self.model():update(self)
                else
                    self.model():insert(self)
                end
            end)
        else
            self.model():insert(self)
        end
    end
end

function instance_base:delete()
    self.model():delete(self[self.model.Identity])
    self.deleted = function()
        return true
    end
end

return instance_base