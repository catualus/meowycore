--[[
	MeowyCore.Lang: translations.

	MeowyCore.Lang.Register("chat", "en", { ["mute.done"] = "{player} was muted for {time}." })
	MeowyCore.L("chat", "mute.done", { player = name, time = "5m" })

	Language: the server convar meowycore_language (replicated). When empty,
	clients use their own gmod_language and the server uses English.
	Missing phrases fall back to English, then to the key itself.
]]

local Lang = MeowyCore.Lang or {}
MeowyCore.Lang = Lang

Lang.phrases = Lang.phrases or {}   -- phrases[namespace][language][key] = text

local cvLanguage = CreateConVar("meowycore_language", "", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
	"Language for MeowyCore products (e.g. en, de). Empty = each player's GMod language.")

--- Adds or replaces phrases for one namespace and language.
function Lang.Register(namespace, language, phrases)
	assert(isstring(namespace) and isstring(language) and istable(phrases), "Lang.Register(namespace, language, phrases)")
	Lang.phrases[namespace] = Lang.phrases[namespace] or {}
	local target = Lang.phrases[namespace][language] or {}
	Lang.phrases[namespace][language] = target
	for key, text in pairs(phrases) do
		target[key] = text
	end
end

--- The active language code.
function Lang.Active()
	local forced = cvLanguage:GetString()
	if forced ~= "" then return string.lower(forced) end
	if CLIENT then
		local gm = GetConVar("gmod_language")
		if gm and gm:GetString() ~= "" then return string.lower(gm:GetString()) end
	end
	return "en"
end

local function interpolate(text, vars)
	if not vars then return text end
	return (string.gsub(text, "{([%w_]+)}", function(name)
		local value = vars[name]
		if value == nil then return nil end
		return tostring(value)
	end))
end

--- Looks up a phrase. Falls back to English, then to the key.
function Lang.Get(namespace, key, vars)
	local ns = Lang.phrases[namespace]
	local text
	if ns then
		local active = ns[Lang.Active()]
		text = active and active[key]
		if text == nil and ns.en then text = ns.en[key] end
	end
	if text == nil then return key end
	return interpolate(text, vars)
end

--- True if the phrase exists in English (useful for tests and tooling).
function Lang.Has(namespace, key)
	local ns = Lang.phrases[namespace]
	return ns ~= nil and ns.en ~= nil and ns.en[key] ~= nil
end

MeowyCore.L = Lang.Get
