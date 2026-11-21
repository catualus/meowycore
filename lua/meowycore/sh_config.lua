--[[
	MeowyCore.Config: declared, validated, persisted settings.

	local cfg = MeowyCore.Config.Define("chat", {
		{ key = "maxLength", type = "number", default = 256, min = 16, max = 1024, integer = true, shared = true },
		{ key = "accent", type = "Color", default = Color(255, 140, 105), shared = true },
		{ key = "logMessages", type = "boolean", default = true },
	})
	cfg:Get("maxLength")
	cfg:Set("maxLength", 300)    -- server only: validates, saves, networks shared keys

	Saved to data/meowycore/config/<namespace>.json on the server.
	Keys marked shared = true are sent to clients (on join and on change).
	Keys marked consoleOnly = true can only be changed from the server console
	(not by players, not from the in-game editor): use it for anything that
	grants access, such as owner lists.
	hook "MeowyCore.ConfigChanged"(namespace, key, value, oldValue) runs in both realms.
	Console: meowycore_config <namespace> <key> [value]  (privilege meowycore.config)
]]

local Util = MeowyCore.Util
local Class = MeowyCore.Class
local Config = MeowyCore.Config or {}
MeowyCore.Config = Config

local log = MeowyCore.Log:Child("Config")

Config.sets = Config.sets or {}

local SUPPORTED = { number = true, string = true, boolean = true, Color = true, table = true }

local ConfigSet = Class.Define("MeowyCore.ConfigSet", {
	fields = {
		namespace = { type = "string", maxLen = 32, check = function(v) return string.match(v, "^[%w_]+$") ~= nil, "letters, digits and _ only" end },
		entries = { type = "table", default = {} },   -- key -> entry spec
		order = { type = "table", default = {} },     -- keys in declaration order
		values = { type = "table", default = {} },    -- key -> current value (nil = default)
	},
})
Config.ConfigSet = ConfigSet

local function filePath(ns)
	return "meowycore/config/" .. ns .. ".json"
end

-- JSON loses Color metatables; rebuild values by declared type.
local function fromJSON(entry, raw)
	if entry.type == "Color" and istable(raw) and raw.r then
		return Color(raw.r, raw.g, raw.b, raw.a or 255)
	end
	return raw
end

--- Parses console text into the entry's type. Returns value or nil + reason.
local function parseText(entry, text)
	if entry.type == "number" then
		local n = tonumber(text)
		if not n then return nil, "not a number" end
		return n
	elseif entry.type == "boolean" then
		local lower = string.lower(text)
		if lower == "1" or lower == "true" or lower == "yes" then return true end
		if lower == "0" or lower == "false" or lower == "no" then return false end
		return nil, "use true or false"
	elseif entry.type == "Color" then
		local r, g, b, a = string.match(text, "^(%d+)[ ,]+(%d+)[ ,]+(%d+)[ ,]*(%d*)$")
		if not r then return nil, "use r,g,b or r,g,b,a" end
		return Color(tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 255)
	elseif entry.type == "table" then
		local t = util.JSONToTable(text)
		if not t then return nil, "not valid JSON" end
		return t
	end
	return text
end

function ConfigSet:Has(key)
	return self.entries[key] ~= nil
end

--- Current value (a copy for tables/Colors, so callers cannot mutate state).
function ConfigSet:Get(key)
	local entry = self.entries[key]
	if not entry then
		error(string.format("Config %s: unknown key '%s'", self.namespace, tostring(key)), 2)
	end
	local value = self.values[key]
	if value == nil then value = entry.default end
	if istable(value) then return Util.DeepCopy(value) end
	return value
end

--- Validates a value for key. Returns true, or false + reason.
function ConfigSet:Check(key, value)
	local entry = self.entries[key]
	if not entry then return false, "unknown key" end
	if entry.type == "Color" and IsColor(value) then
		for _, c in ipairs({ value.r, value.g, value.b, value.a }) do
			if not Util.IsFinite(c) or c < 0 or c > 255 then return false, "colour channels must be 0-255" end
		end
	end
	return Class.CheckValue(entry, value)
end

function ConfigSet:Save()
	if not SERVER then return end
	local out = {}
	for key, value in pairs(self.values) do out[key] = value end
	file.CreateDir("meowycore/config")
	file.Write(filePath(self.namespace), util.TableToJSON(out, true))
end

function ConfigSet:Load()
	if not SERVER then return end
	local raw = file.Read(filePath(self.namespace), "DATA")
	if not raw then return end
	local data = util.JSONToTable(raw)
	if not data then
		log:Error("%s: data/%s is not valid JSON; using defaults", self.namespace, filePath(self.namespace))
		return
	end
	for key, stored in pairs(data) do
		local entry = self.entries[key]
		if entry then
			local value = fromJSON(entry, stored)
			local ok, reason = self:Check(key, value)
			if ok then
				self.values[key] = value
			else
				log:Warn("%s.%s: saved value ignored (%s); using default", self.namespace, key, reason)
			end
		end
	end
end

--- Server: sets, saves and (for shared keys) networks a value.
--- Returns true, or false + reason.
function ConfigSet:Set(key, value)
	if not SERVER then error("Config:Set is server-only", 2) end
	local ok, reason = self:Check(key, value)
	if not ok then return false, reason end
	local old = self:Get(key)
	self.values[key] = Util.DeepCopy(value)
	self:Save()
	if self.entries[key].shared then
		Config.ValueMessage:Send(nil, { ns = self.namespace, key = key, value = { v = value } })
	end
	hook.Run("MeowyCore.ConfigChanged", self.namespace, key, self:Get(key), old)
	return true
end

--- Server: resets a key to its default.
function ConfigSet:Reset(key)
	if not self.entries[key] then return false, "unknown key" end
	return self:Set(key, Util.DeepCopy(self.entries[key].default))
end

--- Values of all shared keys (for networking).
function ConfigSet:SharedValues()
	local out = {}
	for key, entry in pairs(self.entries) do
		if entry.shared then out[key] = self:Get(key) end
	end
	return out
end

--- Declares (or, on Lua refresh, updates) a settings namespace.
function Config.Define(namespace, entries)
	local set = Config.sets[namespace]
	if not set then
		set = ConfigSet.New({ namespace = namespace })
		Config.sets[namespace] = set
	end
	set.entries, set.order = {}, {}
	for i, entry in ipairs(entries) do
		assert(isstring(entry.key), string.format("Config %s: entry %d needs a key", namespace, i))
		assert(SUPPORTED[entry.type], string.format("Config %s.%s: unsupported type %s", namespace, entry.key, tostring(entry.type)))
		assert(entry.default ~= nil, string.format("Config %s.%s: needs a default", namespace, entry.key))
		local ok, reason = Class.CheckValue(entry, entry.default)
		assert(ok, string.format("Config %s.%s: default is invalid: %s", namespace, entry.key, tostring(reason)))
		set.entries[entry.key] = entry
		table.insert(set.order, entry.key)
	end
	-- Drop values for keys that no longer exist.
	for key in pairs(set.values) do
		if not set.entries[key] then set.values[key] = nil end
	end
	if SERVER then set:Load() end
	return set
end

function Config.Get(namespace)
	return Config.sets[namespace]
end

-- Networking ----------------------------------------------------------------

Config.RequestMessage = MeowyCore.Net.Define("mcore_config_request", {
	to = "server",
	fields = {},
	rate = { burst = 2, refill = 30 },
})

Config.SyncMessage = MeowyCore.Net.Define("mcore_config_sync", {
	to = "client",
	fields = { { "sets", "json", max = 60000 } },
})

Config.ValueMessage = MeowyCore.Net.Define("mcore_config_value", {
	to = "client",
	fields = {
		{ "ns", "string", max = 32 },
		{ "key", "string", max = 64 },
		{ "value", "json", max = 16000 },
	},
})

-- In-game editing (privilege meowycore.config). The server validates every
-- value exactly as the console command does.
Config.FullQuery = MeowyCore.Net.Define("mcore_config_query", {
	to = "server",
	fields = { { "ns", "string", max = 32 } },
	rate = { burst = 5, refill = 2 },
	permission = "meowycore.config",
})

Config.FullMessage = MeowyCore.Net.Define("mcore_config_full", {
	to = "client",
	fields = { { "ns", "string", max = 32 }, { "entries", "json", max = 30000 }, { "values", "json", max = 30000 } },
})

Config.SetRequest = MeowyCore.Net.Define("mcore_config_set", {
	to = "server",
	fields = { { "ns", "string", max = 32 }, { "key", "string", max = 64 }, { "value", "json", max = 16000 } },
	rate = { burst = 10, refill = 0.5 },
	permission = "meowycore.config",
})

Config.SetResult = MeowyCore.Net.Define("mcore_config_setresult", {
	to = "client",
	fields = { { "ns", "string", max = 32 }, { "key", "string", max = 64 }, { "ok", "bool" }, { "reason", "string", max = 200 } },
})

local EXPORTED = { "key", "type", "default", "min", "max", "integer", "maxLen", "enum", "shared", "consoleOnly" }

local function applyClientValue(ns, key, raw)
	local set = Config.sets[ns]
	if not set or not set.entries[key] then return end
	local value = fromJSON(set.entries[key], raw)
	local ok = set:Check(key, value)
	if not ok then return end
	local old = set:Get(key)
	set.values[key] = value
	hook.Run("MeowyCore.ConfigChanged", ns, key, set:Get(key), old)
end

if SERVER then
	Config.RequestMessage:Receive(function(ply)
		local out = {}
		for ns, set in pairs(Config.sets) do out[ns] = set:SharedValues() end
		Config.SyncMessage:Send(ply, { sets = out })
	end)

	Config.FullQuery:Receive(function(ply, data)
		local set = Config.sets[data.ns]
		if not set then return end
		local entries, values = {}, {}
		for _, key in ipairs(set.order) do
			local entry, out = set.entries[key], {}
			for _, field in ipairs(EXPORTED) do out[field] = entry[field] end
			table.insert(entries, out)
			values[key] = set:Get(key)
		end
		Config.FullMessage:Send(ply, { ns = data.ns, entries = entries, values = values })
	end)

	Config.SetRequest:Receive(function(ply, data)
		local set = Config.sets[data.ns]
		local function result(ok, reason)
			Config.SetResult:Send(ply, { ns = data.ns, key = data.key, ok = ok, reason = reason or "" })
		end
		if not set or not set:Has(data.key) then result(false, "unknown setting") return end
		if set.entries[data.key].consoleOnly then result(false, "this setting can only be changed from the server console") return end
		local value = fromJSON(set.entries[data.key], data.value.v)
		local ok, err = set:Set(data.key, value)
		if ok then
			log:Info("%s set %s.%s from the menu", ply:SteamID(), data.ns, data.key)
		end
		result(ok, err and tostring(err))
	end)

	concommand.Add("meowycore_config", function(ply, _, args, argStr)
		local function reply(key, vars)
			local text = MeowyCore.L("core", key, vars)
			if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
		end
		if not MeowyCore.Perm.Has(ply, "meowycore.config") then reply("perm.denied") return end
		local ns, key = args[1], args[2]
		if not ns or not key then reply("config.usage") return end
		local set = Config.sets[ns]
		if not set or not set:Has(key) then reply("config.unknown", { ns = ns, key = key }) return end

		if args[3] == nil then
			local value = set:Get(key)
			reply("config.value", { ns = ns, key = key, value = istable(value) and util.TableToJSON(value) or tostring(value) })
			return
		end

		if set.entries[key].consoleOnly and IsValid(ply) then
			reply("config.consoleonly", { ns = ns, key = key })
			return
		end
		-- Use the raw text: the console splits tokens on ':' too, which would
		-- turn STEAM_0:1:2 into "STEAM_0 : 1 : 2".
		local text = string.match(argStr or "", "^%s*%S+%s+%S+%s+(.-)%s*$") or table.concat(args, " ", 3)
		local value, reason = parseText(set.entries[key], text)
		if value == nil then reply("config.invalid", { ns = ns, key = key, reason = reason }) return end
		local ok, err = set:Set(key, value)
		if not ok then reply("config.invalid", { ns = ns, key = key, reason = err }) return end
		reply("config.set", { ns = ns, key = key, value = text })
		log:Info("%s set %s.%s = %s", IsValid(ply) and ply:SteamID() or "console", ns, key, text)
	end)
else
	Config.SyncMessage:Receive(function(data)
		for ns, values in pairs(data.sets) do
			for key, raw in pairs(values) do applyClientValue(ns, key, raw) end
		end
	end)

	Config.ValueMessage:Receive(function(data)
		applyClientValue(data.ns, data.key, data.value.v)
	end)

	hook.Add("InitPostEntity", "mcore_config_request", function()
		Config.RequestMessage:Send({})
	end)

	Config.pendingFull = Config.pendingFull or {}
	Config.pendingSet = Config.pendingSet or {}

	--- Asks the server for every entry and value of a namespace (needs meowycore.config).
	--- callback(entries, values)
	function Config.RequestFull(ns, callback)
		Config.pendingFull[ns] = callback
		Config.FullQuery:Send({ ns = ns })
	end

	--- Asks the server to set a value. callback(ok, reason)
	function Config.RequestSet(ns, key, value, callback)
		Config.pendingSet[ns .. "." .. key] = callback
		Config.SetRequest:Send({ ns = ns, key = key, value = { v = value } })
	end

	Config.FullMessage:Receive(function(data)
		local cb = Config.pendingFull[data.ns]
		Config.pendingFull[data.ns] = nil
		if not cb then return end
		local values = {}
		for _, entry in ipairs(data.entries) do
			values[entry.key] = fromJSON(entry, data.values[entry.key])
			entry.default = fromJSON(entry, entry.default)
		end
		cb(data.entries, values)
	end)

	Config.SetResult:Receive(function(data)
		local id = data.ns .. "." .. data.key
		local cb = Config.pendingSet[id]
		Config.pendingSet[id] = nil
		if cb then cb(data.ok, data.reason) end
	end)
end
