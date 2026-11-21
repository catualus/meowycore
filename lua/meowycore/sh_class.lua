--[[
	MeowyCore.Class: the class system every MeowyCore module and product uses.

	local Channel = MeowyCore.Class.Define("MeowyCore.Chat.Channel", {
		extends  = SomeBase,            -- optional
		abstract = { "CanSee" },        -- methods a subclass must implement
		fields = {
			id    = { type = "string" },                         -- required
			label = { type = "string", default = "", maxLen = 32 },
			range = { type = "number", optional = true, min = 0 },
			kind  = { type = "string", default = "local", enum = { "local", "global" } },
		},
	})
	function Channel:Init(args) end   -- optional, runs after fields are set
	local c = Channel.New({ id = "ooc" })
	c:GetLabel()  c:SetLabel("OOC")  Channel.IsA(c)

	Field types: "string", "number", "boolean", "table", "function", "Color",
	"Vector", "Angle", "Entity", "Player", "any", or another MeowyCore class.
]]

local Util = MeowyCore.Util
local Class = MeowyCore.Class or {}
MeowyCore.Class = Class

Class.registry = Class.registry or {}

local CHECKS = {
	string = isstring,
	number = isnumber,
	boolean = isbool,
	table = istable,
	["function"] = isfunction,
	Color = IsColor,
	Vector = isvector,
	Angle = isangle,
	Entity = function(v) return IsEntity(v) end,
	Player = function(v) return IsEntity(v) and IsValid(v) and v:IsPlayer() end,
	any = function() return true end,
}

local function abstractStub(self)
	error(string.format("%s: abstract method called", tostring(self.__name)), 2)
end

local function typeName(fieldType)
	if istable(fieldType) then return fieldType.__name or "class" end
	return fieldType
end

--- Validates one value against a field spec. Returns true, or false + reason.
function Class.CheckValue(spec, value)
	local fieldType = spec.type or "any"
	if istable(fieldType) then
		if not (istable(value) and fieldType.IsA and fieldType.IsA(value)) then
			return false, "expected " .. typeName(fieldType) .. ", got " .. Util.TypeOf(value)
		end
	else
		local check = CHECKS[fieldType]
		if not check then return false, "unknown field type '" .. tostring(fieldType) .. "'" end
		if not check(value) then
			return false, "expected " .. fieldType .. ", got " .. Util.TypeOf(value)
		end
	end
	if isnumber(value) then
		if not Util.IsFinite(value) then return false, "number is not finite" end
		if spec.min and value < spec.min then return false, "below minimum " .. spec.min end
		if spec.max and value > spec.max then return false, "above maximum " .. spec.max end
		if spec.integer and value ~= math.floor(value) then return false, "must be a whole number" end
	end
	if isstring(value) and spec.maxLen and #value > spec.maxLen then
		return false, "longer than " .. spec.maxLen .. " bytes"
	end
	if spec.enum then
		local found = false
		for _, allowed in ipairs(spec.enum) do
			if allowed == value then found = true break end
		end
		if not found then return false, "not one of: " .. table.concat(spec.enum, ", ") end
	end
	if spec.check then
		local ok, reason = spec.check(value)
		if not ok then return false, reason or "failed custom check" end
	end
	return true
end

--- Defines (or, on Lua refresh, redefines) a class. Existing instances pick up
--- new methods because the class table is reused.
function Class.Define(name, spec)
	assert(isstring(name), "Class.Define: name must be a string")
	spec = spec or {}
	local parent = spec.extends

	local cls = Class.registry[name] or {}
	Class.registry[name] = cls

	-- Merge fields: parent first, own fields override.
	local fields = {}
	if parent then
		for k, v in pairs(parent.__fields) do fields[k] = v end
	end
	for k, v in pairs(spec.fields or {}) do
		assert(istable(v), name .. ": field '" .. k .. "' spec must be a table")
		fields[k] = v
	end

	local abstract = {}
	if parent then
		for k in pairs(parent.__abstract) do abstract[k] = true end
	end
	for _, m in ipairs(spec.abstract or {}) do abstract[m] = true end

	cls.__index = cls
	cls.__name = name
	cls.__parent = parent
	cls.__fields = fields
	cls.__abstract = abstract
	cls.__tostring = function(self) return name .. " instance" end
	cls.__generated = cls.__generated or {}

	setmetatable(cls, {
		__index = parent,
		__tostring = function() return "class " .. name end,
	})

	-- Generated accessors (never overwrite a hand-written method).
	for fieldName, fieldSpec in pairs(fields) do
		local cap = Util.Capitalize(fieldName)
		local getter, setter = "Get" .. cap, "Set" .. cap
		if rawget(cls, getter) == nil or cls.__generated[getter] then
			cls[getter] = function(self) return self[fieldName] end
			cls.__generated[getter] = true
		end
		if rawget(cls, setter) == nil or cls.__generated[setter] then
			cls[setter] = function(self, value)
				if value == nil and (fieldSpec.optional or fieldSpec.default ~= nil) then
					self[fieldName] = nil
					return self
				end
				local ok, reason = Class.CheckValue(fieldSpec, value)
				if not ok then
					error(string.format("%s:%s: %s", name, setter, reason), 2)
				end
				self[fieldName] = value
				return self
			end
			cls.__generated[setter] = true
		end
	end

	for m in pairs(abstract) do
		if rawget(cls, m) == nil then cls[m] = abstractStub end
	end

	--- Creates an instance from a table of named field values.
	function cls.New(args)
		args = args or {}
		if not istable(args) then
			error(name .. ".New: expected a table of fields", 2)
		end
		for m in pairs(abstract) do
			if cls[m] == abstractStub then
				error(name .. ".New: abstract method '" .. m .. "' is not implemented", 2)
			end
		end
		for k in pairs(args) do
			if fields[k] == nil then
				error(string.format("%s.New: unknown field '%s'", name, tostring(k)), 2)
			end
		end

		local obj = setmetatable({}, cls)
		for fieldName, fieldSpec in pairs(fields) do
			local value = args[fieldName]
			if value == nil and fieldSpec.default ~= nil then
				value = Util.DeepCopy(fieldSpec.default)
			end
			if value == nil then
				if not fieldSpec.optional then
					error(string.format("%s.New: missing required field '%s'", name, fieldName), 2)
				end
			else
				local ok, reason = Class.CheckValue(fieldSpec, value)
				if not ok then
					error(string.format("%s.New: field '%s': %s", name, fieldName, reason), 2)
				end
				obj[fieldName] = value
			end
		end

		if obj.Init then obj:Init(args) end
		return obj
	end

	--- True if obj is an instance of this class or a subclass.
	function cls.IsA(obj)
		if not istable(obj) then return false end
		local mt = getmetatable(obj)
		while mt do
			if mt == cls then return true end
			mt = rawget(mt, "__parent")
		end
		return false
	end

	return cls
end

--- True if obj is an instance of cls (or a subclass).
function Class.IsA(obj, cls)
	return istable(cls) and cls.IsA ~= nil and cls.IsA(obj)
end

--- Looks up a class by name.
function Class.Get(name)
	return Class.registry[name]
end
