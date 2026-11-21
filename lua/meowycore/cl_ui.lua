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

UI.scaleCache = {}

--- 1080p design size -> current resolution (minimum 1 px). Memoised: painting
--- code calls this many times per frame.
function UI.Scale(px)
	local v = UI.scaleCache[px]
	if v then return v end
	v = math.max(1, math.Round(px * ScrH() / 1080))
	UI.scaleCache[px] = v
	return v
end

hook.Add("OnScreenSizeChanged", "mcore_ui_scale", function() UI.scaleCache = {} end)

-- Fonts --------------------------------------------------------------------------

UI.fonts = UI.fonts or {}

local function createFont(key, size, weight, mono)
	surface.CreateFont("mcore_" .. key, {
		font = mono and "Roboto Mono" or T.fontFace,
		size = UI.Scale(size), weight = weight, extended = true, antialias = true,
	})
end

UI.fontCache = UI.fontCache or {}   -- [mono][size][weight] -> name (no string building per call)

--- Font name for a design size and weight, created once. Called many times
--- per frame by painting code, so the lookup allocates nothing.
function UI.Font(size, weight, opts)
	weight = weight or 500
	local mono = opts and opts.mono and true or false
	local bySize = UI.fontCache[mono]
	if not bySize then bySize = {} UI.fontCache[mono] = bySize end
	local byWeight = bySize[size]
	if not byWeight then byWeight = {} bySize[size] = byWeight end
	local name = byWeight[weight]
	if name then return name end
	local key = size .. "_" .. weight .. (mono and "_m" or "")
	createFont(key, size, weight, mono)
	name = "mcore_" .. key
	UI.fonts[key] = name
	byWeight[weight] = name
	return name
end

hook.Add("OnScreenSizeChanged", "mcore_ui_fonts", function()
	UI.scaleCache = {} -- hook order isn't guaranteed; never rebuild fonts with stale scales
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
	-- Whole pixels: half-pixel positions make icons soft and shimmer.
	surface.DrawTexturedRect(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(size + 0.5), math.floor(size + 0.5))
end

-- Drawing helpers ----------------------------------------------------------------
--[[
	Anti-aliased shapes. draw.RoundedBox stretches GMod's tiny built-in corner
	textures (8/16 px, no filtering), which gives stair-stepped corners and
	octagons instead of circles. MeowyCore draws corners from one 128 px
	quarter-disc texture with mipmaps, so every radius is smooth, and snaps
	everything to whole pixels.
]]

local CORNER = Material("meowycore/ui/corner.png", "smooth mips")
local CORNER_INV = Material("meowycore/ui/corner_inv.png", "smooth mips")
local SHADOW_MAT = Material("meowycore/ui/shadow.png", "smooth mips")
local floor, min = math.floor, math.min

local function snap(v) return floor(v + 0.5) end

-- Draws one corner of size r at x, y. The texture is the top-left shape.
local function corner(x, y, r, flipX, flipY)
	local u0, u1 = 0, 1
	local v0, v1 = 0, 1
	if flipX then u0, u1 = 1, 0 end
	if flipY then v0, v1 = 1, 0 end
	surface.DrawTexturedRectUV(x, y, r, r, u0, v0, u1, v1)
end

--- Anti-aliased rounded box; same arguments as draw.RoundedBoxEx.
function UI.RoundedBoxEx(radius, x, y, w, h, color, tl, tr, bl, br)
	x, y, w, h = snap(x), snap(y), snap(w), snap(h)
	if w <= 0 or h <= 0 then return end
	local r = floor(min(radius, w / 2, h / 2))
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)
	if r <= 0 then
		surface.DrawRect(x, y, w, h)
		return
	end
	surface.DrawRect(x + r, y, w - r * 2, h)
	surface.DrawRect(x, y + r, r, h - r * 2)
	surface.DrawRect(x + w - r, y + r, r, h - r * 2)

	surface.SetMaterial(CORNER)
	if tl then corner(x, y, r, false, false) else surface.DrawRect(x, y, r, r) end
	if tr then corner(x + w - r, y, r, true, false) else surface.DrawRect(x + w - r, y, r, r) end
	if bl then corner(x, y + h - r, r, false, true) else surface.DrawRect(x, y + h - r, r, r) end
	if br then corner(x + w - r, y + h - r, r, true, true) else surface.DrawRect(x + w - r, y + h - r, r, r) end
end

--- Anti-aliased rounded box; same arguments as draw.RoundedBox.
function UI.RoundedBox(radius, x, y, w, h, color)
	UI.RoundedBoxEx(radius, x, y, w, h, color, true, true, true, true)
end

--- Anti-aliased filled circle centred on cx, cy.
function UI.Circle(cx, cy, radius, color)
	UI.RoundedBox(radius, cx - radius, cy - radius, radius * 2, radius * 2, color)
end

--- Rounded box with a 1 px border. The fill is a concentric box one pixel in,
--- with a radius one smaller, so the ring has the same thickness all round.
function UI.DrawBox(x, y, w, h, fill, border, radius)
	radius = radius or UI.Scale(T.radius)
	if border then
		UI.RoundedBox(radius, x, y, w, h, border)
		UI.RoundedBox(math.max(0, radius - 1), x + 1, y + 1, w - 2, h - 2, fill)
	else
		UI.RoundedBox(radius, x, y, w, h, fill)
	end
end

--- Soft drop shadow around a rectangle, drawn as one 9-slice blur texture
--- (call with clipping disabled; it draws outside the rectangle).
function UI.DrawShadow(x, y, w, h, spread)
	spread = floor(spread or UI.Scale(16))
	local c = floor(spread * 1.5)           -- destination size of each 9-slice corner
	local b = 48 / 128                       -- texture border (see tools/dev/gen_ui_textures.py)
	local x0, y0 = snap(x - spread), snap(y - spread + spread / 3)
	local x1, y1 = snap(x + w + spread), snap(y + h + spread + spread / 3)
	local mw, mh = (x1 - x0) - c * 2, (y1 - y0) - c * 2
	if mw < 0 or mh < 0 then return end
	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(SHADOW_MAT)
	local du = { { x0, c, 0, b }, { x0 + c, mw, b, 1 - b }, { x1 - c, c, 1 - b, 1 } }
	local dv = { { y0, c, 0, b }, { y0 + c, mh, b, 1 - b }, { y1 - c, c, 1 - b, 1 } }
	for _, col in ipairs(du) do
		for _, row in ipairs(dv) do
			surface.DrawTexturedRectUV(col[1], row[1], col[2], row[2], col[3], row[3], col[4], row[4])
		end
	end
end

--- Rounds the corners of a child panel (e.g. AvatarImage) by painting the
--- parent's background colour over them. getColor() returns that colour.
function UI.RoundCorners(panel, radius, getColor)
	panel.PaintOver = function(_, w, h)
		local color = getColor()
		local r = floor(min(radius, w / 2, h / 2))
		surface.SetDrawColor(color.r, color.g, color.b, 255)
		surface.SetMaterial(CORNER_INV)
		corner(0, 0, r, false, false)
		corner(w - r, 0, r, true, false)
		corner(0, h - r, r, false, true)
		corner(w - r, h - r, r, true, true)
	end
end

--- Small rounded label ("pill"), vertically centred on y. Returns its width.
function UI.DrawPill(text, x, y, fg, bg, font, alignRight)
	font = font or UI.Font(13, 700)
	surface.SetFont(font)
	local tw, th = surface.GetTextSize(text)
	local padX, padY = UI.Scale(8), UI.Scale(3)
	local w, h = tw + padX * 2, th + padY * 2
	if alignRight then x = x - w end
	x, y = snap(x), snap(y - h / 2)
	UI.RoundedBox(floor(h / 2), x, y, w, h, bg)
	draw.SimpleText(text, font, x + padX, y + padY, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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
		UI.RoundedBox(UI.Scale(2), UI.Scale(6), UI.Scale(9), UI.Scale(3), ph - UI.Scale(18), fg)
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
