do
    local files = file.Find("sqlier/extensions/*.lua", "LUA")

    sqlier.Logger:log("LOADER", "Loading sqlier extensions")

    for _, name in ipairs(files) do
        local loaded = include("sqlier/extensions/" .. name)

        sqlier.Logger:log("LOADER",
            (loaded == false and "Failed to load" or "Loaded") .. " extension " .. name,
            sqlier.Logger.Trace)
    end
end