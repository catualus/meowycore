--[[
	MeowyCore.UI: theme, scaling and fonts (modern flat dark).

	local T = MeowyCore.UI.Theme
	draw.RoundedBox(MeowyCore.UI.Scale(T.radius), x, y, w, h, T.surface)
	draw.SimpleText("Hi", MeowyCore.UI.Font(18, 600), x, y, T.text)

	Scale() maps a size designed at 1080p to the current screen height.
	Fonts are created on demand and recreated when the resolution changes.
]]

local UI = MeowyCore.UI or {}
MeowyCore.UI = UI

-- Surfaces are fully opaque on purpose: GMod renders partial alpha much more
-- transparent than the number suggests (245/255 shows the world through).
-- Use a separate overlay colour when transparency is actually wanted.
UI.Theme = UI.Theme or {
	background = Color(18, 19, 24, 255),
	surface = Color(28, 30, 37, 255),
	surfaceAlt = Color(36, 39, 48, 255),
	surfaceHover = Color(44, 48, 59, 255),
	border = Color(255, 255, 255, 14),
	text = Color(236, 238, 243),
	textDim = Color(160, 166, 180),
	accent = Color(255, 138, 101),
	accentText = Color(24, 20, 18),
	success = Color(98, 204, 140),
	warning = Color(250, 196, 84),
	danger = Color(240, 94, 94),
	radius = 6,
	fontFace = "Roboto",
}

--- Changes the accent colour (products may expose it as a config value).
function UI.SetAccent(color)
	UI.Theme.accent = Color(color.r, color.g, color.b, color.a or 255)
end

--- Converts a 1080p design size to the current resolution (minimum 1 px).
function UI.Scale(px)
	return math.max(1, math.Round(px * ScrH() / 1080))
end

UI.fonts = UI.fonts or {}

--- Returns a font name for a design size and weight, creating it once.
function UI.Font(size, weight, opts)
	weight = weight or 500
	local key = size .. "_" .. weight .. (opts and opts.mono and "_m" or "")
	local name = UI.fonts[key]
	if name then return name end
	name = "mcore_" .. key
	surface.CreateFont(name, {
		font = opts and opts.mono and "Roboto Mono" or UI.Theme.fontFace,
		size = UI.Scale(size),
		weight = weight,
		extended = true,
		antialias = true,
	})
	UI.fonts[key] = name
	return name
end

hook.Add("OnScreenSizeChanged", "mcore_ui_fonts", function()
	for key in pairs(UI.fonts) do
		local size, weight, mono = string.match(key, "^(%d+)_(%d+)(_?m?)$")
		surface.CreateFont("mcore_" .. key, {
			font = mono == "_m" and "Roboto Mono" or UI.Theme.fontFace,
			size = UI.Scale(tonumber(size)),
			weight = tonumber(weight),
			extended = true,
			antialias = true,
		})
	end
end)

--- Linear blend between two colours into `out` (no allocation when out is given).
function UI.LerpColor(t, from, to, out)
	out = out or Color(0, 0, 0)
	out.r = Lerp(t, from.r, to.r)
	out.g = Lerp(t, from.g, to.g)
	out.b = Lerp(t, from.b, to.b)
	out.a = Lerp(t, from.a, to.a)
	return out
end
