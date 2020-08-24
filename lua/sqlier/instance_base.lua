local instance_base = {}

function instance_base:save()
    if self.deleted and self:deleted() then
        error("Tried to update a deleted instance")
    end

    self.model():update(self)
end

function instance_base:delete()
    self.model():delete(self[self.model.Identity])
    self.deleted = function()
        return true
    end
end

return instance_base