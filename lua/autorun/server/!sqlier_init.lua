module("sqlier", package.seeall)

Type = {}
Type.String = "STRING"
Type.Integer = "INTEGER"
Type.Float = "FLOAT"
Type.SteamId64 = "STEAMID64"
Type.Bool = "BOOLEAN"
Type.Date = "DATE"
Type.DateTime = "DATETIME"
Type.Timestamp = "TIMESTAMP"

-- 0 to disable, 1 for errors only, 2 for debug, 3 for traces
LogSeverity = CreateConVar("sqlier_logs", 1, FCVAR_NONE, "<0/1/2/3> - Logs severity", 0, 3)

Database = {}

function Initialize(database, driver, options)
    local db = include("sqlier/drivers/" .. driver .. ".lua")
    db.__index = db

    function db:Log(log, isError)
        local enabledSeverity = sqlier.LogSeverity:GetInt()

        if enabledSeverity > 0 and (isError or enabledSeverity > 1) then
            log = string.format("[%s] %s", string.upper(driver), log)

            if enabledSeverity == 3 then
                log = log .. "\n" .. debug.traceback()
            end

            if isError then
                file.Append("sqlier/errors.txt", log)
            end

            if hook.Run("SqlierLog", log, isError, enabledSeverity) ~= false then
                print(log)
            end
        end
    end

    function db:LogError(log)
        self:Log(log, true)
    end

    db:initialize(options)
    db.Driver = driver

    Database[database] = db
end


local model_base = include("sqlier/model_base.lua")

function Model(props)
    local model = model_base.Model(props)
    model:__validate()
    return model
end

do
    if not file.IsDir("sqlier", "DATA") then
        file.CreateDir("sqlier")
    end

    local files, _ = file.Find("sqlier/database/*.json", "DATA")

    for _, name in pairs(files) do
        local databaseConfigJson = file.Read("sqlier/database/" .. name)
        local databaseConfig = util.JSONToTable(databaseConfigJson)
        local database = string.StripExtension(name)

        Initialize(database, databaseConfig.driver, databaseConfig)
    end
end