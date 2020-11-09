Are you tired of these lots of heavy database libraries which do a lot of things which you don't need? You came at the right place! This project aims to offer a way of writing a very simple code only one time and be able to switch between multiple database drivers without problems. The most easier and lightweight database abstraction of the market!

> Alert: This project will not fill all the edge database cases and does not aim to do so.

## Usage

### Setup a database

Firstly you will need to setup your databases, you can do it in two ways.
#### First method: Initialize function
sqlier can be itnialized by running the initializer function `sqlier.Initialize(name, drive, conn)` which accepts the following arguments:

1. `STRING` `name`: Identification name for the database (can be anything)
2. `STRING` `driver`: The desired database driver, currently supports:
   - `sqlite`: Uses default [Garry's Mod Sqlite](https://wiki.facepunch.com/gmod/sql) interface
   - `mysqloo`: Uses the [Mysqloo Module](https://github.com/FredyH/MySQLOO) (provides MySQL interface)
   - `file`: Uses [plain files](https://wiki.facepunch.com/gmod/file_class) to read and store data
4. `optional` | `STRING` `Connection info`: Only needed when using MySqloo driver, passing the database authentication details.  

```lua
 -- Sqlite
sqlier.Initialize("db1", "sqlite")

 -- MySQL
sqlier.Initialize("db2", "mysqloo", { address = "localhost", port = "3306", database = "GmodServer", user = "root", password = "" })
```
#### Second method: Json config file
sqlier will also search for the `data/sqlier/database` directory:

* db2.json
```json
{
    "driver": "mysqloo",
    "address": "localhost",
    "port": "3306",
    "database": "GmodServer",
    "user": "root",
    "password": ""
}
```

### Setup a model

Now you will have to setup a model, it works like a class:

```lua
local User = sqlier.Model({
    Table = "user",
    Columns = {
        Id = {
            Type = sqlier.Type.Integer,
            AutoIncrement = true
        },
        Name = {
            Type = sqlier.Type.String
        },
        Rank = {
            Type = sqlier.Type.String,
            MaxLenght = 15
        },
        SteamId64 = {
            Type = sqlier.Type.SteamId64
        },
        CreateTimestamp = {
            Type = sqlier.Type.Timestamp
        }
    },
    Identity = "Id"
})
```

The columns `CreateTimestamp` and `UpdateTimestamp` are hard-coded internally populated automatically.

Available data types are:

```lua
sqlier.Type.String
sqlier.Type.Integer
sqlier.Type.Float
sqlier.Type.SteamId64
sqlier.Type.Bool
sqlier.Type.Date
sqlier.Type.DateTime
sqlier.Type.Timestamp
```

### Instantiate, update or delete a model

```lua
local new_user = User({
    Name = ply:Nick(),
    SteamId = ply:SteamId64(),
    Rank = "user"
})
new_user:save()

new_user.Rank = "donator"
new_user:save()

new_user:delete()

-- throw an error
new_user:save()
```

If you want to know when a save or delete is done, you can pass a callback or use their async api, if using `util.Promise`:

```lua
new_user:save(function()
    print("Save is done")
end)

util.PromiseAsync(function()
    new_user:saveAsync():Await()
    new_user:deleteAsync():Await()
end)
```

### Querying

We have some simple methods to do querying:

```lua
-- The fastest way, get by identity
User:get(2, function(user)
end)

-- Find one by property filtering
User:find({ Name = "ceifa" }, function(user)
end)

-- Get many by property filtering
User:filter({ Rank = "donator" }, function(users)
end)
```

If you have support for `util.Promise`, you can use the async methods:

```lua
util.PromiseAsync(function()
    local user = User:getAsync(2):Await()
    local user = User:findAsync({ Name = "ceifa" }):Await()
    local users = User:filterAsync({ Rank = "donator" }):Await()
end)
```

But if you want more complex queries, you will have to do it yourself:

```lua
local user_db = User:database()
if user_db.Driver == "sqlite" or user_db.Driver == "mysqloo" then
    user_db:query("SELECT Name, COUNT(*) as Quantity FROM user GROUP BY Name", function(names)
    end)
else
    error("Database driver not supported")
end
```

### Logs

To enable the querying logs, set the convar `sqlier_logs` to `1`. Error logs will always log at the console and to the `data/sqlier` folder, at the `errors.txt` file.
