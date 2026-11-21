--[[
	Sends MeowyCore's icons to clients. Disable with meowycore_fastdl 0 when
	the Meowy Workshop content addon is used instead.
]]

local cv = CreateConVar("meowycore_fastdl", "1", { FCVAR_ARCHIVE }, "Send MeowyCore icons to players via the server download (1/0)")

if cv:GetBool() then
	for _, folder in ipairs({ "icons", "ui" }) do
		local files = file.Find("materials/meowycore/" .. folder .. "/*.png", "GAME")
		for _, f in ipairs(files or {}) do
			resource.AddFile("materials/meowycore/" .. folder .. "/" .. f)
		end
	end
end
