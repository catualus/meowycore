--[[
	MeowyCore.Perm: privileges on top of CAMI (works with SAM, sAdmin, ULX,
	xAdmin and any CAMI admin mod). Without an admin mod it falls back to
	the player's usergroup (user / admin / superadmin).

	MeowyCore.Perm.Register("meowycore.chat.mute", "admin", "Mute players in chat")
	if MeowyCore.Perm.Has(ply, "meowycore.chat.mute") then ... end
]]

local Perm = MeowyCore.Perm or {}
MeowyCore.Perm = Perm

Perm.privileges = Perm.privileges or {}

local ACCESS_RANK = { user = 1, admin = 2, superadmin = 3 }

--- Registers a privilege with CAMI. minAccess: "user", "admin" or "superadmin".
function Perm.Register(name, minAccess, description)
	assert(isstring(name), "Perm.Register: name must be a string")
	assert(ACCESS_RANK[minAccess], "Perm.Register: minAccess must be user, admin or superadmin")
	Perm.privileges[name] = { minAccess = minAccess, description = description or "" }
	CAMI.RegisterPrivilege({
		Name = name,
		MinAccess = minAccess,
		Description = description or "",
	})
end

local function fallback(ply, minAccess)
	if minAccess == "user" then return true end
	if minAccess == "superadmin" then return ply:IsSuperAdmin() end
	return ply:IsAdmin()
end

--- Synchronous check. The server console (NULL player) always passes.
--- If the admin mod answers asynchronously, the usergroup fallback is used;
--- use Perm.Check when you can wait for the real answer.
function Perm.Has(ply, name)
	if SERVER and not IsValid(ply) then return true end
	if not IsValid(ply) then return false end
	local priv = Perm.privileges[name]
	if not priv then
		MeowyCore.Log:Warn("Permission check for unregistered privilege '%s'", tostring(name))
		return ply:IsSuperAdmin()
	end

	local answered, result = false, false
	CAMI.PlayerHasAccess(ply, name, function(has)
		answered, result = true, has == true
	end)
	if answered then return result end
	return fallback(ply, priv.minAccess)
end

--- Asynchronous check: callback(has).
function Perm.Check(ply, name, callback)
	if SERVER and not IsValid(ply) then callback(true) return end
	if not IsValid(ply) or not Perm.privileges[name] then callback(false) return end
	CAMI.PlayerHasAccess(ply, name, function(has) callback(has == true) end)
end

Perm.Register("meowycore.config", "superadmin", "Change MeowyCore and product settings")
Perm.Register("meowycore.admin", "admin", "See MeowyCore admin notices (updates, warnings)")
