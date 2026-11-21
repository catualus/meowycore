--[[
	MeowyCore.UI v2: design tokens, scaling, fonts, icons, drawing helpers, toasts.

	Surfaces are layered and fully opaque (GMod renders partial alpha much
	more transparent than the number suggests):
		bg (window) < panel (sidebar/header) < card < input < hover
	Edges use the opaque `border` colour instead of transparency.

	local T = MeowyCore.UI.Theme
	MeowyCore.UI.DrawIcon("search", x, y, 18, T.textDim)
	MeowyCore.UI.Toast("Saved", "success")
]]

local UI = MeowyCore.UI or {}
MeowyCore.UI = UI

local function C(r, g, b, a) return Color(r, g, b, a or 255) end

UI.Theme = UI.Theme or {}
local T = UI.Theme
local tokens = {
	bg = C(15, 16, 20), panel = C(21, 23, 28), card = C(28, 30, 37), input = C(36, 39, 47),
	hover = C(44, 48, 58), border = C(42, 45, 54), borderStrong = C(58, 62, 74),
	text = C(236, 238, 243), textDim = C(165, 171, 186), textMuted = C(112, 118, 133),
	accent = C(255, 138, 101), accentSoft = C(62, 40, 35), accentText = C(26, 20, 18),
	danger = C(240, 94, 94), dangerSoft = C(60, 31, 33),
	success = C(98, 204, 140), successSoft = C(29, 50, 40),
	warning = C(250, 196, 84), warningSoft = C(56, 47, 28),
	info = C(110, 170, 255), infoSoft = C(29, 40, 60),
	radius = 8, radiusSmall = 6,
	fontFace = "Roboto",
}
for k, v in pairs(tokens) do T[k] = v end
-- v1 names, kept for products built on them.
T.background, T.surface, T.surfaceAlt, T.surfaceHover = T.bg, T.panel, T.input, T.hover

--- Changes the accent colour (products may expose it as a setting).
function UI.SetAccent(color)
	T.accent = C(color.r, color.g, color.b)
	T.accentSoft = C(math.floor(color.r * 0.22 + 10), math.floor(color.g * 0.22 + 10), math.floor(color.b * 0.22 + 12))
end

--- 1080p design size -> current resolution (minimum 1 px).
function UI.Scale(px)
	return math.max(1, math.Round(px * ScrH() / 1080))
end

-- Fonts --------------------------------------------------------------------------

UI.fonts = UI.fonts or {}

local function createFont(key, size, weight, mono)
	surface.CreateFont("mcore_" .. key, {
		font = mono and "Roboto Mono" or T.fontFace,
		size = UI.Scale(size), weight = weight, extended = true, antialias = true,
	})
end

--- Font name for a design size and weight, created once.
function UI.Font(size, weight, opts)
	weight = weight or 500
	local mono = opts and opts.mono
	local key = size .. "_" .. weight .. (mono and "_m" or "")
	if not UI.fonts[key] then
		createFont(key, size, weight, mono)
		UI.fonts[key] = "mcore_" .. key
	end
	return UI.fonts[key]
end

hook.Add("OnScreenSizeChanged", "mcore_ui_fonts", function()
	for key in pairs(UI.fonts) do
		local size, weight, mono = string.match(key, "^(%d+)_(%d+)(_?m?)$")
		createFont(key, tonumber(size), tonumber(weight), mono == "_m")
	end
end)

-- Icons ----------------------------------------------------------------------------

UI.icons = UI.icons or {}

--- Cached material for an icon in materials/meowycore/icons/<name>.png (white, tinted on draw).
function UI.Icon(name)
	local mat = UI.icons[name]
	if mat == nil then
		mat = Material("meowycore/icons/" .. name .. ".png", "smooth mips")
		if mat:IsError() then mat = false end
		UI.icons[name] = mat
	end
	return mat or nil
end

function UI.DrawIcon(name, x, y, size, color)
	local mat = UI.Icon(name)
	if not mat then return end
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(x, y, size, size)
end

-- Drawing helpers ----------------------------------------------------------------

--- Rounded box with a 1 px border (both opaque).
function UI.DrawBox(x, y, w, h, fill, border, radius)
	radius = radius or UI.Scale(T.radius)
	if border then
		draw.RoundedBox(radius, x, y, w, h, border)
		draw.RoundedBox(math.max(0, radius - 1), x + 1, y + 1, w - 2, h - 2, fill)
	else
		draw.RoundedBox(radius, x, y, w, h, fill)
	end
end

local SHADOW = Color(0, 0, 0, 14)

--- Soft drop shadow around a rectangle (draws outside the panel; call with clipping disabled).
function UI.DrawShadow(x, y, w, h, spread)
	spread = spread or UI.Scale(14)
	local steps = 6
	for i = steps, 1, -1 do
		local o = math.floor(spread * i / steps)
		draw.RoundedBox(UI.Scale(T.radius) + o, x - o, y - o + math.floor(o / 2), w + o * 2, h + o * 2, SHADOW)
	end
end

--- Small rounded label ("pill"). Returns its width.
function UI.DrawPill(text, x, y, fg, bg, font, alignRight)
	font = font or UI.Font(13, 700)
	surface.SetFont(font)
	local tw, th = surface.GetTextSize(text)
	local padX, padY = UI.Scale(8), UI.Scale(3)
	local w, h = tw + padX * 2, th + padY * 2
	if alignRight then x = x - w end
	draw.RoundedBox(math.floor(h / 2), x, y - h / 2, w, h, bg)
	draw.SimpleText(text, font, x + padX, y, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	return w
end

--- Colours for a semantic kind: "accent", "danger", "success", "warning", "info", "neutral".
function UI.KindColors(kind)
	if kind == "danger" then return T.danger, T.dangerSoft end
	if kind == "success" then return T.success, T.successSoft end
	if kind == "warning" then return T.warning, T.warningSoft end
	if kind == "info" then return T.info, T.infoSoft end
	if kind == "accent" then return T.accent, T.accentSoft end
	return T.textDim, T.input
end

--- Linear blend between two colours into `out` (no allocation when out is given).
function UI.LerpColor(t, from, to, out)
	out = out or Color(0, 0, 0)
	out.r = Lerp(t, from.r, to.r)
	out.g = Lerp(t, from.g, to.g)
	out.b = Lerp(t, from.b, to.b)
	out.a = Lerp(t, from.a or 255, to.a or 255)
	return out
end

--- "3h ago", "in 2d", "just now".
function UI.RelativeTime(timestamp)
	local diff = timestamp - os.time()
	local abs = math.abs(diff)
	local text
	if abs < 45 then return "just now"
	elseif abs < 3600 then text = math.floor(abs / 60) .. "m"
	elseif abs < 86400 then text = math.floor(abs / 3600) .. "h"
	elseif abs < 86400 * 60 then text = math.floor(abs / 86400) .. "d"
	else text = math.floor(abs / (86400 * 30)) .. "mo" end
	return diff > 0 and ("in " .. text) or (text .. " ago")
end

-- Toasts ---------------------------------------------------------------------------

local TOAST_ICONS = { success = "check_circle", danger = "error", warning = "warning", info = "info" }
UI.toasts = UI.toasts or {}

local function layoutToasts()
	local y = UI.Scale(24)
	for _, toast in ipairs(UI.toasts) do
		if IsValid(toast) then
			toast.targetY = y
			y = y + toast:GetTall() + UI.Scale(8)
		end
	end
end

--- Shows a small notification in the top-right corner. kind: success, danger, warning, info.
function UI.Toast(text, kind, seconds)
	kind = kind or "info"
	local fg = UI.KindColors(kind)
	local p = vgui.Create("DPanel")
	p:SetDrawOnTop(true)
	surface.SetFont(UI.Font(15, 600))
	local tw = surface.GetTextSize(text)
	local w = math.min(math.max(tw + UI.Scale(64), UI.Scale(220)), UI.Scale(520))
	p:SetSize(w, UI.Scale(44))
	p:SetPos(ScrW(), UI.Scale(24))
	p.born = RealTime()
	p.life = seconds or 4
	p.targetY = UI.Scale(24)
	p.Paint = function(self, pw, ph)
		DisableClipping(true)
		UI.DrawShadow(0, 0, pw, ph, UI.Scale(8))
		DisableClipping(false)
		UI.DrawBox(0, 0, pw, ph, T.card, T.borderStrong)
		draw.RoundedBoxEx(UI.Scale(T.radius), 0, 0, UI.Scale(4), ph, fg, true, false, true, false)
		UI.DrawIcon(TOAST_ICONS[kind] or "info", UI.Scale(14), (ph - UI.Scale(20)) / 2, UI.Scale(20), fg)
		draw.SimpleText(text, UI.Font(15, 600), UI.Scale(44), ph / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	p.Think = function(self)
		local age = RealTime() - self.born
		local x = ScrW() - self:GetWide() - UI.Scale(24)
		if age > self.life then x = ScrW() + 10 end
		local cx, cy = self:GetPos()
		self:SetPos(Lerp(FrameTime() * 12, cx, x), Lerp(FrameTime() * 12, cy, self.targetY))
		if age > self.life + 0.4 then
			self:Remove()
			table.RemoveByValue(UI.toasts, self)
			layoutToasts()
		end
	end
	table.insert(UI.toasts, 1, p)
	while #UI.toasts > 5 do
		local old = table.remove(UI.toasts)
		if IsValid(old) then old:Remove() end
	end
	layoutToasts()
	if kind == "danger" then surface.PlaySound("buttons/button10.wav") end
	return p
end
