module("sqlier", package.seeall)

Type = {}
Type.String = "STRING"
Type.Integer = "INTEGER"
Type.Float = "FLOAT"
Type.SteamId64 = "STEAMID64"
Type.Bool = "BOOLEAN"
Type.Date = "DATE"
Type.DateTime = "DATETIME"

ShouldLog = CreateConVar("sqlier_logs", 0, FCVAR_NONE, "Sqlier should log on console or not")

Database = {}

function Initialize(database, driver, options)
    local db = include("sqlier/drivers/" .. driver .. ".lua")
    db.__index = db

    function db:Log(log)
        if sqlier.ShouldLog:GetBool() then
            print(string.format("[%s], %s", string.upper(driver), log))
        end
    end

    function db:LogError(log)
        log = string.format("[%s], %s", string.upper(driver), log)

        ErrorNoHalt(log)
        file.Write("sqlier/errors.txt", log)
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