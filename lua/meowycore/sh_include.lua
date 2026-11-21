--[[
	MeowyCore.IncludeDir: loads a product's Lua folder by file-name convention.

	MeowyCore.IncludeDir("meowycore_chat")

	- Files must start with sh_, sv_ or cl_; anything else is skipped with a warning.
	- In each folder: sh_ files, then sv_, then cl_, each alphabetically.
	  Then subfolders, alphabetically. Use numeric names to force order
	  (sh_1_classes.lua before sh_2_channels.lua).
	- AddCSLuaFile is handled: clients receive sh_ and cl_ files only.
]]

local log = MeowyCore.Log:Child("Include")

local REALM_ORDER = { "sh", "sv", "cl" }

local function realmOf(fileName)
	return string.match(fileName, "^(%a%a)_")
end

local function loadFile(path, realm)
	if realm == "sh" then
		if SERVER then AddCSLuaFile(path) end
		return include(path)
	elseif realm == "sv" then
		if SERVER then return include(path) end
	elseif realm == "cl" then
		if SERVER then
			AddCSLuaFile(path)
		else
			return include(path)
		end
	end
end

--- Loads every Lua file under lua/<dir>/ following the convention above.
--- Returns the number of files loaded in this realm.
function MeowyCore.IncludeDir(dir)
	local count = 0

	local function walk(folder)
		local files, folders = file.Find(folder .. "/*", "LUA")
		files = files or {}
		folders = folders or {}
		table.sort(files)
		table.sort(folders)

		local byRealm = { sh = {}, sv = {}, cl = {} }
		for _, fileName in ipairs(files) do
			if string.EndsWith(fileName, ".lua") then
				local realm = realmOf(fileName)
				if byRealm[realm] then
					table.insert(byRealm[realm], fileName)
				else
					log:Warn("Skipping %s/%s: file names must start with sh_, sv_ or cl_", folder, fileName)
				end
			end
		end

		for _, realm in ipairs(REALM_ORDER) do
			for _, fileName in ipairs(byRealm[realm]) do
				loadFile(folder .. "/" .. fileName, realm)
				if realm == "sh" or (realm == "sv" and SERVER) or (realm == "cl" and CLIENT) then
					count = count + 1
				end
			end
		end

		for _, sub in ipairs(folders) do
			walk(folder .. "/" .. sub)
		end
	end

	walk(dir)
	log:Debug("Loaded %d files from %s", count, dir)
	return count
end
