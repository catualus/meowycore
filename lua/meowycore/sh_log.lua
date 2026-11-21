--[[
	MeowyCore.Logger: named, levelled console logging.

	local log = MeowyCore.Logger.New({ name = "MeowyChat" })
	log:Info("Loaded %d channels", n)
	local sub = log:Child("Data")          -- "MeowyChat/Data"

	Level is set by the convar meowycore_loglevel (error, warn, info, debug).
	Every message also runs hook "MeowyCore.Log" (name, level, text), which
	logging adapters (for example a bLogs module) can listen to.
]]

local LEVELS = { error = 1, warn = 2, info = 3, debug = 4 }
local LEVEL_COLORS = {
	error = Color(255, 90, 90),
	warn = Color(255, 200, 80),
	info = Color(170, 220, 255),
	debug = Color(160, 160, 160),
}
local WHITE = Color(230, 230, 230)

local cvLevel = CreateConVar("meowycore_loglevel", "info", { FCVAR_ARCHIVE },
	"MeowyCore log level: error, warn, info or debug")

local Logger = MeowyCore.Class.Define("MeowyCore.Logger", {
	fields = {
		name = { type = "string", maxLen = 64 },
		color = { type = "Color", default = Color(255, 150, 110) },
	},
})
MeowyCore.Logger = Logger

local function currentLevel()
	return LEVELS[string.lower(cvLevel:GetString())] or LEVELS.info
end

local function format(fmt, ...)
	if select("#", ...) == 0 then return tostring(fmt) end
	local ok, text = pcall(string.format, fmt, ...)
	if ok then return text end
	return tostring(fmt) .. " (bad log format: " .. tostring(text) .. ")"
end

function Logger:Log(level, fmt, ...)
	local rank = LEVELS[level]
	if not rank or rank > currentLevel() then return end
	local text = format(fmt, ...)
	MsgC(self.color, "[" .. self.name .. "] ", LEVEL_COLORS[level], string.upper(level), WHITE, " " .. text .. "\n")
	hook.Run("MeowyCore.Log", self.name, level, text)
end

function Logger:Error(fmt, ...) self:Log("error", fmt, ...) end
function Logger:Warn(fmt, ...) self:Log("warn", fmt, ...) end
function Logger:Info(fmt, ...) self:Log("info", fmt, ...) end
function Logger:Debug(fmt, ...) self:Log("debug", fmt, ...) end

--- A logger for a subsystem: "Parent/Sub", same colour.
function Logger:Child(sub)
	return Logger.New({ name = self.name .. "/" .. sub, color = self.color })
end

MeowyCore.Log = Logger.New({ name = "MeowyCore" })
