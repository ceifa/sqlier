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

function dataflow:process(args)
    self.ConcurrentActions = self.ConcurrentActions + 1
    local callback = isfunction(args[#args]) and table.remove(args)

    self.Action(unpack(args), function(...)
        if callback then
            callback(...)
        end

        self.ConcurrentActions = self.ConcurrentActions - 1
        self:processNext()
    end)
end

function dataflow:processNext()
    local nextArgs = self:dequeue()
    if nextArgs then
        self:process(nextArgs)
    end
end

function dataflow:start()
    self.Started = true
    self:processNext()
end

function dataflow:dequeue()
    if #self.Queue > 0 then
        local nextArgs = table.remove(self.Queue, 1)
        return nextArgs
    end
end

function dataflow:enqueue(...)
    if self.Started and (self.MaxDegree == 0 or self.ConcurrentActions < self.MaxDegree) then
        self:process({...})
    else
        table.insert(self.Queue, {...})
    end
end

return dataflow.new