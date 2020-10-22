do
    local logPrefix = "LOADER"

    local files = file.Find("sqlier/extensions/*.lua", "LUA")

    sqlier.Logger:Log(logPrefix, "Loading sqlier extensions", sqlier.Logger.Trace)

    for _, name in ipairs(files) do
        local loaded = include("sqlier/extensions/" .. name)

        sqlier.Logger:Log(logPrefix,
            (loaded == false and "Failed to load" or "Loaded") .. " extension " .. name,
            sqlier.Logger.Trace)
    end
end