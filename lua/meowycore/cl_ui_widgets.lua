--[[
	More MeowyCore widgets:
		MeowyCore.List      column list with selectable rows (data per row)
		MeowyCore.Combo     themed dropdown
		MeowyCore.Check     themed checkbox with label
		MeowyCore.NavButton sidebar navigation button
		MeowyCore.Label     themed label helper: MeowyCore.UI.Label(parent, text, size, weight, color)
]]

local UI = MeowyCore.UI
local T = UI.Theme

function UI.Label(parent, text, size, weight, color)
	local l = vgui.Create("DLabel", parent)
	l:SetFont(UI.Font(size or 16, weight or 500))
	l:SetTextColor(color or T.text)
	l:SetText(text or "")
	l:SizeToContents()
	return l
end

-- List ------------------------------------------------------------------------
--[[
	local list = vgui.Create("MeowyCore.List", parent)
	list:SetColumns({ { label = "Name", width = 0.4 }, { label = "Rank", width = 0.3 }, ... })
	list:AddRow({ "Bob", "Admin" }, data, { [2] = rankColor })
	list.OnSelect = function(self, data, row) end
]]

local LIST = {}

function LIST:Init()
	self.columns = {}
	self.rows = {}
	self.selected = nil
	self.header = vgui.Create("Panel", self)
	self.header:Dock(TOP)
	self.header:SetTall(UI.Scale(28))
	self.header.Paint = function(_, w, h)
		draw.RoundedBoxEx(UI.Scale(T.radius), 0, 0, w, h, T.surface, true, true, false, false)
		local x = UI.Scale(10)
		for _, col in ipairs(self.columns) do
			draw.SimpleText(col.label, UI.Font(14, 700), x, h / 2, T.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + col.width * (w - UI.Scale(20))
		end
	end
	self.scroll = vgui.Create("MeowyCore.Scroll", self)
	self.scroll:Dock(FILL)
	self.empty = ""
end

function LIST:SetColumns(columns) self.columns = columns end
function LIST:SetEmptyText(text) self.empty = text end

function LIST:Clear()
	self.scroll:Clear()
	self.rows = {}
	self.selected = nil
end

function LIST:AddRow(values, data, colors)
	local row = self.scroll:Add("DButton")
	row:SetText("")
	row:Dock(TOP)
	row:SetTall(UI.Scale(30))
	row.values, row.data, row.colors = values, data, colors or {}
	row.hover = 0
	row.Paint = function(btn, w, h)
		btn.hover = Lerp(FrameTime() * 14, btn.hover, btn:IsHovered() and 1 or 0)
		if self.selected == btn then
			draw.RoundedBox(UI.Scale(4), 0, 0, w, h, T.surfaceHover)
			surface.SetDrawColor(T.accent)
			surface.DrawRect(0, UI.Scale(6), UI.Scale(3), h - UI.Scale(12))
		elseif btn.hover > 0.02 then
			draw.RoundedBox(UI.Scale(4), 0, 0, w, h, T.surfaceAlt)
		end
		local font = UI.Font(15, 500)
		if btn.cacheW ~= w then
			-- Truncate to column widths once per width, not every frame.
			btn.cacheW, btn.texts = w, {}
			surface.SetFont(font)
			for i, col in ipairs(self.columns) do
				local colW = col.width * (w - UI.Scale(20))
				local text = tostring(btn.values[i] or "")
				if surface.GetTextSize(text) > colW - UI.Scale(8) then
					while #text > 1 and surface.GetTextSize(text .. "…") > colW - UI.Scale(8) do
						text = string.sub(text, 1, -2)
					end
					text = text .. "…"
				end
				btn.texts[i] = text
			end
		end
		local x = UI.Scale(10)
		for i, col in ipairs(self.columns) do
			draw.SimpleText(btn.texts[i], font, x, h / 2, btn.colors[i] or T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + col.width * (w - UI.Scale(20))
		end
	end
	row.DoClick = function(btn)
		self.selected = btn
		if self.OnSelect then self:OnSelect(btn.data, btn) end
	end
	row.DoDoubleClick = function(btn)
		if self.OnDoubleClick then self:OnDoubleClick(btn.data, btn) end
	end
	table.insert(self.rows, row)
	return row
end

function LIST:Paint(w, h)
	draw.RoundedBox(UI.Scale(T.radius), 0, 0, w, h, T.surfaceAlt)
	if #self.rows == 0 and self.empty ~= "" then
		draw.SimpleText(self.empty, UI.Font(15, 500), w / 2, h / 2, T.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("MeowyCore.List", LIST, "Panel")

-- Combo -----------------------------------------------------------------------

local COMBO = {}

function COMBO:Init()
	self:SetFont(UI.Font(16, 500))
	self:SetTextColor(T.text)
	self:SetTall(UI.Scale(32))
end

function COMBO:Paint(w, h)
	draw.RoundedBox(UI.Scale(T.radius), 0, 0, w, h, self:IsHovered() and T.surfaceHover or T.surfaceAlt)
end

function COMBO:OpenMenu(...)
	DComboBox.OpenMenu(self, ...)
	if IsValid(self.Menu) then
		self.Menu.Paint = function(_, w, h) draw.RoundedBox(UI.Scale(4), 0, 0, w, h, T.surface) end
		for _, opt in ipairs(self.Menu:GetCanvas():GetChildren()) do
			opt:SetFont(UI.Font(15, 500))
			opt:SetTextColor(T.text)
			opt.Paint = function(o, w, h)
				if o:IsHovered() then draw.RoundedBox(0, 0, 0, w, h, T.surfaceHover) end
			end
		end
	end
end

vgui.Register("MeowyCore.Combo", COMBO, "DComboBox")

-- Check -----------------------------------------------------------------------

local CHECK = {}

function CHECK:Init()
	self:SetText("")
	self.checked = false
	self.label = ""
	self:SetTall(UI.Scale(26))
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
	draw.RoundedBox(UI.Scale(4), 0, y, box, box, self.checked and T.accent or T.surfaceHover)
	if self.checked then
		draw.RoundedBox(UI.Scale(2), UI.Scale(5), y + UI.Scale(5), box - UI.Scale(10), box - UI.Scale(10), T.accentText)
	end
	draw.SimpleText(self.label, UI.Font(15, 500), box + UI.Scale(8), h / 2, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.Check", CHECK, "DButton")

-- NavButton -------------------------------------------------------------------

local NAV = {}

function NAV:Init()
	self:SetText("")
	self.label = ""
	self.active = false
	self.hover = 0
	self:SetTall(UI.Scale(38))
end

function NAV:SetLabel(text) self.label = text end
function NAV:SetActive(b) self.active = b end

function NAV:Paint(w, h)
	self.hover = Lerp(FrameTime() * 14, self.hover, self:IsHovered() and 1 or 0)
	if self.active then
		draw.RoundedBox(UI.Scale(T.radius), 0, 0, w, h, T.surfaceHover)
		surface.SetDrawColor(T.accent)
		surface.DrawRect(0, UI.Scale(8), UI.Scale(3), h - UI.Scale(16))
	elseif self.hover > 0.02 then
		draw.RoundedBox(UI.Scale(T.radius), 0, 0, w, h, T.surfaceAlt)
	end
	draw.SimpleText(self.label, UI.Font(16, 600), UI.Scale(14), h / 2, self.active and T.text or T.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("MeowyCore.NavButton", NAV, "DButton")
