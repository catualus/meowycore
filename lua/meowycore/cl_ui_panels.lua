--[[
	MeowyCore base panels v2:
		MeowyCore.Frame      window: header (icon, title, subtitle), shadow, Esc to close
		MeowyCore.Button     variants primary / secondary / ghost / danger, optional icon
		MeowyCore.TextEntry  input with visible surface, border and focus ring
		MeowyCore.SearchBox  input with a search icon and a clear button
		MeowyCore.Scroll     scroll panel with a thin themed scrollbar
	plus dialogs: MeowyCore.UI.Confirm(...) and MeowyCore.UI.Prompt(...)
]]

local UI = MeowyCore.UI
local T = UI.Theme

local HEADER = 56

-- Frame -----------------------------------------------------------------------------

UI.openFrames = UI.openFrames or {}

local FRAME = {}

function FRAME:Init()
	self.title, self.subtitle, self.icon = "", nil, nil
	self.draggable = true
	self.escClose = true
	self:DockPadding(UI.Scale(16), UI.Scale(HEADER + 8), UI.Scale(16), UI.Scale(16))

	self.close = vgui.Create("DButton", self)
	self.close:SetText("")
	self.close.hover = 0
	self.close.col = Color(0, 0, 0)
	self.close.DoClick = function() self:Close() end
	self.close.Paint = function(btn, w, h)
		btn.hover = Lerp(FrameTime() * 14, btn.hover, btn:IsHovered() and 1 or 0)
		if btn.hover > 0.02 then UI.RoundedBox(math.floor(w / 2), 0, 0, w, h, T.hover) end
		local s = math.floor(w * 0.6)
		UI.DrawIcon("close", (w - s) / 2, (h - s) / 2, s, UI.LerpColor(btn.hover, T.textDim, T.text, btn.col))
	end
	table.insert(UI.openFrames, self)
end

function FRAME:SetTitle(text) self.title = text end
function FRAME:SetSubtitle(text) self.subtitle = text end
function FRAME:SetIcon(name) self.icon = name end
function FRAME:SetDraggable(b) self.draggable = b end
function FRAME:SetEscClose(b) self.escClose = b end

function FRAME:Close()
	if self.OnClose then self:OnClose() end
	self:Remove()
end

function FRAME:OnRemove()
	table.RemoveByValue(UI.openFrames, self)
end

function FRAME:PerformLayout(w)
	local size = UI.Scale(32)
	self.close:SetSize(size, size)
	self.close:SetPos(w - size - UI.Scale(12), (UI.Scale(HEADER) - size) / 2)
end

function FRAME:OnMousePressed(code)
	if code == MOUSE_LEFT and self.draggable and gui.MouseY() - self:GetY() < UI.Scale(HEADER) then
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

function FRAME:OnKeyCodePressed(code)
	if code == KEY_F and input.IsControlDown() and self.OnSearchShortcut then
		self:OnSearchShortcut()
		return true
	end
end

function FRAME:Paint(w, h)
	DisableClipping(true)
	UI.DrawShadow(0, 0, w, h)
	DisableClipping(false)
	UI.DrawBox(0, 0, w, h, T.bg, T.border)
	local r = UI.Scale(T.radius)
	UI.RoundedBoxEx(r, 1, 1, w - 2, UI.Scale(HEADER), T.panel, true, true, false, false)
	surface.SetDrawColor(T.border)
	surface.DrawRect(1, UI.Scale(HEADER), w - 2, 1)

	local x = UI.Scale(18)
	if self.icon then
		local s = UI.Scale(30)
		UI.RoundedBox(UI.Scale(T.radiusSmall), x, (UI.Scale(HEADER) - s) / 2, s, s, T.accentSoft)
		UI.DrawIcon(self.icon, x + UI.Scale(5), (UI.Scale(HEADER) - s) / 2 + UI.Scale(5), s - UI.Scale(10), T.accent)
		x = x + s + UI.Scale(12)
	end
	if self.subtitle then
		draw.SimpleText(self.title, UI.Font(18, 700), x, UI.Scale(HEADER) / 2 - UI.Scale(1), T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		draw.SimpleText(self.subtitle, UI.Font(13, 500), x, UI.Scale(HEADER) / 2 + UI.Scale(1), T.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	else
		draw.SimpleText(self.title, UI.Font(18, 700), x, UI.Scale(HEADER) / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("MeowyCore.Frame", FRAME, "EditablePanel")

-- Esc closes the topmost frame instead of opening the pause menu.
hook.Add("OnPauseMenuShow", "mcore_ui_frames", function()
	for i = #UI.openFrames, 1, -1 do
		local f = UI.openFrames[i]
		if IsValid(f) and f:IsVisible() and f.escClose then
			f:Close()
			return false
		end
	end
end)

-- Button ------------------------------------------------------------------------------

local BUTTON = {}

local VARIANTS = {
	primary = function() return T.accent, T.accentText, nil end,
	secondary = function() return T.input, T.text, T.border end,
	ghost = function() return nil, T.textDim, nil end,
	danger = function() return T.dangerSoft, T.danger, nil end,
	dangerSolid = function() return T.danger, T.accentText, nil end,
}

function BUTTON:Init()
	self:SetText("")
	self.label = ""
	self.variant = "secondary"
	self.icon = nil
	self.hover, self.press = 0, 0
	self.fill = Color(0, 0, 0)
	self:SetTall(UI.Scale(36))
end

function BUTTON:SetLabel(text) self.label = text self.textW = nil end
function BUTTON:SetIcon(name) self.icon = name end
function BUTTON:SetVariant(v) self.variant = VARIANTS[v] and v or "secondary" end
function BUTTON:SetPrimary(b) self.variant = b and "primary" or "secondary" end
function BUTTON:SetFontSize(size) self.fontSize = size self.textW = nil end

local function approach(current, target, speed)
	if current == target then return current end
	local v = Lerp(FrameTime() * speed, current, target)
	if math.abs(v - target) < 0.01 then return target end
	return v
end

function BUTTON:Paint(w, h)
	local enabled = self:IsEnabled()
	self.hover = approach(self.hover, (enabled and self:IsHovered()) and 1 or 0, 14)
	self.press = approach(self.press, (enabled and self:IsDown()) and 1 or 0, 20)
	local bg, fg, border = VARIANTS[self.variant]()
	if not enabled then fg = T.textMuted end

	local r = UI.Scale(T.radiusSmall)
	if bg then
		local fill = bg
		if not enabled then
			fill = T.card
		elseif self.hover > 0 or self.press > 0 then
			fill = UI.LerpColor(self.hover * 0.12 + self.press * 0.1, bg, T.text, self.fill)
		end
		UI.DrawBox(0, 0, w, h, fill, enabled and border or nil, r)
	elseif self.hover > 0.02 then
		UI.LerpColor(self.hover, T.bg, T.hover, self.fill)
		UI.RoundedBox(r, 0, 0, w, h, self.fill)
	end

	local font = UI.Font(self.fontSize or 15, 600)
	local iconSize = UI.Scale(18)
	if self.icon and self.label == "" then
		UI.DrawIcon(self.icon, (w - iconSize) / 2, (h - iconSize) / 2, iconSize, (self.variant == "ghost" and self.hover > 0.5) and T.text or fg)
		return
	end
	if not self.textW or self.textFont ~= font then
		surface.SetFont(font)
		self.textW, self.textFont = surface.GetTextSize(self.label), font
	end
	local tw = self.textW
	local total = tw + (self.icon and iconSize + UI.Scale(8) or 0)
	local x = (w - total) / 2
	if self.align == "left" then x = UI.Scale(12) end
	if self.icon then
		UI.DrawIcon(self.icon, x, (h - iconSize) / 2, iconSize, fg)
		x = x + iconSize + UI.Scale(8)
	end
	draw.SimpleText(self.label, font, x, h / 2, (self.variant == "ghost" and self.hover > 0.5) and T.text or fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.Button", BUTTON, "DButton")

-- TextEntry -----------------------------------------------------------------------------
--[[
	DTextEntry can't pad its text (the engine ignores text insets and model
	matrices for entry text). So MeowyCore.TextEntry is a small wrapper that
	draws the box and holds a padded inner DTextEntry ("MeowyCore.TextEntryCore").
	It forwards the usual DTextEntry API, and callbacks set on the wrapper
	(OnChange, OnEnter, OnKeyCodeTyped, OnLoseFocus, OnGetFocus) receive the
	wrapper as self, so it behaves like a DTextEntry for callers.
]]

local CORE = {}

function CORE:Init()
	self:SetFont(UI.Font(15, 500))
	self:SetPaintBackground(false)
	self:SetTextColor(T.text)
	self:SetCursorColor(T.accent)
	self:SetHighlightColor(T.accentSoft)
	self:SetPlaceholderColor(T.textMuted)
	self:SetDrawLanguageID(false)
end

function CORE:Paint(w, h)
	self:DrawTextEntryText(self:IsEnabled() and T.text or T.textMuted, T.accentSoft, T.accent)
	local ph = self:GetPlaceholderText()
	if self:GetText() == "" and ph and ph ~= "" then
		draw.SimpleText(ph, self:GetFont(), 3, h / 2, T.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("MeowyCore.TextEntryCore", CORE, "DTextEntry")

local ENTRY = {}

function ENTRY:Init()
	self:SetTall(UI.Scale(36))
	self.focus = 0
	self.ring = Color(0, 0, 0)
	self.inner = vgui.Create("MeowyCore.TextEntryCore", self)
	self.inner:Dock(FILL)
	self.inner:DockMargin(UI.Scale(7), 0, UI.Scale(7), 0)
	local wrapper = self
	self.inner.OnChange = function() if wrapper.OnChange then wrapper:OnChange() end end
	self.inner.OnEnter = function() if wrapper.OnEnter then wrapper:OnEnter() end end
	self.inner.OnKeyCodeTyped = function(_, code)
		if wrapper.OnKeyCodeTyped then return wrapper:OnKeyCodeTyped(code) end
	end
	self.inner.OnGetFocus = function(s)
		if wrapper.OnGetFocus then wrapper:OnGetFocus() end
		DTextEntry.OnGetFocus(s)
	end
	self.inner.OnLoseFocus = function(s)
		if wrapper.OnLoseFocus then wrapper:OnLoseFocus() end
		DTextEntry.OnLoseFocus(s)
	end
end

-- Forwarded DTextEntry methods.
for _, name in ipairs({
	"GetValue", "SetValue", "GetText", "SetText", "SetPlaceholderText", "GetPlaceholderText",
	"SetNumeric", "GetNumeric", "SetCaretPos", "GetCaretPos", "SetHistoryEnabled", "SelectAllText",
	"SetFont", "GetFont", "SetUpdateOnType", "SetMultiline", "SetEditable", "IsEditing",
	"AddHistory", "SetTextColor", "SetAllowNonAsciiCharacters",
}) do
	ENTRY[name] = function(self, ...) return self.inner[name](self.inner, ...) end
end

function ENTRY:RequestFocus() self.inner:RequestFocus() end
function ENTRY:HasFocus() return self.inner:HasFocus() end
function ENTRY:KillFocus() self.inner:KillFocus() end

function ENTRY:SetEnabled(b)
	self.inner:SetEnabled(b)
	self.inner:SetMouseInputEnabled(b)
	self.inner:SetKeyboardInputEnabled(b)
	self.disabled = not b
end
function ENTRY:IsEnabled() return not self.disabled end

--- Extra left padding (e.g. to leave room for an icon drawn by a parent).
function ENTRY:SetInset(x)
	self.inner:DockMargin(x, 0, UI.Scale(7), 0)
end

--- Don't draw the input box (when a parent draws it).
function ENTRY:SetNoBox(b) self.noBox = b end

function ENTRY:OnMousePressed() self.inner:RequestFocus() end

function ENTRY:Paint(w, h)
	if self.noBox then return end
	self.focus = Lerp(FrameTime() * 14, self.focus, self.inner:HasFocus() and 1 or 0)
	UI.LerpColor(self.focus, T.border, T.accent, self.ring)
	UI.DrawBox(0, 0, w, h, self.disabled and T.card or T.input, self.ring, UI.Scale(T.radiusSmall))
end

vgui.Register("MeowyCore.TextEntry", ENTRY, "Panel")

-- SearchBox ------------------------------------------------------------------------------

local SEARCH = {}

function SEARCH:Init()
	self:SetTall(UI.Scale(36))
	self.focus = 0
	self.ring = Color(0, 0, 0)
	self.entry = vgui.Create("MeowyCore.TextEntryCore", self)
	self.entry:Dock(FILL)
	self.entry:DockMargin(UI.Scale(34), 0, UI.Scale(30), 0)
	self.entry:SetPlaceholderText("Search…")
	self.entry.OnChange = function() self:Changed() end
	self.entry.OnEnter = function() if self.OnEnter then self:OnEnter(self:GetValue()) end end

	self.clear = vgui.Create("DButton", self)
	self.clear:SetText("")
	self.clear:SetVisible(false)
	self.clear.Paint = function(btn, w, h)
		UI.DrawIcon("clear", (w - UI.Scale(16)) / 2, (h - UI.Scale(16)) / 2, UI.Scale(16), btn:IsHovered() and T.text or T.textMuted)
	end
	self.clear.DoClick = function()
		self.entry:SetText("")
		self:Changed()
		if self.OnEnter then self:OnEnter("") end
	end
end

function SEARCH:Changed()
	self.clear:SetVisible(self:GetValue() ~= "")
	if self.OnChange then self:OnChange(self:GetValue()) end
end

function SEARCH:PerformLayout(w, h)
	local s = UI.Scale(28)
	self.clear:SetSize(s, s)
	self.clear:SetPos(w - s - UI.Scale(4), (h - s) / 2)
end

function SEARCH:Paint(w, h)
	self.focus = Lerp(FrameTime() * 14, self.focus, self.entry:HasFocus() and 1 or 0)
	UI.LerpColor(self.focus, T.border, T.accent, self.ring)
	UI.DrawBox(0, 0, w, h, T.input, self.ring, UI.Scale(T.radiusSmall))
	UI.DrawIcon("search", UI.Scale(10), (h - UI.Scale(18)) / 2, UI.Scale(18), self.focus > 0.5 and T.text or T.textMuted)
end

function SEARCH:OnMousePressed() self.entry:RequestFocus() end

function SEARCH:GetValue() return self.entry:GetValue() end
function SEARCH:SetValue(v) self.entry:SetText(v) self:Changed() end
function SEARCH:SetPlaceholderText(t) self.entry:SetPlaceholderText(t) end
function SEARCH:RequestFocus() self.entry:RequestFocus() end

vgui.Register("MeowyCore.SearchBox", SEARCH, "Panel")

-- Scroll -------------------------------------------------------------------------------

local SCROLL = {}

function SCROLL:Init()
	local bar = self:GetVBar()
	bar:SetWide(UI.Scale(8))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(grip, w, h)
		UI.RoundedBox(math.floor(w / 2), UI.Scale(2), 0, w - UI.Scale(4), h, grip:IsHovered() and T.borderStrong or T.hover)
	end
end

vgui.Register("MeowyCore.Scroll", SCROLL, "DScrollPanel")

-- Dialogs -------------------------------------------------------------------------------

local function dialogFrame(title, icon, height)
	local dlg = vgui.Create("MeowyCore.Frame")
	dlg:SetTitle(title)
	dlg:SetIcon(icon)
	dlg:SetSize(UI.Scale(440), height)
	dlg:Center()
	dlg:MakePopup()
	dlg:DoModal()
	dlg.opened = SysTime()
	local paint = dlg.Paint
	dlg.Paint = function(self, w, h)
		Derma_DrawBackgroundBlur(self, self.opened)
		paint(self, w, h)
	end
	return dlg
end

local function footer(dlg)
	local row = vgui.Create("Panel", dlg)
	row:Dock(BOTTOM)
	row:SetTall(UI.Scale(36))
	row:DockMargin(0, UI.Scale(12), 0, 0)
	return row
end

--- Modal yes/no dialog. danger = true styles the confirm button red.
function UI.Confirm(title, text, confirmLabel, danger, onYes, cancelLabel)
	local dlg = dialogFrame(title, danger and "warning" or "info", UI.Scale(200))
	local msg = vgui.Create("DLabel", dlg)
	msg:Dock(FILL)
	msg:SetFont(UI.Font(15, 500))
	msg:SetTextColor(T.textDim)
	msg:SetWrap(true)
	msg:SetContentAlignment(7)
	msg:SetText(text)

	local row = footer(dlg)
	local yes = vgui.Create("MeowyCore.Button", row)
	yes:Dock(RIGHT)
	yes:SetWide(UI.Scale(140))
	yes:SetVariant(danger and "dangerSolid" or "primary")
	yes:SetLabel(confirmLabel or "Confirm")
	yes.DoClick = function() dlg:Close() onYes() end
	local no = vgui.Create("MeowyCore.Button", row)
	no:Dock(RIGHT)
	no:DockMargin(0, 0, UI.Scale(8), 0)
	no:SetWide(UI.Scale(110))
	no:SetVariant("ghost")
	no:SetLabel(cancelLabel or "Cancel")
	no.DoClick = function() dlg:Close() end
	return dlg
end

UI.DURATION_PRESETS = { "15m", "1h", "1d", "1w", "perm" }

--- A fixed-height container (label + one input) docked to the top of parent.
--- Put the input in it with :Dock(TOP). Returns the container.
function UI.FieldBox(parent, labelText, bottomMargin)
	local box = vgui.Create("Panel", parent)
	box:Dock(TOP)
	box:SetTall(UI.Scale(18 + 4 + 36))
	box:DockMargin(0, 0, 0, bottomMargin or UI.Scale(12))
	local label = vgui.Create("DLabel", box)
	label:Dock(TOP)
	label:SetTall(UI.Scale(18))
	label:DockMargin(0, 0, 0, UI.Scale(4))
	label:SetFont(UI.Font(13, 700))
	label:SetTextColor(T.textDim)
	label:SetText(labelText or "")
	return box
end

--- A wrapping row of preset chips docked under an entry; clicking fills the entry.
function UI.PresetChips(parent, entry, presets, chipWidth)
	local chips = vgui.Create("DIconLayout", parent)
	chips:Dock(TOP)
	chips:DockMargin(0, 0, 0, UI.Scale(12))
	chips:SetSpaceX(UI.Scale(6))
	chips:SetSpaceY(UI.Scale(6))
	surface.SetFont(UI.Font(13, 600))
	local rowW, rows = 0, 1
	local maxW = parent:GetWide() > 0 and (parent:GetWide() - UI.Scale(32)) or UI.Scale(400)
	for _, preset in ipairs(presets) do
		local chip = chips:Add("MeowyCore.Button")
		local w = chipWidth or (surface.GetTextSize(preset) + UI.Scale(20))
		chip:SetSize(w, UI.Scale(26))
		chip:SetFontSize(13)
		chip:SetLabel(preset)
		chip.Think = function(c) c:SetVariant(entry:GetValue() == preset and "primary" or "secondary") end
		chip.DoClick = function() entry:SetValue(preset) end
		if rowW + w > maxW then rows = rows + 1 rowW = 0 end
		rowW = rowW + w + UI.Scale(6)
	end
	chips:SetTall(rows * UI.Scale(26) + (rows - 1) * UI.Scale(6))
	chips.rows = rows
	return chips
end

--- Duration preset chips (15m, 1h, 1d, 1w, perm) under an entry.
function UI.DurationChips(parent, entry)
	return UI.PresetChips(parent, entry, UI.DURATION_PRESETS, UI.Scale(58))
end

--[[
	Modal form. fields: { key, type, label, description?, default?, placeholder?, options? }
	types: "text", "number", "duration" (entry + preset chips), "choice" (options = { { label, value }, … })
	onSubmit(values) — return a string to show it as an error and keep the dialog open.
]]
function UI.Prompt(title, fields, onSubmit, opts)
	opts = opts or {}
	local height = UI.Scale(150)
	for _, f in ipairs(fields) do
		height = height + UI.Scale(f.type == "duration" and 108 or 70)
		if f.presets and #f.presets > 0 then height = height + UI.Scale(32 * math.ceil(#f.presets / 4)) end
	end
	local dlg = dialogFrame(title, opts.icon or "edit", height)

	local readers = {}
	for _, field in ipairs(fields) do
		-- Label + input live in their own container: a text entry moves itself
		-- to the end of its parent's children when focused, which would
		-- otherwise reorder the docked form.
		local box = UI.FieldBox(dlg, field.label, (field.type == "duration" or field.presets) and UI.Scale(6) or UI.Scale(12))

		if field.type == "choice" then
			local combo = vgui.Create("MeowyCore.Combo", box)
			combo:Dock(TOP)
			for _, opt in ipairs(field.options or {}) do
				combo:AddChoice(opt[1], opt[2], opt[2] == field.default)
			end
			readers[field.key] = function() local _, v = combo:GetSelected() return v end
		else
			local entry = vgui.Create("MeowyCore.TextEntry", box)
			entry:Dock(TOP)
			entry:SetValue(field.default or "")
			entry:SetPlaceholderText(field.placeholder or "")
			if field.type == "number" then entry:SetNumeric(true) end
			readers[field.key] = function() return entry:GetValue() end
			if field.type == "duration" then UI.DurationChips(dlg, entry) end
			if field.presets and #field.presets > 0 then UI.PresetChips(dlg, entry, field.presets) end
			if not dlg.firstInput then dlg.firstInput = entry end
		end
	end

	local err = vgui.Create("DLabel", dlg)
	err:Dock(TOP)
	err:SetFont(UI.Font(14, 600))
	err:SetTextColor(T.danger)
	err:SetText("")

	local row = footer(dlg)
	local ok = vgui.Create("MeowyCore.Button", row)
	ok:Dock(RIGHT)
	ok:SetWide(UI.Scale(140))
	ok:SetVariant(opts.danger and "dangerSolid" or "primary")
	ok:SetLabel(opts.confirmLabel or "Confirm")
	ok.DoClick = function()
		local values = {}
		for key, read in pairs(readers) do values[key] = read() end
		local problem = onSubmit(values)
		if isstring(problem) then err:SetText(problem) return end
		dlg:Close()
	end
	local cancel = vgui.Create("MeowyCore.Button", row)
	cancel:Dock(RIGHT)
	cancel:DockMargin(0, 0, UI.Scale(8), 0)
	cancel:SetWide(UI.Scale(110))
	cancel:SetVariant("ghost")
	cancel:SetLabel(opts.cancelLabel or "Cancel")
	cancel.DoClick = function() dlg:Close() end

	if dlg.firstInput then
		dlg.firstInput.OnEnter = ok.DoClick
		timer.Simple(0, function() if IsValid(dlg.firstInput) then dlg.firstInput:RequestFocus() end end)
	end
	return dlg
end
