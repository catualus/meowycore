--[[
	MeowyCore bootstrap. MIT licence, see LICENSE.
	Loads the core modules in a fixed order, in the right realm.
	Products wait for it with:  MeowyCore.OnReady(function() ... end)
]]

MeowyCore = MeowyCore or {}
MeowyCore.VERSION = "0.1.0"
MeowyCore._readyQueue = MeowyCore._readyQueue or {}

local FILES = {
	{ "thirdparty/sh_cami.lua", "sh" },
	{ "sh_util.lua", "sh" },
	{ "sh_class.lua", "sh" },
	{ "sh_log.lua", "sh" },
	{ "sh_lang.lua", "sh" },
	{ "lang/sh_en.lua", "sh" },
	{ "sh_include.lua", "sh" },
	{ "sh_perm.lua", "sh" },
	{ "sh_net.lua", "sh" },
	{ "sh_config.lua", "sh" },
	{ "sv_data.lua", "sv" },
	{ "cl_ui.lua", "cl" },
	{ "cl_ui_panels.lua", "cl" },
	{ "cl_ui_widgets.lua", "cl" },
	{ "sh_updates.lua", "sh" },
}

for _, entry in ipairs(FILES) do
	local path, realm = "meowycore/" .. entry[1], entry[2]
	if realm == "sh" then
		if SERVER then AddCSLuaFile(path) end
		include(path)
	elseif realm == "sv" then
		if SERVER then include(path) end
	elseif realm == "cl" then
		if SERVER then AddCSLuaFile(path) else include(path) end
	end
end

MeowyCore.Ready = true

--- Runs fn once MeowyCore is loaded (immediately if it already is).
function MeowyCore.OnReady(fn)
	if MeowyCore.Ready then
		fn()
	else
		table.insert(MeowyCore._readyQueue, fn)
	end
end

for _, fn in ipairs(MeowyCore._readyQueue) do
	ProtectedCall(fn)
end
MeowyCore._readyQueue = {}

MeowyCore.Updates = MeowyCore.Updates or {}
if SERVER and MeowyCore.Updates.Register then
	MeowyCore.Updates.Register("meowycore", "MeowyCore", MeowyCore.VERSION)
end

hook.Run("MeowyCore.Loaded", MeowyCore.VERSION)
MeowyCore.Log:Info("MeowyCore %s loaded (%s)", MeowyCore.VERSION, SERVER and "server" or "client")
