--[[
	MeowyCore.Data: one database for all MeowyCore products.
	SQLite by default; MySQL through MySQLOO when configured.

	local db = MeowyCore.Data.Get("chat")
	db:Migrate({
		{ sqlite = "CREATE TABLE ...", mysql = "CREATE TABLE ..." },  -- version 1
		"CREATE INDEX ...",                                           -- version 2 (same SQL for both)
	}, function(ok, err) end)
	db:Query("SELECT * FROM mcore_chat_mutes WHERE steamid = ?", { sid }, function(rows, err, lastId) end)

	MySQL: create data/meowycore/database.json on the server:
		{ "driver": "mysqloo", "host": "127.0.0.1", "port": 3306,
		  "user": "...", "password": "...", "database": "..." }
	and install MySQLOO (lua/bin/gmsv_mysqloo_*.dll). Without both, SQLite is used.

	Callbacks are always asynchronous (SQLite results arrive on the next tick),
	so product code behaves the same on both drivers. "?" placeholders are
	replaced with escaped values; SQL text itself must not contain a literal "?".
]]

local Util = MeowyCore.Util
local Class = MeowyCore.Class
local Data = MeowyCore.Data or {}
MeowyCore.Data = Data

local log = MeowyCore.Log:Child("Data")

local CONFIG_FILE = "meowycore/database.json"
local RETRY_SECONDS = 30

-- Driver --------------------------------------------------------------------

local function readSettings()
	local raw = file.Read(CONFIG_FILE, "DATA")
	if not raw then return nil end
	local settings = util.JSONToTable(raw)
	if not settings then
		log:Error("data/%s is not valid JSON; using SQLite", CONFIG_FILE)
		return nil
	end
	return settings
end

local function escapeValue(value, escapeString)
	if value == nil then return "NULL" end
	if isbool(value) then return value and "1" or "0" end
	if isnumber(value) then
		if not Util.IsFinite(value) then error("cannot store a non-finite number", 3) end
		return tostring(value)
	end
	if isstring(value) then return escapeString(value) end
	error("unsupported SQL parameter type " .. Util.TypeOf(value), 3)
end

--- Replaces each "?" with the next escaped parameter.
function Data.Bind(sqlText, params, escapeString)
	params = params or {}
	local index, count = 0, 0
	local out = string.gsub(sqlText, "%?", function()
		index = index + 1
		count = count + 1
		return escapeValue(params[index], escapeString)
	end)
	local expected = 0
	for k in pairs(params) do
		if isnumber(k) and k > expected then expected = k end
	end
	if expected > count then
		error(string.format("SQL has %d placeholders but %d parameters", count, expected), 2)
	end
	return out
end

local function sqliteEscape(s)
	return sql.SQLStr(s)
end

Data.driver = Data.driver or nil       -- "sqlite" | "mysqloo"
Data.mysql = Data.mysql or nil         -- mysqloo database object
Data.queue = Data.queue or {}          -- queries waiting for the MySQL connection
Data.connected = Data.connected or false

local function runSqlite(sqlText, callback)
	local rows = sql.Query(sqlText)
	local err, lastId
	if rows == false then
		err = sql.LastError()
	else
		lastId = tonumber(sql.QueryValue("SELECT last_insert_rowid()"))
	end
	if callback then
		local result = nil
		if not err then result = rows or {} end
		timer.Simple(0, function() callback(result, err, lastId) end)
	end
end

local function runMysql(sqlText, callback)
	local q = Data.mysql:query(sqlText)
	function q:onSuccess(rows)
		if callback then callback(rows or {}, nil, self:lastInsert()) end
	end
	function q:onError(err)
		log:Error("MySQL query failed: %s", err)
		if callback then callback(nil, err) end
	end
	q:start()
end

local function flushQueue()
	local pending = Data.queue
	Data.queue = {}
	for _, item in ipairs(pending) do runMysql(item[1], item[2]) end
end

local function connectMysql(settings)
	local db = mysqloo.connect(settings.host or "127.0.0.1", settings.user or "", settings.password or "",
		settings.database or "", tonumber(settings.port) or 3306)
	function db:onConnected()
		Data.connected = true
		self:setCharacterSet("utf8mb4")
		log:Info("Connected to MySQL %s", self:serverInfo())
		flushQueue()
	end
	function db:onConnectionFailed(err)
		Data.connected = false
		log:Error("MySQL connection failed: %s (retrying in %ds)", err, RETRY_SECONDS)
		timer.Create("mcore_data_reconnect", RETRY_SECONDS, 1, function() db:connect() end)
	end
	Data.mysql = db
	db:connect()
end

--- Chooses the driver once per map load.
function Data.Init()
	if Data.driver then return end
	local settings = readSettings()
	if settings and settings.driver == "mysqloo" then
		local ok, err = pcall(require, "mysqloo")
		if ok and mysqloo then
			Data.driver = "mysqloo"
			connectMysql(settings)
			return
		end
		log:Error("database.json asks for MySQL but MySQLOO is not installed (%s); using SQLite", tostring(err))
	end
	Data.driver = "sqlite"
end

--- Escapes a string for the active driver (including quotes).
function Data.Escape(s)
	if Data.driver == "mysqloo" then
		return "'" .. Data.mysql:escape(s) .. "'"
	end
	return sqliteEscape(s)
end

--- Runs raw SQL with "?" parameters. callback(rows, err, lastInsertId).
function Data.Query(sqlText, params, callback)
	Data.Init()
	local final = Data.Bind(sqlText, params, Data.Escape)
	if Data.driver == "sqlite" then
		runSqlite(final, callback)
	elseif Data.connected then
		runMysql(final, callback)
	else
		table.insert(Data.queue, { final, callback })
	end
end

function Data.Driver()
	Data.Init()
	return Data.driver
end

-- Namespaced handle ---------------------------------------------------------

local Handle = Class.Define("MeowyCore.DataHandle", {
	fields = {
		namespace = { type = "string", maxLen = 64, check = function(v) return string.match(v, "^[%w_]+$") ~= nil, "letters, digits and _ only" end },
	},
})
Data.Handle = Handle

Data.handles = Data.handles or {}

--- Returns the handle for a namespace (one per product).
function Data.Get(namespace)
	local handle = Data.handles[namespace]
	if not handle then
		handle = Handle.New({ namespace = namespace })
		Data.handles[namespace] = handle
	end
	return handle
end

function Handle:Query(sqlText, params, callback)
	Data.Query(sqlText, params, callback)
end

function Handle:Driver()
	return Data.Driver()
end

local MIGRATIONS_TABLE = "CREATE TABLE IF NOT EXISTS mcore_migrations (ns VARCHAR(64) NOT NULL PRIMARY KEY, version INTEGER NOT NULL)"

--- Applies pending migrations in order. callback(ok, err, version).
--- Each step is a SQL string, or { sqlite = "...", mysql = "..." }.
local function migrationSql(item)
	if istable(item) then
		return Data.Driver() == "mysqloo" and item.mysql or item.sqlite
	end
	return item
end

local function runMigrationStep(ns, steps, i, callback)
	if i > #steps then
		callback(true, nil, #steps)
		return
	end
	local text = migrationSql(steps[i])
	if not isstring(text) then
		callback(false, string.format("%s migration %d has no SQL for %s", ns, i, Data.Driver()), i - 1)
		return
	end

	local function recorded(_, err)
		if err then callback(false, err, i - 1) return end
		log:Info("%s: applied migration %d", ns, i)
		runMigrationStep(ns, steps, i + 1, callback)
	end

	Data.Query(text, nil, function(_, err)
		if err then
			log:Error("%s migration %d failed: %s", ns, i, err)
			callback(false, err, i - 1)
			return
		end
		Data.Query("REPLACE INTO mcore_migrations (ns, version) VALUES (?, ?)", { ns, i }, recorded)
	end)
end

function Handle:Migrate(steps, callback)
	callback = callback or function() end
	local ns = self.namespace

	local function onVersion(rows, err)
		if err then callback(false, err) return end
		local current = (rows[1] and tonumber(rows[1].version)) or 0
		runMigrationStep(ns, steps, current + 1, callback)
	end

	Data.Query(MIGRATIONS_TABLE, nil, function(_, err)
		if err then callback(false, err) return end
		Data.Query("SELECT version FROM mcore_migrations WHERE ns = ?", { ns }, onVersion)
	end)
end
