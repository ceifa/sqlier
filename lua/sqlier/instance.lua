local instance_base = {}

function instance_base:save()
    return self:model():context():insert_update(self):run()
end

setmetatable("ModelInstance", instance_base)