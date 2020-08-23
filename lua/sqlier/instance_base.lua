local instance_base = {}

function instance_base:save()
    self.model:update(self)
end

function instance_base:delete()
    self.model:delete(self[self.model.Identity])
end

return instance_base