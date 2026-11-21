--[[
	MeowyCore base panels, themed by MeowyCore.UI.Theme:
		MeowyCore.Frame      window with title bar, close button, drag
		MeowyCore.Button     flat button (primary = accent fill)
		MeowyCore.TextEntry  text input with placeholder and focus ring
		MeowyCore.Scroll     scroll panel with a thin themed scrollbar
]]

local UI = MeowyCore.UI
local T = UI.Theme

-- Frame -----------------------------------------------------------------------

local FRAME = {}

function FRAME:Init()
	self.title = ""
	self.draggable = true
	self:DockPadding(UI.Scale(12), UI.Scale(44), UI.Scale(12), UI.Scale(12))

	self.close = vgui.Create("DButton", self)
	self.close:SetText("")
	self.close.hover = 0
	self.close.DoClick = function() self:Close() end
	self.close.Paint = function(btn, w, h)
		btn.hover = Lerp(FrameTime() * 12, btn.hover, btn:IsHovered() and 1 or 0)
		local pad = math.floor(w * 0.32)
		surface.SetDrawColor(UI.LerpColor(btn.hover, T.textDim, T.danger, btn.col))
		surface.DrawLine(pad, pad, w - pad, h - pad)
		surface.DrawLine(w - pad, pad, pad, h - pad)
	end
	self.close.col = Color(0, 0, 0)
end

function FRAME:SetTitle(text) self.title = text end
function FRAME:SetDraggable(b) self.draggable = b end

function FRAME:Close()
	self:Remove()
	if self.OnClose then self:OnClose() end
end

function FRAME:PerformLayout(w)
	local size = UI.Scale(28)
	self.close:SetSize(size, size)
	self.close:SetPos(w - size - UI.Scale(8), UI.Scale(8))
end

function FRAME:OnMousePressed(code)
	if code == MOUSE_LEFT and self.draggable and gui.MouseY() - self:GetY() < UI.Scale(44) then
		self.dragging = { gui.MouseX() - self:GetX(), gui.MouseY() - self:GetY() }
		self:MouseCapture(true)
	end
end

function FRAME:OnMouseReleased()
	self.dragging = nil
	self:MouseCapture(false)
end

function FRAME:Think()
	if self.dragging then
		local x = math.Clamp(gui.MouseX() - self.dragging[1], 0, ScrW() - self:GetWide())
		local y = math.Clamp(gui.MouseY() - self.dragging[2], 0, ScrH() - self:GetTall())
		self:SetPos(x, y)
	end
end

function FRAME:Paint(w, h)
	local r = UI.Scale(T.radius)
	draw.RoundedBox(r, 0, 0, w, h, T.background)
	draw.RoundedBoxEx(r, 0, 0, w, UI.Scale(44), T.surface, true, true, false, false)
	draw.SimpleText(self.title, UI.Font(20, 600), UI.Scale(14), UI.Scale(22), T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.Frame", FRAME, "EditablePanel")

-- Button ----------------------------------------------------------------------

local BUTTON = {}

function BUTTON:Init()
	self:SetText("")
	self.label = ""
	self.primary = false
	self.hover = 0
	self.fill = Color(0, 0, 0)
	self:SetTall(UI.Scale(34))
end

function BUTTON:SetLabel(text) self.label = text end
function BUTTON:SetPrimary(b) self.primary = b end

function BUTTON:Paint(w, h)
	local enabled = self:IsEnabled()
	self.hover = Lerp(FrameTime() * 12, self.hover, (self:IsHovered() and enabled) and 1 or 0)
	local base, top, textColor
	if not enabled then
		base, top, textColor = T.surface, T.surface, T.textDim
	elseif self.primary then
		base, top, textColor = T.accent, T.text, T.accentText
	else
		base, top, textColor = T.surfaceAlt, T.surfaceHover, T.text
	end
	UI.LerpColor(self.hover * 0.25, base, top, self.fill)
	draw.RoundedBox(UI.Scale(T.radius), 0, 0, w, h, self.fill)
	draw.SimpleText(self.label, UI.Font(17, 600), w / 2, h / 2, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.Button", BUTTON, "DButton")

-- TextEntry -------------------------------------------------------------------

local ENTRY = {}

function ENTRY:Init()
	self:SetFont(UI.Font(17, 500))
	self:SetTall(UI.Scale(34))
	self:SetPaintBackground(false)
	self:SetTextColor(T.text)
	self:SetCursorColor(T.text)
	self:SetHighlightColor(T.accent)
	self:SetPlaceholderColor(T.textDim)
	self:SetDrawLanguageID(false)
end

function ENTRY:Paint(w, h)
	local r = UI.Scale(T.radius)
	if self:HasFocus() then
		draw.RoundedBox(r, 0, 0, w, h, T.accent)
		draw.RoundedBox(r, 1, 1, w - 2, h - 2, T.surfaceAlt)
	else
		draw.RoundedBox(r, 0, 0, w, h, T.surfaceAlt)
	end
	self:DrawTextEntryText(T.text, T.accent, T.text)
	if self:GetText() == "" and not self:HasFocus() and self:GetPlaceholderText() then
		draw.SimpleText(self:GetPlaceholderText(), self:GetFont(), UI.Scale(4), h / 2, T.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("MeowyCore.TextEntry", ENTRY, "DTextEntry")

-- Scroll ----------------------------------------------------------------------

local SCROLL = {}

function SCROLL:Init()
	local bar = self:GetVBar()
	bar:SetWide(UI.Scale(6))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(math.floor(w / 2), 0, 0, w, h, T.surfaceHover)
	end
end

vgui.Register("MeowyCore.Scroll", SCROLL, "DScrollPanel")
