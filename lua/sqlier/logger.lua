local logger = {
    Error = 1,
    Debug = 2,
    Trace = 3
}

-- 0 to disable, 1 for errors only, 2 for debug, 3 for traces
local log_severity = CreateConVar("sqlier_logs", 1, FCVAR_NONE, "<0/1/2/3> - Logs severity", 0, 3)

function logger:log(prefix, log, severity)
    severity = severity or self.Debug

    local enabledSeverity = log_severity:GetInt()

    if severity <= enabledSeverity then
        log = string.format("[%s] %s", string.upper(prefix), log)

        if enabledSeverity == 3 then
            log = log .. "\n" .. debug.traceback()
        end

        if severity == 1 then
            file.Append("sqlier/errors.txt", log)
        end

        if hook.Run("SqlierLog", log, severity, enabledSeverity) ~= false then
            print(log)
        end
    end
end

return logger