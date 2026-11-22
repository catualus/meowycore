--[[
	Sends MeowyCore's icons and UI textures to clients.

	Two ways, pick one:
	  - Workshop (recommended): set meowycore_workshop to the ID of the
	    "MeowyCore Content" Workshop item. Players download it with the rest of
	    the server's Workshop content; nothing goes through FastDL.
	  - Server download / FastDL (default when no Workshop ID is set): the files
	    are added with resource.AddFile. With sv_allowdownload 0 they must also
	    be on the FastDL host. meowycore_fastdl 0 turns this off.
]]

local cvWorkshop = CreateConVar("meowycore_workshop", "", { FCVAR_ARCHIVE }, "Workshop ID of the MeowyCore Content addon (empty = use the server download instead)")
local cvFastDL = CreateConVar("meowycore_fastdl", "1", { FCVAR_ARCHIVE }, "Send MeowyCore icons to players via the server download (1/0)")

local id = string.Trim(cvWorkshop:GetString())
if string.match(id, "^%d+$") then
	resource.AddWorkshop(id)
elseif cvFastDL:GetBool() then
	for _, folder in ipairs({ "icons", "ui" }) do
		local files = file.Find("materials/meowycore/" .. folder .. "/*.png", "GAME")
		for _, f in ipairs(files or {}) do
			resource.AddFile("materials/meowycore/" .. folder .. "/" .. f)
		end
	end
end
