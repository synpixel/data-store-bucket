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
    print(pages:getCurrentPage()) -- an array of entries

    if pages.finished then
        break
    end

    pages:advanceToNextPage()
end

bucket:add(unpack(table.create(50, "foo"))) -- this will create 2 buckets because the maximum amount of entries is 25
bucket:add(unpack(table.create(50, "baz"))) -- this will create 2 buckets because the maximum amount of entries is 25

bucket:save() -- i advise you to only call this rarely (preferably once with :BindToClose) but this is for the sake of the example
```
