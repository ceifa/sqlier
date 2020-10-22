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

Database = {}
ModelBase = include("sqlier/model_base.lua")
InstanceBase = include("sqlier/instance_base.lua")
Logger = include("sqlier/logger.lua")

function Initialize(database, driver, options)
    local db = include("sqlier/drivers/" .. driver .. ".lua")
    db.__index = db

    function db:Log(log, severity)
        Logger:Log(driver, log, severity)
    end

    function db:LogError(log)
        Logger:Log(driver, log, Logger.Error)
    end

    db:initialize(options)
    db.Driver = driver

    Database[database] = db
end

function Model(props)
    local model = ModelBase.Model(props)
    model:__validate()
    return model
end

do
    if not file.IsDir("sqlier", "DATA") then
        file.CreateDir("sqlier")
    end

    local files = file.Find("sqlier/database/*.json", "DATA")

    for _, name in pairs(files) do
        local databaseConfigJson = file.Read("sqlier/database/" .. name)
        local databaseConfig = util.JSONToTable(databaseConfigJson)
        local database = string.StripExtension(name)

        Initialize(database, databaseConfig.driver, databaseConfig)
    end
end