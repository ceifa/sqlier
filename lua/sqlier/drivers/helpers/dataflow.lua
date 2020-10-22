local dataflow = {}
dataflow.__index = dataflow

function dataflow.new()
    return setmetatable({
        ConcurrentActions = 0,
        MaxDegree = 0,
        Action = function() end,
        Queue = {}
    }, dataflow)
end

function dataflow:degreeOfParallelism(value)
    self.MaxDegree = value
end

function dataflow:action(action)
    self.Action = action
end

function dataflow:processNext(...)
    self.ConcurrentActions = self.ConcurrentActions + 1
    local args = {...}
    local callback = isfunction(args[#args]) and table.remove(args)

    self.Action(unpack(args), function(...)
        if callback then
            callback(...)
        end

        self.ConcurrentActions = self.ConcurrentActions - 1

        if #self.Queue > 0 then
            local next = table.remove(self.Queue, 1)
            self:processNext(unpack(next))
        end
    end)
end

function dataflow:enqueue(...)
    if self.MaxDegree == 0 or self.ConcurrentActions < self.MaxDegree then
        self:processNext(...)
    else
        table.insert(self.Queue, {...})
    end
end

return dataflow.new