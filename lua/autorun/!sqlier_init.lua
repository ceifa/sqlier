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
TransactionBuilder = include("sqlier/transaction.lua")

-- Runs the operations queued inside `buildFn` atomically (all-or-nothing). The
-- builder mirrors the model verbs, so no parallel "dialect" is needed:
--
--   sqlier.transaction(function(tx)
--       tx:insert(Item, { ... })
--       tx:decrement(Point, { ... })
--   end, function(success, results)
--       -- results[1].lastInsert
--   end)
--
-- All operations must target the same database (one connection). Drivers without
-- native transaction support degrade to sequential, non-atomic execution.
function transaction(buildFn, callback)
    local builder = TransactionBuilder.new()
    buildFn(builder)

    local operations = builder.operations

    if #operations == 0 then
        if isfunction(callback) then callback(true, {}) end
        return
    end

    local database = Database[operations[1].model.Database]

    if not database then
        error("sqlier.transaction: could not resolve a database from the queued operations")
    end

    if isfunction(database.transaction) then
        database:transaction(operations, callback)
        return
    end

    -- Fallback: run sequentially (not atomic) on drivers that lack transactions.
    for _, op in ipairs(operations) do
        if op.kind == "insert" then
            database:insert(op.model, op.object)
        elseif op.kind == "update" then
            database:update(op.model, op.object)
        elseif op.kind == "delete" then
            database:delete(op.model, op.identity)
        elseif op.kind == "increment" then
            database:increment(op.model, op.object)
        elseif op.kind == "decrement" then
            database:decrement(op.model, op.object)
        end
    end

    if isfunction(callback) then callback(true, {}) end
end

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
