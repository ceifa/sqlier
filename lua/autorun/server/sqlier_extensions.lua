local files = file.Find("sqlier/extensions/*.lua", "LUA")

sqlier.Logger:log("LOADER", "Loading sqlier extensions")

for _, name in ipairs(files) do
    local loaded = include("sqlier/extensions/" .. name)

    if loaded ~= false then
        sqlier.Logger:log("LOADER", "Loaded extension " .. name, sqlier.Logger.Debug)
    end
end
