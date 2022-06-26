local use_experimental_promises = CreateConVar("sqlier_experimental_promises_decorator", false, FCVAR_ARCHIVE,
    "Use experimental promises decorator")

if not use_experimental_promises:GetBool() then
    return false
end

local PENDING = 0
local RESOLVED = 1
local REJECTED = -1

local promise = {}
promise.__index = promise

function promise:__call(callback)
    local instance = {}
    instance._state = PENDING
    instance._handlers = {}
    setmetatable(instance, promise)

    local safe, args = pcall(function()
        callback(function(res)
            self:_resolve(res)
        end, function(err)
            self:_reject(err)
        end)
    end)

    if not safe then
        self:_reject(args)
    end

    return self
end

function promise:_resolve(response)
    if not self:isPending() then
        return
    end

    local safe, args = pcall(function()
        if getmetatable(response) == promise then
            response:next(function(inner_response)
                self:_resolve(inner_response)
            end, function(err)
                self:_reject(err)
            end)
        else
            self._state = RESOLVED
            self._value = response

            for i, handler in ipairs(self._handlers) do
                handler.onresolve(response)
            end
        end
    end)

    if not safe then
        self:_reject(args)
    end
end

function promise:_reject(err)
    if not self:isPending() then
        return
    end

    self._state = REJECTED
    self._value = err

    for i, handler in ipairs(self._handlers) do
        handler.onreject(err)
    end
end

function promise:isPending()
    return self._state == PENDING
end

function promise:isResolved()
    return self._state == RESOLVED
end

function promise:isRejected()
    return self._state == REJECTED
end

function promise:done(onresolve, onreject)
    onresolve = onresolve or function()
    end
    onreject = onreject or function()
    end

    timer.Simple(0, function()
        if self:isPending() then
            table.insert(self._handlers, {
                onresolve = onresolve,
                onreject = onreject
            })
        elseif self:isResolved() then
            onresolve(self._value)
        else
            onreject(self._value)
        end
    end)
end

function promise:next(onresolve, onreject)
    return promise(function(resolve, reject)
        self:done(function(res)
            if isfunction(onresolve) then
                local safe, args = pcall(function()
                    resolve(onresolve(res))
                end)

                if not safe then
                    reject(args)
                end
            else
                resolve(res)
            end
        end, function(err)
            if isfunction(onreject) then
                local safe, args = pcall(function()
                    resolve(onreject(err))
                end)

                if not safe then
                    reject(args)
                end
            else
                reject(err)
            end
        end)
    end)
end

function promise:catch(onreject)
    return self:next(nil, onreject)
end

function promise:__tostring()
    if self:isPending() then
        return "promise: pending"
    elseif self:isResolved() then
        return "promise: fulfilled (" .. tostring(self._value) .. ")"
    else
        return "promise: rejected (" .. tostring(self._value) .. ")"
    end
end

function sqlier.ModelBase:get(identity, callback)
    if not callback then
        return promise(function(resolve)
            self:get(identity, resolve)
        end)
    else
        self:get(identity, callback)
    end
end

function sqlier.ModelBase:find(filter, callback)
    if not callback then
        return promise(function(resolve)
            self:find(filter, resolve)
        end)
    else
        self:find(filter, callback)
    end
end

function sqlier.ModelBase:filter(filter, callback)
    if not callback then
        return promise(function(resolve)
            self:filter(filter, resolve)
        end)
    else
        self:filter(filter, callback)
    end
end

function sqlier.InstanceBase:save(callback)
    if not callback then
        return promise(function(resolve)
            self:save(resolve)
        end)
    else
        self:save(callback)
    end
end

function sqlier.InstanceBase:delete(callback)
    if not callback then
        return promise(function(resolve)
            self:delete(resolve)
        end)
    else
        self:delete(callback)
    end
end
