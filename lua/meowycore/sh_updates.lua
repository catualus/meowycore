--[[
	MeowyCore.Updates: opt-out update check for MeowyCore products.

	Once per map, about 20 s after start, the server makes ONE request for
	versions.json in the public MeowyCore repository. No data is sent. Admins
	(privilege meowycore.admin) get a chat notice when something is outdated.
	Disable with:  meowycore_update_check 0

	Products register themselves:
		MeowyCore.Updates.Register("chat", "Meowy Chat", "1.0.0")
]]

local Util = MeowyCore.Util
local Updates = MeowyCore.Updates or {}
MeowyCore.Updates = Updates

local VERSIONS_URL = "https://raw.githubusercontent.com/catualus/meowycore/main/versions.json"

Updates.products = Updates.products or {}   -- id -> { name, version }
Updates.outdated = Updates.outdated or {}   -- list of { name, installed, latest }

Updates.NoticeMessage = MeowyCore.Net.Define("mcore_update_notice", {
	to = "client",
	fields = { { "items", "json", max = 4000 } },
})

function Updates.Register(id, name, version)
	assert(Util.ParseVersion(version), "Updates.Register: version must look like 1.2.3")
	Updates.products[id] = { name = name, version = version }
end

if CLIENT then
	Updates.NoticeMessage:Receive(function(data)
		for _, item in ipairs(data.items) do
			chat.AddText(MeowyCore.UI.Theme.accent, "[MeowyCore] ", MeowyCore.UI.Theme.text,
				MeowyCore.L("core", "update.available", item))
		end
	end)
	return
end

local log = MeowyCore.Log:Child("Updates")
local cvEnabled = CreateConVar("meowycore_update_check", "1", { FCVAR_ARCHIVE },
	"Check for MeowyCore product updates once per map (1 = on, 0 = off). Sends no data.")

local function check()
	if not cvEnabled:GetBool() then return end
	http.Fetch(VERSIONS_URL, function(body, _, _, code)
		if code ~= 200 then log:Debug("versions.json: HTTP %s", tostring(code)) return end
		local latest = util.JSONToTable(body or "")
		if not latest then return end
		local outdated = {}
		for id, product in pairs(Updates.products) do
			local entry = latest[id]
			if istable(entry) and Util.CompareVersions(product.version, entry.latest) == -1 then
				table.insert(outdated, { name = product.name, installed = product.version, latest = entry.latest })
				log:Info("%s %s is available (installed %s)", product.name, entry.latest, product.version)
			end
		end
		Updates.outdated = outdated
	end, function(err)
		log:Debug("Update check failed: %s", tostring(err))
	end)
end

hook.Add("InitPostEntity", "mcore_updates_check", function()
	timer.Simple(20, check)
end)

hook.Add("PlayerInitialSpawn", "mcore_updates_notice", function(ply)
	timer.Simple(15, function()
		if not IsValid(ply) or #Updates.outdated == 0 then return end
		if not MeowyCore.Perm.Has(ply, "meowycore.admin") then return end
		Updates.NoticeMessage:Send(ply, { items = Updates.outdated })
	end)
end)
