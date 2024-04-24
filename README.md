# DataStoreBucket

DataStore library for bucketing data

## Example

```lua
local DataStoreService = game:GetService("DataStoreService")
local DataStoreBucket = require(...)

local bucket = DataStoreBucket.new({
    dataStore = DataStoreService:GetDataStore("bucket-example"),
    maxEntries = 25,
})

local pages = bucket:listEntries()

while true do
    print(pages:getCurrentPage())

    if pages.finished then
        break
    end

    pages:advanceToNextPage()
end

bucket:add(unpack(table.create(50, "foo")))
bucket:add(unpack(table.create(50, "baz")))

bucket:save() -- i advise you to only call this rarely (preferably once with :BindToClose) but this is for the sake of the example
```
