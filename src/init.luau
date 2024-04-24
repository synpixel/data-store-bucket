export type DataStoreBucketConfiguration = {
	dataStore: DataStore,
	maxEntries: number,
}

export type BucketPages<T> = {
	cursor: string,
	finished: boolean,
	getCurrentPage: (self: BucketPages<T>) -> { T },
	advanceToNextPage: (self: BucketPages<T>) -> (),
}

type Bucket<T> = {
	entries: { T },
	nextCursor: string?,
}

local FIRST_BUCKET_CURSOR = "bucket_1"
local LATEST_BUCKET_CURSOR_KEY = "latest"
local DATA_KEYS = {
	nextCursor = "n",
	entries = "e",
}

local DataStoreBucket = {}

local function indexFromCursor(cursor: string): number
	return tonumber(cursor:match("(%d+)$")) :: number
end

local function incrementCursor(cursor: string, increment: number): string
	return "bucket_" .. indexFromCursor(cursor) + increment
end

local function getBucket<T>(dataStore: DataStore, cursor: string): Bucket<T>
	return dataStore:GetAsync(cursor, nil :: any)
		or dataStore:UpdateAsync(cursor, function(bucket)
			return {
				[DATA_KEYS.entries] = {},
				[DATA_KEYS.nextCursor] = nil,
			}
		end)
end

local function updateBucket<T>(dataStore: DataStore, cursor: string, newEntries: { T }, nextCursor: string?): Bucket<T>
	return dataStore:UpdateAsync(cursor, function(bucket)
		local entries = {}

		if bucket then
			for _, entry in bucket[DATA_KEYS.entries] do
				table.insert(entries, entry)
			end
		end

		for _, entry in newEntries do
			table.insert(entries, entry)
		end

		return {
			[DATA_KEYS.entries] = entries,
			[DATA_KEYS.nextCursor] = nextCursor,
		}
	end)
end

local function add<T>(self: DataStoreBucket<T>, ...: T)
	for _, entry in { ... } do
		table.insert(self._queue, entry)
	end
end

local function save<T>(self: DataStoreBucket<T>)
	if #self._queue <= 0 then
		return
	end

	local cursor, bucket: Bucket<T> = self._lastBucketCursor, getBucket(self._dataStore, self._lastBucketCursor)

	while bucket[DATA_KEYS.nextCursor] ~= nil do
		cursor = bucket[DATA_KEYS.nextCursor]
		bucket = self._dataStore:GetAsync(cursor, nil :: any)
	end

	if #bucket[DATA_KEYS.entries] >= self._maxEntries then
		local nextCursor = incrementCursor(cursor, 1)
		updateBucket(self._dataStore, cursor, {}, nextCursor)
		bucket = getBucket(self._dataStore, nextCursor)
		cursor = nextCursor
	end

	local chunks: { { T } } = { bucket[DATA_KEYS.entries] }

	while #self._queue > 0 do
		if #chunks[#chunks] >= self._maxEntries then
			table.insert(chunks, {})
		end

		local entry = self._queue[1]
		table.remove(self._queue, 1)
		table.insert(chunks[#chunks], entry)
	end

	for i, chunk in chunks do
		local nextCursor = incrementCursor(cursor, 1)
		updateBucket(self._dataStore, cursor, chunk, if i < #chunks then nextCursor else nil)

		if i < #chunks then
			cursor = nextCursor
		end
	end

	self._lastBucketCursor = cursor
	self._dataStore:UpdateAsync(LATEST_BUCKET_CURSOR_KEY, function(lastBucketCursor)
		if indexFromCursor(lastBucketCursor or FIRST_BUCKET_CURSOR) > indexFromCursor(cursor) then
			self._lastBucketCursor = lastBucketCursor
		end
		return self._lastBucketCursor
	end)
end

local function listEntries<T>(self: DataStoreBucket<T>): BucketPages<T>
	local dataStore = self._dataStore

	local pages = {}
	pages.cursor = FIRST_BUCKET_CURSOR
	pages.page = getBucket(dataStore, pages.cursor)
	pages.finished = pages.page[DATA_KEYS.nextCursor] == nil

	function pages:getCurrentPage()
		return pages.page[DATA_KEYS.entries]
	end

	function pages:advanceToNextPage()
		if pages.finished then
			error("no page to advance to")
		end

		pages.cursor = pages.page[DATA_KEYS.nextCursor]
		pages.page = getBucket(dataStore, pages.cursor)
		pages.finished = pages.page[DATA_KEYS.nextCursor] == nil
	end

	return pages
end

function DataStoreBucket.new<T>(config: DataStoreBucketConfiguration): DataStoreBucket<T>
	local self = {
		_dataStore = config.dataStore,
		_maxEntries = config.maxEntries,
		_queue = {},
		add = add,
		save = save,
		listEntries = listEntries,
	}

	self._lastBucketCursor = self._dataStore:GetAsync(LATEST_BUCKET_CURSOR_KEY) or FIRST_BUCKET_CURSOR

	return self
end

export type DataStoreBucket<T> = {
	_dataStore: DataStore,
	_maxEntries: number,
	_queue: { T },
	_lastBucketCursor: string,
	add: (self: DataStoreBucket<T>, ...T) -> (),
	save: (self: DataStoreBucket<T>) -> (),
	listEntries: (self: DataStoreBucket<T>) -> BucketPages<T>,
}

return DataStoreBucket
