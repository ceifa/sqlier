if CLIENT then return end

module("sqlier", package.seeall)

Type = {
    String = "STRING",
    Integer = "INTEGER",
    Float = "FLOAT",
    SteamId64 = "STEAMID64",
    Bool = "BOOLEAN",
    Date = "DATE",
    DateTime = "DATETIME",
    Timestamp = "TIMESTAMP",
    Color = "COLOR"
}

Database = {}
Logger = include("sqlier/logger.lua")
ModelBase = include("sqlier/model_base.lua")
InstanceBase = include("sqlier/instance_base.lua")

function Initialize(database, driver, options)
    local db = include("sqlier/drivers/" .. driver .. ".lua")
    db.__index = db

    function db:log(log, severity)
        Logger:log(driver, log, severity)
    end

    function db:logError(log)
        Logger:log(driver, log, Logger.Error)
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

    for _, name in SortedPairsByValue(files) do
        local database = string.StripExtension(name)
        Logger:log("LOADER", "Loading database " .. database)

        local databaseConfigJson = file.Read("sqlier/database/" .. name)
        local databaseConfig = util.JSONToTable(databaseConfigJson)

        Initialize(database, databaseConfig.driver, databaseConfig)
    end
end
