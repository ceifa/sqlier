This project aims to offer a way of writing one only code and be able to switch between multiple database drivers without problems. The most easier and lightweight database abstraction of the market!

> Alert: This project will not fill all the database cases and not aims to fill.

## Usage

### Setup a database

Firstly you will need to setup your databases, you can do it in two ways.

The first way is calling the initilizer function `sqlier.Initialize`, it accepts three arguments:

1. Name, it's just a name to identify your database, it can be anything

2. Driver, available options are: `sqlite`, `mysqloo`, `file`

3. Options, the only one currently using it is the `mysqloo` driver, where you need to pass the database connection details

```
sqlier.Initialize("db1", "sqlite")
```

The second way is creating a json file inside the `data/sqlier/database` directory:

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
        CreateDate = {
            Type = sqlier.Type.Date
        },
        UpdateDate = {
            Type = sqlier.Type.Date
        }
    },
    Identity = "Id"
})
```

The columns `CreateDate` and `UpdateDate` are hard-coded internally populated automatically.

Available data types are:

```lua
sqlier.Type.String
sqlier.Type.Integer
sqlier.Type.Float
sqlier.Type.SteamId64
sqlier.Type.Bool
sqlier.Type.Date
sqlier.Type.DateTime
```

### Instantiate, update and delete a model

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