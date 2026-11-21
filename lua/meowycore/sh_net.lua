--[[
	MeowyCore.Net: declared, validated, rate-limited net messages.

	local Send = MeowyCore.Net.Define("mcore_chat_send", {
		to = "server",                                  -- "server" or "client"
		fields = {
			{ "channel", "string", max = 32 },
			{ "text", "string", max = 512 },
		},
		rate = { burst = 5, refill = 1.5 },             -- token bucket per player
		permission = nil,                               -- privilege name, optional
	})
	Send:Receive(function(ply, msg) end)   -- server; msg.channel / msg.text are validated
	Send:Send(msg)                          -- client -> server
	Other:Send(target, msg)                 -- server -> client; target = player, list, or nil for everyone

	Field types: string (max, default 255), uint / int (bits, default 32),
	float, bool, entity, player, color, vector, angle, json (max bytes, default 16384).
	entity/player fields may be NULL only when marked optional = true.

	Server side, every message passes Net.Guard (size, rate limit, permission)
	before anything is read, then every field is validated before the handler runs.
]]

local Util = MeowyCore.Util
local Net = MeowyCore.Net or {}
MeowyCore.Net = Net

local log = MeowyCore.Log:Child("Net")

Net.messages = Net.messages or {}
Net.buckets = Net.buckets or {}         -- buckets[key][messageName] = { tokens, last }

local MAX_BITS = 64 * 1024 * 8

-- Type codecs: write(value, field), read(field) -> value, valid(value, field) -> ok, reason
local CODECS = {
	string = {
		write = function(v) net.WriteString(v) end,
		read = function() return net.ReadString() end,
		valid = function(v, f)
			if not isstring(v) then return false, "not a string" end
			if #v > (f.max or 255) then return false, "longer than " .. (f.max or 255) end
			return true
		end,
	},
	uint = {
		write = function(v, f) net.WriteUInt(v, f.bits or 32) end,
		read = function(f) return net.ReadUInt(f.bits or 32) end,
		valid = function(v, f)
			if not Util.IsFinite(v) or v < 0 or v ~= math.floor(v) then return false, "not a whole non-negative number" end
			if v >= 2 ^ (f.bits or 32) then return false, "too large for " .. (f.bits or 32) .. " bits" end
			if f.min and v < f.min then return false, "below " .. f.min end
			if f.max and v > f.max then return false, "above " .. f.max end
			return true
		end,
	},
	int = {
		write = function(v, f) net.WriteInt(v, f.bits or 32) end,
		read = function(f) return net.ReadInt(f.bits or 32) end,
		valid = function(v, f)
			if not Util.IsFinite(v) or v ~= math.floor(v) then return false, "not a whole number" end
			local half = 2 ^ ((f.bits or 32) - 1)
			if v < -half or v >= half then return false, "out of range for " .. (f.bits or 32) .. " bits" end
			if f.min and v < f.min then return false, "below " .. f.min end
			if f.max and v > f.max then return false, "above " .. f.max end
			return true
		end,
	},
	float = {
		write = function(v) net.WriteFloat(v) end,
		read = function() return net.ReadFloat() end,
		valid = function(v, f)
			if not Util.IsFinite(v) then return false, "not a finite number" end
			if f.min and v < f.min then return false, "below " .. f.min end
			if f.max and v > f.max then return false, "above " .. f.max end
			return true
		end,
	},
	bool = {
		write = function(v) net.WriteBool(v) end,
		read = function() return net.ReadBool() end,
		valid = function(v) return isbool(v), "not a boolean" end,
	},
	entity = {
		write = function(v) net.WriteEntity(v) end,
		read = function() return net.ReadEntity() end,
		valid = function(v, f)
			if not IsEntity(v) then return false, "not an entity" end
			if not f.optional and not IsValid(v) then return false, "entity is not valid" end
			return true
		end,
	},
	player = {
		write = function(v) net.WriteEntity(v) end,
		read = function() return net.ReadEntity() end,
		valid = function(v, f)
			if not IsEntity(v) then return false, "not an entity" end
			if not IsValid(v) then
				if f.optional then return true end
				return false, "player is not valid"
			end
			if not v:IsPlayer() then return false, "not a player" end
			return true
		end,
	},
	color = {
		write = function(v) net.WriteColor(v, true) end,
		read = function() return net.ReadColor(true) end,
		valid = function(v) return IsColor(v), "not a Color" end,
	},
	vector = {
		write = function(v) net.WriteVector(v) end,
		read = function() return net.ReadVector() end,
		valid = function(v)
			if not isvector(v) then return false, "not a Vector" end
			if not (Util.IsFinite(v.x) and Util.IsFinite(v.y) and Util.IsFinite(v.z)) then return false, "not finite" end
			return true
		end,
	},
	angle = {
		write = function(v) net.WriteAngle(v) end,
		read = function() return net.ReadAngle() end,
		valid = function(v)
			if not isangle(v) then return false, "not an Angle" end
			if not (Util.IsFinite(v.p) and Util.IsFinite(v.y) and Util.IsFinite(v.r)) then return false, "not finite" end
			return true
		end,
	},
	json = {
		write = function(v)
			local data = util.Compress(util.TableToJSON(v))
			net.WriteUInt(#data, 16)
			net.WriteData(data, #data)
		end,
		read = function(f)
			local size = net.ReadUInt(16)
			if size > (f.max or 16384) then return nil end
			local raw = util.Decompress(net.ReadData(size), f.max or 16384)
			if not raw then return nil end
			return util.JSONToTable(raw)
		end,
		valid = function(v, f)
			if not istable(v) then return false, "not a table" end
			if f.max and #util.TableToJSON(v) > f.max then return false, "larger than " .. f.max .. " bytes" end
			return true
		end,
	},
}
Net.CODECS = CODECS

local Message = MeowyCore.Class.Define("MeowyCore.NetMessage", {
	fields = {
		name = { type = "string", maxLen = 64 },
		to = { type = "string", enum = { "server", "client" } },
		fields = { type = "table", default = {} },
		rate = { type = "table", optional = true },
		permission = { type = "string", optional = true },
		handlers = { type = "table", default = {} },
	},
})
Net.Message = Message

--- Validates a decoded or outgoing payload. Returns true, or false + reason.
function Message:Validate(data)
	if not istable(data) then return false, "payload is not a table" end
	for _, f in ipairs(self.fields) do
		local name, kind = f[1], f[2]
		local value = data[name]
		if value == nil then
			if not f.optional then return false, "missing field '" .. name .. "'" end
		else
			local ok, reason = CODECS[kind].valid(value, f)
			if not ok then return false, "field '" .. name .. "': " .. tostring(reason) end
		end
	end
	return true
end

local function writePayload(msg, data)
	for _, f in ipairs(msg.fields) do
		local value = data[f[1]]
		if f.optional then
			net.WriteBool(value ~= nil)
			if value ~= nil then CODECS[f[2]].write(value, f) end
		else
			CODECS[f[2]].write(value, f)
		end
	end
end

local function readPayload(msg)
	local data = {}
	for _, f in ipairs(msg.fields) do
		if not f.optional or net.ReadBool() then
			data[f[1]] = CODECS[f[2]].read(f)
		end
	end
	return data
end

--- Adds a handler. Server: fn(ply, data). Client: fn(data).
--- A handler defined at the same file and line replaces the old one, so Lua
--- auto-refresh does not stack duplicate handlers.
function Message:Receive(fn)
	assert(isfunction(fn), "Receive needs a function")
	local info = debug.getinfo(fn, "S")
	local key = info.short_src .. ":" .. info.linedefined
	for _, entry in ipairs(self.handlers) do
		if entry.key == key then
			entry.fn = fn
			return self
		end
	end
	table.insert(self.handlers, { key = key, fn = fn })
	return self
end

--- Removes all handlers (used on Lua refresh before re-adding).
function Message:ClearHandlers()
	self.handlers = {}
	return self
end

--- Server: Send(target, data). target = player, list of players, or nil for everyone.
--- Client: Send(data).
function Message:Send(a, b)
	local target, data
	if SERVER then target, data = a, b else data = a end
	if SERVER and self.to ~= "client" then error(self.name .. " is a client->server message", 2) end
	if CLIENT and self.to ~= "server" then error(self.name .. " is a server->client message", 2) end
	local ok, reason = self:Validate(data or {})
	if not ok then error(self.name .. ": " .. reason, 2) end

	net.Start(self.name)
	writePayload(self, data or {})
	if CLIENT then
		net.SendToServer()
	elseif target == nil then
		net.Broadcast()
	else
		net.Send(target)
	end
end

--- Takes one token from key's bucket for msg. Returns false when empty.
function Net.TakeToken(key, msg, now)
	local rate = msg.rate
	if not rate then return true end
	now = now or SysTime()
	local perKey = Net.buckets[key]
	if not perKey then
		perKey = {}
		Net.buckets[key] = perKey
	end
	local bucket = perKey[msg.name]
	if not bucket then
		bucket = { tokens = rate.burst, last = now }
		perKey[msg.name] = bucket
	end
	local refill = (now - bucket.last) / rate.refill
	bucket.tokens = math.min(rate.burst, bucket.tokens + refill)
	bucket.last = now
	if bucket.tokens < 1 then return false end
	bucket.tokens = bucket.tokens - 1
	return true
end

--- Gate run before any payload is read. Returns true to allow the message.
function Net.Guard(name, ply, len)
	local msg = Net.messages[name]
	if not msg then return false end
	if CLIENT then return msg.to == "client" end
	if msg.to ~= "server" then
		log:Warn("%s sent server->client message %s to the server", tostring(ply), name)
		return false
	end
	if not IsValid(ply) then return false end
	if len > MAX_BITS then return false end
	if not Net.TakeToken(ply, msg) then
		log:Debug("Rate limit: %s on %s", ply:SteamID(), name)
		return false
	end
	if msg.permission and not MeowyCore.Perm.Has(ply, msg.permission) then
		log:Warn("%s (%s) tried %s without %s", ply:Nick(), ply:SteamID(), name, msg.permission)
		return false
	end
	return true
end

local function dispatch(name, len, ply)
	if not Net.Guard(name, ply, len) then return end
	local msg = Net.messages[name]

	local okRead, data = pcall(readPayload, msg)
	if not okRead then
		log:Warn("Malformed %s from %s: %s", name, tostring(ply), tostring(data))
		return
	end
	local valid, reason = msg:Validate(data)
	if not valid then
		log:Warn("Rejected %s from %s: %s", name, tostring(ply), reason)
		return
	end
	for _, entry in ipairs(msg.handlers) do
		if SERVER then
			xpcall(entry.fn, ErrorNoHaltWithStack, ply, data)
		else
			xpcall(entry.fn, ErrorNoHaltWithStack, data)
		end
	end
end

--- Declares a message. Re-declaring (Lua refresh) keeps registered handlers.
function Net.Define(name, spec)
	assert(isstring(name) and string.StartWith(name, "mcore_"), "Net.Define: name must start with mcore_")
	assert(istable(spec), "Net.Define: spec must be a table")
	for i, f in ipairs(spec.fields or {}) do
		assert(isstring(f[1]) and CODECS[f[2]], string.format("Net.Define %s: field %d has an unknown type", name, i))
	end
	if spec.rate then
		assert(isnumber(spec.rate.burst) and spec.rate.burst >= 1 and isnumber(spec.rate.refill) and spec.rate.refill > 0,
			"Net.Define " .. name .. ": rate needs burst >= 1 and refill > 0")
	end

	local old = Net.messages[name]
	local msg = Message.New({
		name = name,
		to = spec.to,
		fields = spec.fields or {},
		rate = spec.rate,
		permission = spec.permission,
		handlers = old and old.handlers or {},
	})
	Net.messages[name] = msg

	if SERVER then util.AddNetworkString(name) end
	net.Receive(name, function(len, ply)
		dispatch(name, len, ply)
	end)
	return msg
end

if SERVER then
	hook.Add("PlayerDisconnected", "mcore_net_buckets", function(ply)
		Net.buckets[ply] = nil
	end)
end
