--[[
	MeowyCore widgets v2:
		MeowyCore.List       rows with optional avatars, custom cell renderers, right-click, empty/loading states
		MeowyCore.Combo      themed dropdown
		MeowyCore.Switch     on/off toggle
		MeowyCore.Check      checkbox with label
		MeowyCore.Segmented  2–5 option selector
		MeowyCore.ColorPicker swatches + RGB entry
		MeowyCore.NavButton  sidebar item with icon and badge
	helpers: UI.Label, UI.Card, UI.SectionTitle
]]

local UI = MeowyCore.UI
local T = UI.Theme

function UI.Label(parent, text, size, weight, color)
	local l = vgui.Create("DLabel", parent)
	l:SetFont(UI.Font(size or 15, weight or 500))
	l:SetTextColor(color or T.text)
	l:SetText(text or "")
	l:SizeToContents()
	return l
end

--- Small uppercase section title docked to the top of parent.
function UI.SectionTitle(parent, text, marginTop)
	local l = UI.Label(parent, string.upper(text), 12, 700, T.textMuted)
	l:Dock(TOP)
	l:DockMargin(0, marginTop or UI.Scale(12), 0, UI.Scale(6))
	return l
end

--- A titled card. Returns the card; add children to card.body.
function UI.Card(parent, title, description)
	local card = vgui.Create("Panel", parent)
	card:Dock(TOP)
	card:DockMargin(0, 0, 0, UI.Scale(12))
	card:DockPadding(UI.Scale(16), UI.Scale(title and (description and 60 or 44) or 14), UI.Scale(16), UI.Scale(16))
	card.Paint = function(_, w, h)
		UI.DrawBox(0, 0, w, h, T.card, T.border)
		if title then draw.SimpleText(title, UI.Font(16, 700), UI.Scale(16), UI.Scale(14), T.text) end
		if description then draw.SimpleText(description, UI.Font(13, 500), UI.Scale(16), UI.Scale(36), T.textMuted) end
	end
	card.body = card
	-- Size to children after layout.
	function card:PerformLayout()
		self:SizeToChildren(false, true)
		local _, _, _, pb = self:GetDockPadding()
		self:SetTall(self:GetTall() + pb)
	end
	return card
end

-- List -------------------------------------------------------------------------------
--[[
	list:SetColumns({
		{ label = "Name", width = 0.4 },
		{ label = "Rank", width = 0.2, render = function(value, x, y, w, h, row) UI.DrawPill(...) end },
	})
	list:SetAvatars(true)   -- row data needs .steamid64 or .player
	list:AddRow({ "Bob", "Admin" }, data, { [1] = color })
	list.OnSelect / OnDoubleClick / OnRightClick = function(self, data, row) end
]]

local LIST = {}

function LIST:Init()
	self.columns = {}
	self.rows = {}
	self.selected = nil
	self.rowH = UI.Scale(40)
	self.emptyText, self.emptyIcon = "Nothing here", "search"
	self.loading = false

	self.header = vgui.Create("Panel", self)
	self.header:Dock(TOP)
	self.header:SetTall(UI.Scale(32))
	self.header.Paint = function(_, w, h)
		surface.SetDrawColor(T.border)
		surface.DrawRect(0, h - 1, w, 1)
		local x = self:CellStart()
		local avail = w - x - UI.Scale(12)
		for _, col in ipairs(self.columns) do
			draw.SimpleText(string.upper(col.label), UI.Font(12, 700), x, h / 2, T.textMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + col.width * avail
		end
	end

	self.scroll = vgui.Create("MeowyCore.Scroll", self)
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(UI.Scale(4), UI.Scale(4), UI.Scale(4), UI.Scale(4))
end

function LIST:SetColumns(columns) self.columns = columns end
function LIST:SetAvatars(b) self.avatars = b end
function LIST:SetRowHeight(px) self.rowH = UI.Scale(px) end
function LIST:SetHeaderVisible(b) self.header:SetVisible(b) end
function LIST:SetEmptyText(text, icon) self.emptyText = text self.emptyIcon = icon or self.emptyIcon end
function LIST:SetLoading(b) self.loading = b end

function LIST:CellStart()
	return UI.Scale(12) + (self.avatars and (self.rowH - UI.Scale(12) + UI.Scale(10)) or 0)
end

function LIST:Clear()
	self.scroll:Clear()
	self.rows = {}
	self.selected = nil
end

function LIST:Select(row)
	self.selected = row
end

local function truncate(text, maxW)
	if surface.GetTextSize(text) <= maxW then return text end
	while #text > 1 and surface.GetTextSize(text .. "…") > maxW do
		text = string.sub(text, 1, -2)
	end
	return text .. "…"
end

function LIST:AddRow(values, data, colors)
	local list = self
	local row = self.scroll:Add("DButton")
	row:SetText("")
	row:Dock(TOP)
	row:DockMargin(0, 0, 0, UI.Scale(2))
	row:SetTall(self.rowH)
	row.values, row.data, row.colors = values, data, colors or {}
	row.hover = 0
	row.fill = Color(0, 0, 0)

	if self.avatars and istable(data) then
		local size = self.rowH - UI.Scale(12)
		local av = vgui.Create("AvatarImage", row)
		av:SetSize(size, size)
		av:SetPos(UI.Scale(10), UI.Scale(6))
		av:SetMouseInputEnabled(false)
		if IsValid(data.player) then av:SetPlayer(data.player, 64)
		elseif data.steamid64 then av:SetSteamID(data.steamid64, 64) end
		UI.RoundCorners(av, UI.Scale(6), function() return row.bgColor or T.card end)
	end

	row.Paint = function(btn, w, h)
		btn.hover = Lerp(FrameTime() * 16, btn.hover, btn:IsHovered() and 1 or 0)
		if list.selected == btn then
			UI.RoundedBox(UI.Scale(T.radiusSmall), 0, 0, w, h, T.hover)
			UI.RoundedBox(2, 0, UI.Scale(8), UI.Scale(3), h - UI.Scale(16), T.accent)
			btn.bgColor = T.hover
		elseif btn.hover > 0.02 then
			UI.LerpColor(btn.hover, T.card, T.input, btn.fill)
			UI.RoundedBox(UI.Scale(T.radiusSmall), 0, 0, w, h, btn.fill)
			btn.bgColor = btn.fill
		else
			btn.bgColor = T.card
		end

		local font = UI.Font(15, 500)
		local x0 = list:CellStart()
		local avail = w - x0 - UI.Scale(12)
		if btn.cacheW ~= w then
			btn.cacheW, btn.texts = w, {}
			surface.SetFont(font)
			for i, col in ipairs(list.columns) do
				if not col.render then btn.texts[i] = truncate(tostring(btn.values[i] or ""), col.width * avail - UI.Scale(10)) end
			end
		end
		local x = x0
		for i, col in ipairs(list.columns) do
			local colW = col.width * avail
			if col.render then
				col.render(btn.values[i], x, 0, colW, h, btn)
			else
				draw.SimpleText(btn.texts[i], i == 1 and UI.Font(15, 600) or font, x, h / 2, btn.colors[i] or (i == 1 and T.text or T.textDim), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
			x = x + colW
		end
	end
	row.DoClick = function(btn)
		list.selected = btn
		if list.OnSelect then list:OnSelect(btn.data, btn) end
	end
	row.DoDoubleClick = function(btn)
		if list.OnDoubleClick then list:OnDoubleClick(btn.data, btn) end
	end
	row.DoRightClick = function(btn)
		list.selected = btn
		if list.OnRightClick then list:OnRightClick(btn.data, btn) end
	end
	table.insert(self.rows, row)
	return row
end

function LIST:Paint(w, h)
	UI.DrawBox(0, 0, w, h, T.card, T.border)
	if #self.rows == 0 then
		local cy = h / 2 + UI.Scale(10)
		local s = UI.Scale(36)
		if self.loading then
			local a = (RealTime() * 360) % 360
			for i = 0, 7 do
				local ang = math.rad(a + i * 45)
				local alpha = 40 + i * 25
				UI.RoundedBox(2, w / 2 + math.cos(ang) * UI.Scale(12) - 2, cy - s / 2 + math.sin(ang) * UI.Scale(12) - 2, 5, 5, Color(T.textDim.r, T.textDim.g, T.textDim.b, alpha))
			end
		else
			UI.DrawIcon(self.emptyIcon, (w - s) / 2, cy - s - UI.Scale(6), s, T.textMuted)
			draw.SimpleText(self.emptyText, UI.Font(15, 500), w / 2, cy + UI.Scale(8), T.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

vgui.Register("MeowyCore.List", LIST, "Panel")

-- Combo --------------------------------------------------------------------------------

local COMBO = {}

function COMBO:Init()
	self:SetFont(UI.Font(15, 500))
	self:SetTextColor(T.text)
	self:SetTall(UI.Scale(36))
	self:SetTextInset(UI.Scale(10), 0)
	self.DropButton.Paint = function(_, w, h)
		UI.DrawIcon("expand_more", (w - UI.Scale(18)) / 2, (h - UI.Scale(18)) / 2, UI.Scale(18), T.textDim)
	end
end

function COMBO:Paint(w, h)
	UI.DrawBox(0, 0, w, h, self:IsHovered() and T.hover or T.input, self:IsMenuOpen() and T.accent or T.border, UI.Scale(T.radiusSmall))
end

function COMBO:OpenMenu(...)
	DComboBox.OpenMenu(self, ...)
	if not IsValid(self.Menu) then return end
	self.Menu.Paint = function(_, w, h) UI.DrawBox(0, 0, w, h, T.card, T.borderStrong, UI.Scale(T.radiusSmall)) end
	for _, opt in ipairs(self.Menu:GetCanvas():GetChildren()) do
		opt:SetFont(UI.Font(15, 500))
		opt:SetTextColor(T.text)
		opt:SetTall(UI.Scale(30))
		opt:SetTextInset(UI.Scale(10), 0)
		opt.Paint = function(o, w, h)
			if o:IsHovered() then UI.RoundedBox(UI.Scale(4), 2, 1, w - 4, h - 2, T.hover) end
		end
	end
end

vgui.Register("MeowyCore.Combo", COMBO, "DComboBox")

-- Switch -------------------------------------------------------------------------------

local SWITCH = {}

function SWITCH:Init()
	self:SetText("")
	self.on = false
	self.anim = 0
	self.fill = Color(0, 0, 0)
	self:SetSize(UI.Scale(44), UI.Scale(24))
end

function SWITCH:SetChecked(b) self.on = b == true self.anim = self.on and 1 or 0 end
function SWITCH:GetChecked() return self.on end

function SWITCH:DoClick()
	self.on = not self.on
	if self.OnChange then self:OnChange(self.on) end
end

function SWITCH:Paint(w, h)
	self.anim = Lerp(FrameTime() * 16, self.anim, self.on and 1 or 0)
	local tw, th = UI.Scale(40), UI.Scale(22)
	local y = (h - th) / 2
	UI.LerpColor(self.anim, T.hover, T.accent, self.fill)
	UI.RoundedBox(math.floor(th / 2), 0, y, tw, th, self.fill)
	local knob = th - UI.Scale(6)
	local kx = Lerp(self.anim, UI.Scale(3), tw - knob - UI.Scale(3))
	UI.RoundedBox(math.floor(knob / 2), kx, y + UI.Scale(3), knob, knob, self.on and T.accentText or T.textDim)
end

vgui.Register("MeowyCore.Switch", SWITCH, "DButton")

-- Check ---------------------------------------------------------------------------------

local CHECK = {}

function CHECK:Init()
	self:SetText("")
	self.checked = false
	self.label = ""
	self:SetTall(UI.Scale(28))
end

function CHECK:SetChecked(b) self.checked = b == true end
function CHECK:GetChecked() return self.checked end
function CHECK:SetLabel(text) self.label = text end

function CHECK:DoClick()
	self.checked = not self.checked
	if self.OnChange then self:OnChange(self.checked) end
end

function CHECK:Paint(w, h)
	local box = UI.Scale(18)
	local y = (h - box) / 2
	if self.checked then
		UI.RoundedBox(UI.Scale(4), 0, y, box, box, T.accent)
		UI.DrawIcon("check", 0, y, box, T.accentText)
	else
		UI.DrawBox(0, y, box, box, T.input, self:IsHovered() and T.borderStrong or T.border, UI.Scale(4))
	end
	draw.SimpleText(self.label, UI.Font(15, 500), box + UI.Scale(10), h / 2, T.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.Check", CHECK, "DButton")

-- Segmented -----------------------------------------------------------------------------
--[[
	seg:SetOptions({ { label = "Inherit", value = "inherit" }, { label = "Allow", value = "allow", kind = "success" }, … })
	seg:SetValue("allow")   seg.OnChange = function(self, value) end
]]

local SEG = {}

function SEG:Init()
	self.options, self.value = {}, nil
	self.buttons = {}
	self:SetTall(UI.Scale(30))
end

function SEG:SetOptions(options)
	for _, b in ipairs(self.buttons) do b:Remove() end
	self.options, self.buttons = options, {}
	for _, opt in ipairs(options) do
		local b = vgui.Create("DButton", self)
		b:SetText("")
		b.opt = opt
		b.DoClick = function()
			self.value = opt.value
			if self.OnChange then self:OnChange(opt.value) end
		end
		b.Paint = function(btn, w, h)
			local active = self.value == opt.value
			if active then
				local fg, soft = UI.KindColors(opt.kind or "accent")
				if opt.kind == "neutral" then fg, soft = T.text, T.hover end
				UI.RoundedBox(UI.Scale(4), 1, 1, w - 2, h - 2, soft)
				draw.SimpleText(opt.label, UI.Font(13, 700), w / 2, h / 2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				if btn:IsHovered() then UI.RoundedBox(UI.Scale(4), 1, 1, w - 2, h - 2, T.hover) end
				draw.SimpleText(opt.label, UI.Font(13, 600), w / 2, h / 2, T.textMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
		table.insert(self.buttons, b)
	end
	self:InvalidateLayout()
end

function SEG:SetValue(v) self.value = v end
function SEG:GetValue() return self.value end

function SEG:PerformLayout(w, h)
	local n = #self.buttons
	if n == 0 then return end
	local bw = math.floor((w - UI.Scale(4)) / n)
	for i, b in ipairs(self.buttons) do
		b:SetPos(UI.Scale(2) + (i - 1) * bw, UI.Scale(2))
		b:SetSize(bw, h - UI.Scale(4))
	end
end

function SEG:Paint(w, h)
	UI.DrawBox(0, 0, w, h, T.input, T.border, UI.Scale(T.radiusSmall))
end

vgui.Register("MeowyCore.Segmented", SEG, "Panel")

-- ColorPicker ---------------------------------------------------------------------------

local SWATCHES = {
	Color(236, 238, 243), Color(160, 166, 180), Color(255, 110, 110), Color(255, 138, 101), Color(255, 170, 90),
	Color(250, 210, 90), Color(130, 220, 120), Color(80, 200, 170), Color(90, 190, 255), Color(120, 140, 255),
	Color(175, 120, 255), Color(255, 120, 200),
}

local PICKER = {}

function PICKER:Init()
	self.color = Color(255, 255, 255)
	self:SetTall(UI.Scale(76))

	self.swatches = vgui.Create("Panel", self)
	self.swatches:Dock(TOP)
	self.swatches:SetTall(UI.Scale(30))
	for _, c in ipairs(SWATCHES) do
		local s = vgui.Create("DButton", self.swatches)
		s:SetText("")
		s:Dock(LEFT)
		s:SetWide(UI.Scale(30))
		s:DockMargin(0, 0, UI.Scale(6), 0)
		s.Paint = function(btn, w, h)
			local same = self.color.r == c.r and self.color.g == c.g and self.color.b == c.b
			if same or btn:IsHovered() then UI.RoundedBox(math.floor(w / 2), 0, 0, w, h, same and T.text or T.borderStrong) end
			UI.RoundedBox(math.floor(w / 2) - 3, 3, 3, w - 6, h - 6, c)
		end
		s.DoClick = function() self:SetColor(c, true) end
	end

	self.entry = vgui.Create("MeowyCore.TextEntry", self)
	self.entry:Dock(TOP)
	self.entry:DockMargin(UI.Scale(36), UI.Scale(8), 0, 0)
	self.entry:SetPlaceholderText("R, G, B")
	self.entry.OnChange = function(e)
		local r, g, b = string.match(e:GetValue(), "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
		if r then self:SetColor(Color(math.min(255, tonumber(r)), math.min(255, tonumber(g)), math.min(255, tonumber(b))), true, true) end
	end
end

function PICKER:SetColor(c, notify, fromEntry)
	self.color = Color(c.r, c.g, c.b)
	if not fromEntry then self.entry:SetValue(string.format("%d, %d, %d", c.r, c.g, c.b)) end
	if notify and self.OnChange then self:OnChange(self.color) end
end

function PICKER:GetColor() return self.color end

function PICKER:PaintOver()
	local _, ey = self.entry:GetPos()
	local s = self.entry:GetTall()
	UI.RoundedBox(UI.Scale(T.radiusSmall), 0, ey, s - UI.Scale(6), s, self.color)
end

vgui.Register("MeowyCore.ColorPicker", PICKER, "Panel")

-- NavButton ------------------------------------------------------------------------------

local NAV = {}

function NAV:Init()
	self:SetText("")
	self.label, self.icon, self.badge = "", nil, nil
	self.active = false
	self.hover = 0
	self.fill = Color(0, 0, 0)
	self:SetTall(UI.Scale(40))
end

function NAV:SetLabel(text) self.label = text end
function NAV:SetIcon(name) self.icon = name end
function NAV:SetActive(b) self.active = b end
function NAV:SetBadge(text) self.badge = text end

function NAV:Paint(w, h)
	self.hover = Lerp(FrameTime() * 16, self.hover, self:IsHovered() and 1 or 0)
	if self.active then
		UI.RoundedBox(UI.Scale(T.radiusSmall), 0, 0, w, h, T.accentSoft)
	elseif self.hover > 0.02 then
		UI.LerpColor(self.hover, T.panel, T.hover, self.fill)
		UI.RoundedBox(UI.Scale(T.radiusSmall), 0, 0, w, h, self.fill)
	end
	local color = self.active and T.accent or (self.hover > 0.5 and T.text or T.textDim)
	local x = UI.Scale(12)
	if self.icon then
		UI.DrawIcon(self.icon, x, (h - UI.Scale(20)) / 2, UI.Scale(20), color)
		x = x + UI.Scale(32)
	end
	draw.SimpleText(self.label, UI.Font(15, 600), x, h / 2, self.active and T.text or color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	if self.badge then
		UI.DrawPill(tostring(self.badge), w - UI.Scale(10), h / 2, T.accentText, T.accent, UI.Font(12, 700), true)
	end
end

vgui.Register("MeowyCore.NavButton", NAV, "DButton")

-- Context menu ------------------------------------------------------------------------
--[[
	local menu = MeowyCore.UI.ContextMenu()
	menu:AddOption("Copy SteamID", "content_copy", function() end)
	menu:AddSpacer()
	menu:AddOption("Ban", "gavel", function() end, true)   -- true = danger styling
	menu:Open()
]]

function UI.ContextMenu()
	local menu = DermaMenu()
	menu:SetMinimumWidth(UI.Scale(200))
	menu:SetDrawColumn(false)
	menu.Paint = function(_, w, h)
		UI.DrawBox(0, 0, w, h, T.card, T.borderStrong, UI.Scale(T.radiusSmall))
	end

	local addOption = menu.AddOption
	function menu:AddOption(label, icon, fn, danger)
		local opt = addOption(self, label, fn)
		opt:SetTall(UI.Scale(32))
		opt:SetText("")
		opt.Paint = function(o, w, h)
			if o:IsHovered() then UI.RoundedBox(UI.Scale(4), UI.Scale(4), 1, w - UI.Scale(8), h - 2, danger and T.dangerSoft or T.hover) end
			local color = danger and T.danger or (o:IsHovered() and T.text or T.textDim)
			if icon then UI.DrawIcon(icon, UI.Scale(12), (h - UI.Scale(16)) / 2, UI.Scale(16), color) end
			draw.SimpleText(label, UI.Font(14, 600), UI.Scale(38), h / 2, danger and T.danger or T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		return opt
	end

	local addSpacer = menu.AddSpacer
	function menu:AddSpacer()
		local s = addSpacer(self)
		s:SetTall(UI.Scale(9))
		s.Paint = function(_, w, h)
			surface.SetDrawColor(T.border)
			surface.DrawRect(UI.Scale(8), math.floor(h / 2), w - UI.Scale(16), 1)
		end
		return s
	end
	return menu
end
