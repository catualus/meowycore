--[[
	MeowyCore.Util: small helpers shared by every module.
]]

local Util = MeowyCore.Util or {}
MeowyCore.Util = Util

--- Deep copy that keeps Color/Vector/Angle values as their own types.
function Util.DeepCopy(value, seen)
	if IsColor(value) then return Color(value.r, value.g, value.b, value.a) end
	if isvector(value) then return Vector(value) end
	if isangle(value) then return Angle(value) end
	if not istable(value) then return value end

	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[Util.DeepCopy(k, seen)] = Util.DeepCopy(v, seen)
	end
	return setmetatable(copy, getmetatable(value))
end

--- Returns a descriptive type name: "Color", "Vector", "Angle", "Player",
--- "Entity", or the plain Lua type.
function Util.TypeOf(value)
	if IsColor(value) then return "Color" end
	if isvector(value) then return "Vector" end
	if isangle(value) then return "Angle" end
	if IsEntity(value) then
		if value:IsPlayer() then return "Player" end
		return "Entity"
	end
	return type(value)
end

--- True if n is a real number (not NaN and not +/-inf).
function Util.IsFinite(n)
	return isnumber(n) and n == n and n ~= math.huge and n ~= -math.huge
end

--- Parses "1.2.3" (optionally "v1.2.3", extra suffix ignored) into {1, 2, 3}.
function Util.ParseVersion(text)
	if not isstring(text) then return nil end
	local a, b, c = string.match(text, "^v?(%d+)%.(%d+)%.(%d+)")
	if not a then return nil end
	return { tonumber(a), tonumber(b), tonumber(c) }
end

--- Compares two version strings: -1 if a < b, 0 if equal, 1 if a > b.
--- Returns nil if either is not a valid version.
function Util.CompareVersions(a, b)
	local va, vb = Util.ParseVersion(a), Util.ParseVersion(b)
	if not va or not vb then return nil end
	for i = 1, 3 do
		if va[i] ~= vb[i] then
			return va[i] < vb[i] and -1 or 1
		end
	end
	return 0
end

--- Capitalises the first letter: "label" -> "Label".
function Util.Capitalize(text)
	return (string.gsub(text, "^%l", string.upper))
end

--- Number of keys in a table (pairs-based).
function Util.Count(tbl)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end
