--[[
	PreviewUI.lua  —  отдельный модуль для JustLib (кладётся в репозиторий рядом с JustLib.lua)

	Загружается библиотекой сам:   local Preview = JL:Preview({ Title = "Preview" })
	Руками вызывать не нужно. Модуль берёт у JustLib темы, конфиг, Unload и уведомления.

	========================  API  ========================
	local Preview = JL:Preview({
		Title = "Preview", Icon = "⬡",       -- заголовок и иконка окна
		Key = Enum.KeyCode.P,                -- (необязательно) горячая клавиша открыть/закрыть
		PreviewText = "Preview",             -- текст кнопки полного просмотра
		OnOpen = function(pv) end, OnClose = function(pv) end,
	})

	Preview:Open(target)    target: nil | "TabName" | Tab | Asset | {Tab="Models", Asset="Tree"}
	Preview:Close()         крестик делает то же самое: окно уничтожается полностью
	Preview:Toggle(target)  Preview:IsOpen()  Preview:SetTitle(text)  Preview:Destroy()
	Preview:OnClosed(fn)    вызывается после закрытия (крестиком или кодом)
	Preview:GetTab(name)    Preview:GetTabs()  Preview:GetAsset(name)

	-- сайдбар
	local Models = Preview:Tab({ Name = "Models", Icon = "⬡" })
	local All    = Preview:Tab({ Name = "All", Icon = "▦", ShowAll = true })   -- вкладка со всеми ассетами
	Preview:Header("Categories")                                              -- подпись + линия в сайдбаре
	Preview:Tab({ Name = "Weapons", Filter = function(asset) return asset.Type == "Weapon" end })

	-- ассеты («экраны» в сетке)
	local Tree = Models:Asset({
		Name = "Tree", Type = "Model",                  -- Type показывается под названием и работает как фильтр
		Creator = "Roblox", Size = "1.5 MB", Created = "01.03.2024",   -- любое поле можно не указывать
		Description = "A simple tree.",
		Info = { { Label = "Polygons", Value = "1.2k", Icon = "▤" } },  -- свои строки
		Tags = { "nature" },
		-- что показывать (достаточно одного):
		Build = function(model) ... end,                -- собрать превью из Part'ов
		Model = someModelInstance,                      -- или готовая Model/Part (клонируется)
		Image = "rbxassetid://123",                     -- или картинка
		Yaw = 0, Tilt = CFrame.Angles(0, 0, 0),
		Preview = true,                                 -- false = без кнопки полного просмотра
		Callback = function(asset) end,                 -- при выборе карточки
	})
	Models:Assets({ {...}, {...} })      Tree:Select()  Tree:Update({Name="..."})  Tree:Remove()
	Models:Clear()  Models:Open()  Models:Remove()

	-- контролы в правой панели. Можно вешать на Preview (всегда видны), на Tab (видны на вкладке)
	-- и на Asset (видны только когда выбран этот ассет)
	X:Button({ Name, Icon, Callback })
	X:Toggle({ Name, Default, Flag, Callback(v) })
	X:Dropdown({ Name, Options = {...}, MultiSelect = true, MaxSelect = 3, Default, Flag, Callback(v) })
	X:ColorPicker({ Name, Default = Color3, Flag, Callback(color) })
	X:Slider({ Name, Min, Max, Step, Default, Suffix, Flag, Callback(v) })
	X:Input({ Name, Placeholder, Default, Flag, Callback(text) })
	X:Label({ Text })          X:Divider({ Label = "text" })
	Каждый контрол возвращает объект: :Get() :Set(v) :Remove()   (Dropdown ещё :SetOptions(list))
	Flag сохраняется в конфиг JustLib и работает с пресетами.

	Настройки (размер, блюр, Auto Rotate, скорость, анимации) живут на странице "Preview UI" в Settings JustLib.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local GB, GM, G = Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Gotham
local V3, V2, CF, ANG, U2 = Vector3.new, Vector2.new, CFrame.new, CFrame.Angles, UDim2.new
local rgb = Color3.fromRGB

local DESIGN_W, DESIGN_H = 1247, 833

local B, C, ACCENTS -- заполняются в M.new (берутся у JustLib, темы меняются «на месте»)

local M = {}
M.__index = M
M.Version = "1.0"

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, inst)
end

local function stroke(inst, col, th)
	return new("UIStroke", { Color = col, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function pad(inst, l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
	}, inst)
end

local function txt(class, props, parent)
	local base = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Font = G, TextColor3 = C.txt,
		TextSize = 16, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
	}
	if class == "TextButton" then
		base.AutoButtonColor = false
	end
	for k, v in pairs(props) do
		base[k] = v
	end
	return new(class, base, parent)
end

local function tw(o, p, t, style, dir)
	TS:Create(o, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), p):Play()
end

local function safe(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[PreviewUI] " .. tostring(err))
	end
end

local function S(key, default)
	return B.cfgGet("_pv_" .. key, default)
end

local function touchLast()
	return UIS:GetLastInputType() == Enum.UserInputType.Touch
end

local function isPtr(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function beginDrag(onMove, onEnd)
	local c1, c2
	c1 = UIS.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			onMove(i)
		end
	end)
	c2 = UIS.InputEnded:Connect(function(i)
		if isPtr(i) then
			c1:Disconnect()
			c2:Disconnect()
			if onEnd then
				onEnd()
			end
		end
	end)
	return function()
		pcall(function() c1:Disconnect() end)
		pcall(function() c2:Disconnect() end)
	end
end

local function mkIcon(parent, icon, size, color)
	local s = tostring(icon or "")
	if B and B.icon then
		local ok, r = pcall(B.icon, s)
		if ok and r then
			s = tostring(r)
		end
	end
	if s:match("^rbxassetid://") or s:match("^%d+$") then
		return new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size),
			Image = s:match("^%d+$") and ("rbxassetid://" .. s) or s, ImageColor3 = color,
		}, parent)
	end
	return new("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Text = s,
		TextScaled = true, Font = GB, TextColor3 = color,
	}, parent)
end

local function mkSwitch(parent, pos, state)
	local track = new("Frame", {
		Position = pos, Size = UDim2.fromOffset(40, 22), BorderSizePixel = 0,
		BackgroundColor3 = state and C.togOn or C.togOff,
	}, parent)
	corner(track, 11)
	stroke(track, C.border, 1)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
		Position = state and U2(1, -19, 0.5, -8) or U2(0, 3, 0.5, -8),
	}, track)
	corner(knob, 8)
	local sw = {}
	function sw.Set(v)
		tw(track, { BackgroundColor3 = v and C.togOn or C.togOff }, 0.12)
		tw(knob, { Position = v and U2(1, -19, 0.5, -8) or U2(0, 3, 0.5, -8) }, 0.12)
	end
	return sw
end

local function snapNum(v, min, max, step)
	v = math.clamp(v, min, max)
	if step and step > 0 then
		v = math.floor((v - min) / step + 0.5) * step + min
		v = math.clamp(v, min, max)
	end
	return tonumber(string.format("%.6g", v)) or v
end

local function mkSlider(parent, pos, size, min, max, step, value, onChange)
	local track = new("Frame", { Position = pos, Size = size, BackgroundColor3 = C.slTrack, BorderSizePixel = 0 }, parent)
	corner(track, 3)
	local fill = new("Frame", { Size = U2(0, 0, 1, 0), BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0 }, track)
	corner(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14), AnchorPoint = V2(0.5, 0.5), Position = U2(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, 7)
	local hit = new("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = U2(1, 0, 0, 28), Position = U2(0, 0, 0.5, -14),
	}, track)
	local function show(v)
		local a = 0
		if max > min then
			a = (v - min) / (max - min)
		end
		fill.Size = U2(a, 0, 1, 0)
		knob.Position = U2(a, 0, 0.5, 0)
	end
	local function from(i)
		local ap, as = track.AbsolutePosition, track.AbsoluteSize
		local a = math.clamp((i.Position.X - ap.X) / math.max(as.X, 1), 0, 1)
		local v = snapNum(min + a * (max - min), min, max, step)
		show(v)
		onChange(v)
	end
	hit.InputBegan:Connect(function(i)
		if isPtr(i) then
			from(i)
			beginDrag(from)
		end
	end)
	show(value)
	return { Set = show }
end

--------------------------------------------------------------------
-- 3D thumbnails (из Part'ов, ассеты не нужны)
--------------------------------------------------------------------
local function part(model, size, cf, color, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.CFrame = cf
	p.Parent = model
	return p
end

local Ball, Cyl = Enum.PartType.Ball, Enum.PartType.Cylinder
local Neon, Metal = Enum.Material.Neon, Enum.Material.Metal

local function makeHead(model, color, y)
	local head = part(model, V3(2, 1, 1), CF(0, y, 0), color)
	new("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = V3(1.25, 1.25, 1.25) }, head)
	new("Decal", { Texture = "rbxasset://textures/face.png", Face = Enum.NormalId.Front }, head)
	return head
end

local Builders = {}

function Builders.R6(m)
	local c = rgb(165, 165, 192)
	part(m, V3(2, 2, 1), CF(0, 0, 0), c)
	makeHead(m, c, 1.5)
	part(m, V3(1, 2, 1), CF(-1.5, 0, 0), c)
	part(m, V3(1, 2, 1), CF(1.5, 0, 0), c)
	part(m, V3(1, 2, 1), CF(-0.5, -2, 0), c)
	part(m, V3(1, 2, 1), CF(0.5, -2, 0), c)
end

function Builders.Anime(m)
	local black, skin, hair = rgb(24, 24, 30), rgb(238, 224, 218), rgb(222, 224, 238)
	part(m, V3(2, 2, 1), CF(0, 0, 0), black)
	makeHead(m, skin, 1.5)
	part(m, V3(2.6, 0.7, 1.6), CF(0, 2.25, 0.05), hair)
	part(m, V3(2.6, 1.9, 0.6), CF(0, 1.6, 0.65), hair)
	part(m, V3(0.55, 0.8, 0.3), CF(-0.8, 2.85, 0) * ANG(0, 0, 0.25), black)
	part(m, V3(0.55, 0.8, 0.3), CF(0.8, 2.85, 0) * ANG(0, 0, -0.25), black)
	part(m, V3(1, 2, 1), CF(-1.5, 0, 0), black)
	part(m, V3(1, 2, 1), CF(1.5, 0, 0), black)
	part(m, V3(1, 2, 1), CF(-0.5, -2, 0), black)
	part(m, V3(1, 2, 1), CF(0.5, -2, 0), black)
	part(m, V3(1, 0.4, 1.1), CF(-0.5, -2.8, -0.05), hair)
	part(m, V3(1, 0.4, 1.1), CF(0.5, -2.8, -0.05), hair)
end

function Builders.Sword(m)
	local dark, neon = rgb(26, 22, 36), rgb(210, 70, 255)
	part(m, V3(0.3, 5.2, 0.12), CF(0, 1.9, 0), dark, nil, Metal)
	part(m, V3(0.06, 5.2, 0.14), CF(0.17, 1.9, 0), neon, nil, Neon)
	part(m, V3(0.06, 5.2, 0.14), CF(-0.17, 1.9, 0), neon, nil, Neon)
	part(m, V3(1.8, 0.28, 0.4), CF(0, -0.85, 0), dark, nil, Metal)
	part(m, V3(0.4, 0.4, 0.45), CF(0, -0.85, 0), neon, nil, Neon)
	part(m, V3(0.3, 1.3, 0.3), CF(0, -1.65, 0), rgb(40, 30, 55))
	part(m, V3(0.55, 0.55, 0.55), CF(0, -2.4, 0), neon, Ball, Neon)
end

function Builders.Checker(m)
	for i = 0, 5 do
		for j = 0, 5 do
			local c = ((i + j) % 2 == 0) and rgb(108, 111, 132) or rgb(68, 70, 92)
			part(m, V3(1.6, 0.2, 1.6), CF((i - 2.5) * 1.6, 0, (j - 2.5) * 1.6), c)
		end
	end
end

function Builders.Rock(m)
	local mat = Enum.Material.Slate
	part(m, V3(5, 5, 5), CF(0, 0, 0), rgb(112, 106, 96), Ball, mat)
	part(m, V3(3.5, 3.5, 3.5), CF(1.9, -0.7, 0.5), rgb(98, 94, 86), Ball, mat)
	part(m, V3(3, 3, 3), CF(-1.8, -0.8, -0.3), rgb(122, 116, 104), Ball, mat)
	part(m, V3(2.6, 2.6, 2.6), CF(0.3, 1.5, 0.6), rgb(104, 99, 90), Ball, mat)
end

function Builders.Tree(m)
	part(m, V3(4, 0.9, 0.9), CF(0, 2, 0) * ANG(0, 0, math.pi / 2), rgb(105, 74, 48), Cyl)
	part(m, V3(4.2, 4.2, 4.2), CF(0, 5.4, 0), rgb(52, 104, 48), Ball)
	part(m, V3(3.3, 3.3, 3.3), CF(-1.3, 4.4, 0.5), rgb(62, 118, 56), Ball)
	part(m, V3(3.3, 3.3, 3.3), CF(1.4, 4.3, -0.4), rgb(46, 94, 44), Ball)
	part(m, V3(2.8, 2.8, 2.8), CF(0, 7.2, 0), rgb(66, 124, 58), Ball)
end

function Builders.Car(m)
	local silver = rgb(165, 167, 182)
	part(m, V3(4.2, 1.2, 9), CF(0, 0.2, 0), silver)
	part(m, V3(3.4, 1, 4), CF(0, 1.3, 0.6), silver)
	part(m, V3(3.5, 0.6, 3.6), CF(0, 1.4, 0.6), rgb(28, 32, 46))
	part(m, V3(3.2, 0.15, 2.6), CF(0, 1.9, 0.6), silver)
	for _, x in ipairs({ -2.2, 2.2 }) do
		for _, z in ipairs({ -2.9, 3 }) do
			part(m, V3(0.9, 2, 2), CF(x, -0.4, z), rgb(24, 24, 30), Cyl)
		end
	end
	part(m, V3(0.9, 0.3, 0.1), CF(-1.3, 0.5, -4.52), rgb(255, 245, 210), nil, Neon)
	part(m, V3(0.9, 0.3, 0.1), CF(1.3, 0.5, -4.52), rgb(255, 245, 210), nil, Neon)
end

function Builders.Baseplate(m)
	part(m, V3(10, 0.8, 10), CF(0, 0, 0), rgb(88, 90, 102))
	for i = 0, 4 do
		for j = 0, 4 do
			part(m, V3(0.25, 1.1, 1.1), CF((i - 2) * 2, 0.5, (j - 2) * 2) * ANG(0, 0, math.pi / 2), rgb(96, 98, 110), Cyl)
		end
	end
end

function Builders.House(m)
	local warm = rgb(255, 190, 92)
	part(m, V3(8, 3, 6), CF(0, 0, 0), rgb(46, 50, 70))
	part(m, V3(7, 2.6, 5.4), CF(0, 2.8, 0), rgb(54, 58, 84))
	part(m, V3(8.4, 0.4, 6.4), CF(0, 4.3, 0), rgb(30, 32, 46))
	for _, x in ipairs({ -2.8, -1.2, 1.2, 2.8 }) do
		part(m, V3(1, 1.4, 0.1), CF(x, 0.1, -3.05), warm, nil, Neon)
	end
	for _, x in ipairs({ -2, 0, 2 }) do
		part(m, V3(1, 1.2, 0.1), CF(x, 2.9, -2.75), warm, nil, Neon)
	end
end

M.Builders = Builders

-- ViewportFrame с автоподбором камеры. Модель вписывается с запасом, поэтому края не обрезаются.
local function makeViewport(parent, src)
	local model
	if src.Model then
		local ok, c = pcall(function() return src.Model:Clone() end)
		if not ok or not c then
			return nil
		end
		if c:IsA("BasePart") then
			local wrap = Instance.new("Model")
			c.Parent = wrap
			c = wrap
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		model = c
	elseif src.Build then
		model = Instance.new("Model")
		local ok, err = pcall(src.Build, model)
		if not ok then
			warn("[PreviewUI] Build failed: " .. tostring(err))
		end
	else
		return nil
	end

	local okb, cf, size = pcall(function() return model:GetBoundingBox() end)
	if not okb or not cf then
		model:Destroy()
		return nil
	end
	model.WorldPivot = cf

	local vp = new("ViewportFrame", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Ambient = rgb(170, 170, 188), LightColor = rgb(255, 255, 255), LightDirection = V3(-0.4, -1, 0.8),
	}, parent)
	model.Parent = vp

	local fov = 35
	local radius = math.max(size.Magnitude * 0.5, 0.5)
	local base = radius / math.sin(math.rad(fov / 2)) * 1.3
	local cam = new("Camera", { FieldOfView = fov }, vp)
	vp.CurrentCamera = cam
	local center = cf.Position
	local dir = V3(0.45, 0.4, -1).Unit
	local tilt = src.Tilt or CF()
	local h = { yaw = src.Yaw or 0, zoom = 1 }
	local function placeCam()
		cam.CFrame = CFrame.lookAt(center + dir * base * h.zoom, center)
	end
	function h.set(y)
		h.yaw = y
		model:PivotTo(CF(center) * ANG(0, y, 0) * tilt)
	end
	function h.setZoom(z)
		h.zoom = math.clamp(z, 0.45, 2.4)
		placeCam()
	end
	placeCam()
	h.set(h.yaw)
	return h
end

local function normImage(s)
	s = tostring(s)
	if s:match("^%d+$") then
		return "rbxassetid://" .. s
	end
	return s
end

local function makeThumb(parent, asset)
	if asset.Image then
		local img = new("ImageLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
			Image = normImage(asset.Image), ScaleType = Enum.ScaleType.Fit,
		}, parent)
		img:SetAttribute("JLNoRepaint", true)
		return nil
	end
	local h = makeViewport(parent, asset)
	if h then
		return h
	end
	txt("TextLabel", {
		Text = "No preview", TextSize = 14, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
	}, parent)
	return nil
end

--------------------------------------------------------------------
-- контролы (правая панель)
--------------------------------------------------------------------
local CtrlBuilders = {}

local function rowFrame(parent, h, order)
	return new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 0, h), LayoutOrder = order }, parent)
end

local function headButton(row, h)
	local b = txt("TextButton", { BackgroundTransparency = 0, BackgroundColor3 = C.btnBg, Size = U2(1, 0, 0, h) }, row)
	corner(b, 8)
	stroke(b, C.border, 1)
	b.MouseEnter:Connect(function()
		if not touchLast() then
			tw(b, { BackgroundColor3 = C.btnHov }, 0.1)
		end
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = C.btnBg }, 0.1)
	end)
	return b
end

CtrlBuilders.Button = function(def, parent, order)
	local o = def.o
	local row = rowFrame(parent, 38, order)
	local b = headButton(row, 38)
	b.Size = UDim2.fromScale(1, 1)
	local ix = 0
	if o.Icon then
		local ic = mkIcon(b, o.Icon, 18, ACCENTS[1])
		ic.Position = U2(0, 12, 0.5, -9)
		ix = 36
	end
	def._lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center,
		Position = U2(0, ix, 0, 0), Size = U2(1, -ix - 8, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
	}, b)
	b.Activated:Connect(function()
		tw(b, { BackgroundColor3 = ACCENTS[1] }, 0.06)
		task.delay(0.14, function()
			if b.Parent then
				tw(b, { BackgroundColor3 = C.btnBg }, 0.12)
			end
		end)
		def:Fire()
	end)
	return row
end

CtrlBuilders.Toggle = function(def, parent, order)
	local row = rowFrame(parent, 38, order)
	local bg = headButton(row, 38)
	bg.Size = UDim2.fromScale(1, 1)
	local lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 15, Position = U2(0, 14, 0, 0), Size = U2(1, -72, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bg)
	local sw = mkSwitch(bg, U2(1, -54, 0.5, -11), def.value)
	def._refresh = function()
		sw.Set(def.value)
		lbl.Text = def.name
	end
	bg.Activated:Connect(function()
		def:Set(not def.value)
	end)
	return row
end

CtrlBuilders.Dropdown = function(def, parent, order)
	local HEAD = 38
	local row = rowFrame(parent, HEAD, order)
	row.ClipsDescendants = true
	local head = headButton(row, HEAD)
	local lbl = txt("TextLabel", {
		Font = GB, TextSize = 15, Position = U2(0, 14, 0, 0), Size = U2(1, -48, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	local arrow = txt("TextLabel", {
		Text = "▼", Font = GB, TextSize = 11, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center, Position = U2(1, -32, 0, 0), Size = U2(0, 30, 1, 0),
	}, head)
	local list = new("ScrollingFrame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false,
		Position = U2(0, 0, 0, HEAD + 6), Size = U2(1, 0, 0, 0),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1],
	}, row)
	corner(list, 8)
	stroke(list, C.border, 1)
	pad(list, 4, 4, 4, 4)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
	table.insert(def._pv._scrollers, list)

	local open = false
	local optBtns = {}

	local function labelText()
		local picked = {}
		for _, opt in ipairs(def.options) do
			if def.sel[opt] then
				picked[#picked + 1] = tostring(opt)
			end
		end
		if #picked == 0 or def.o.Static then
			return def.name
		end
		return def.name .. ": " .. table.concat(picked, ", ")
	end

	local function resize()
		local lh = math.min(#def.options * 30 + 8, 188)
		list.Size = U2(1, 0, 0, lh)
		row.Size = U2(1, 0, 0, open and (HEAD + 6 + lh) or HEAD)
	end

	local function rebuild()
		for _, b in ipairs(optBtns) do
			b:Destroy()
		end
		optBtns = {}
		for i, opt in ipairs(def.options) do
			local on = def.sel[opt] == true
			local ob = txt("TextButton", {
				BackgroundTransparency = on and 0.85 or 1, BackgroundColor3 = ACCENTS[1],
				Size = U2(1, 0, 0, 30), LayoutOrder = i,
			}, list)
			corner(ob, 6)
			txt("TextLabel", {
				Text = tostring(opt), Font = GB, TextSize = 14, TextColor3 = on and ACCENTS[1] or C.txt,
				Position = U2(0, 10, 0, 0), Size = U2(1, -40, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
			}, ob)
			if on then
				txt("TextLabel", {
					Text = "✓", Font = GB, TextSize = 14, TextColor3 = ACCENTS[1],
					TextXAlignment = Enum.TextXAlignment.Center, Position = U2(1, -30, 0, 0), Size = U2(0, 26, 1, 0),
				}, ob)
			end
			ob.Activated:Connect(function()
				if def.multi then
					local count = 0
					for _ in pairs(def.sel) do
						count = count + 1
					end
					if def.sel[opt] then
						def.sel[opt] = nil
					elseif count < def.maxSel then
						def.sel[opt] = true
					end
				else
					def.sel = {}
					def.sel[opt] = true
					open = false
					list.Visible = false
					arrow.Text = "▼"
				end
				def:_commit()
				resize()
			end)
			optBtns[#optBtns + 1] = ob
		end
	end

	def._refresh = function()
		lbl.Text = labelText()
		rebuild()
		resize()
	end
	head.Activated:Connect(function()
		open = not open
		list.Visible = open
		arrow.Text = open and "▲" or "▼"
		resize()
	end)
	def._refresh()
	return row
end

CtrlBuilders.ColorPicker = function(def, parent, order)
	local HEAD, PH = 38, 160
	local row = rowFrame(parent, HEAD, order)
	row.ClipsDescendants = true
	local head = headButton(row, HEAD)
	txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 15, Position = U2(0, 14, 0, 0), Size = U2(1, -80, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, head)
	local swatch = new("Frame", {
		Size = UDim2.fromOffset(40, 22), Position = U2(1, -52, 0.5, -11), BackgroundColor3 = def.value, BorderSizePixel = 0,
	}, head)
	corner(swatch, 6)
	stroke(swatch, C.border, 1)
	swatch:SetAttribute("JLNoRepaint", true)

	local pick = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false,
		Position = U2(0, 0, 0, HEAD + 6), Size = U2(1, 0, 0, PH),
	}, row)
	corner(pick, 8)
	stroke(pick, C.border, 1)

	local h, s, v = Color3.toHSV(def.value)

	local svBg = new("Frame", {
		Position = U2(0, 10, 0, 10), Size = U2(1, -52, 0, 100), BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1),
	}, pick)
	corner(svBg, 6)
	svBg:SetAttribute("JLNoRepaint", true)
	local sat = new("Frame", { Size = U2(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, svBg)
	corner(sat, 6)
	sat:SetAttribute("JLNoRepaint", true)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, sat)
	local val = new("Frame", { Size = U2(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 3 }, svBg)
	corner(val, 6)
	val:SetAttribute("JLNoRepaint", true)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, val)
	local svCursor = new("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 4 }, svBg)
	corner(svCursor, 6)
	stroke(svCursor, Color3.new(1, 1, 1), 2)
	local svHit = new("TextButton", { Size = U2(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, svBg)

	local hueBar = new("Frame", {
		Position = U2(1, -34, 0, 10), Size = U2(0, 22, 0, 100), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, pick)
	corner(hueBar, 5)
	hueBar:SetAttribute("JLNoRepaint", true)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 0, 0)), ColorSequenceKeypoint.new(0.167, rgb(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, rgb(0, 255, 0)), ColorSequenceKeypoint.new(0.5, rgb(0, 255, 255)),
			ColorSequenceKeypoint.new(0.667, rgb(0, 0, 255)), ColorSequenceKeypoint.new(0.833, rgb(255, 0, 255)),
			ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
		}),
	}, hueBar)
	local hueCursor = new("Frame", {
		Size = U2(1, 6, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
	}, hueBar)
	corner(hueCursor, 3)
	hueCursor:SetAttribute("JLNoRepaint", true)
	local hueHit = new("TextButton", { Size = U2(1, 8, 1, 0), Position = U2(0, -4, 0, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3 }, hueBar)

	local hexBox = txt("TextBox", {
		BackgroundTransparency = 0, BackgroundColor3 = C.pHdr, Font = GB, TextSize = 14,
		ClearTextOnFocus = false, Position = U2(0, 10, 0, 120), Size = U2(1, -20, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, pick)
	corner(hexBox, 6)
	stroke(hexBox, C.border, 1)

	local function visuals()
		local col = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = col
		svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = U2(s, -6, 1 - v, -6)
		hueCursor.Position = U2(0, -3, h, -3)
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. col:ToHex():upper()
		end
	end
	local function commit()
		visuals()
		def:_setColor(Color3.fromHSV(h, s, v))
	end
	local function svFrom(i)
		local ap, as = svBg.AbsolutePosition, svBg.AbsoluteSize
		s = math.clamp((i.Position.X - ap.X) / math.max(as.X, 1), 0, 1)
		v = math.clamp(1 - (i.Position.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
		commit()
	end
	local function hueFrom(i)
		local ap, as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
		h = math.clamp((i.Position.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
		commit()
	end
	svHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			svFrom(i)
			beginDrag(svFrom)
		end
	end)
	hueHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			hueFrom(i)
			beginDrag(hueFrom)
		end
	end)
	hexBox.FocusLost:Connect(function()
		local t = hexBox.Text:gsub("#", ""):gsub("%s", "")
		if #t == 6 then
			local ok, c3 = pcall(function() return Color3.fromHex(t) end)
			if ok and c3 then
				h, s, v = Color3.toHSV(c3)
				commit()
				return
			end
		end
		visuals()
	end)

	def._refresh = function()
		h, s, v = Color3.toHSV(def.value)
		visuals()
	end
	head.Activated:Connect(function()
		local on = not pick.Visible
		pick.Visible = on
		row.Size = U2(1, 0, 0, on and (HEAD + 6 + PH) or HEAD)
	end)
	visuals()
	return row
end

CtrlBuilders.Slider = function(def, parent, order)
	local row = rowFrame(parent, 56, order)
	local bg = new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, row)
	corner(bg, 8)
	stroke(bg, C.border, 1)
	local lbl = txt("TextLabel", {
		Text = def.name, Font = GB, TextSize = 15, Position = U2(0, 14, 0, 6), Size = U2(1, -90, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, bg)
	local suffix = def.o.Suffix or ""
	local vl = txt("TextLabel", {
		Font = GB, TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
		Position = U2(1, -74, 0, 6), Size = U2(0, 60, 0, 22),
	}, bg)
	local bar = mkSlider(bg, U2(0, 14, 0, 38), U2(1, -28, 0, 6), def.min, def.max, def.step, def.value, function(x)
		def:_slide(x)
		vl.Text = tostring(x) .. suffix
	end)
	def._refresh = function()
		lbl.Text = def.name
		bar.Set(def.value)
		vl.Text = tostring(def.value) .. suffix
	end
	def._refresh()
	return row
end

CtrlBuilders.Input = function(def, parent, order)
	local row = rowFrame(parent, 38, order)
	local bg = new("Frame", { BackgroundColor3 = C.input, BorderSizePixel = 0, Size = U2(1, 0, 1, 0) }, row)
	corner(bg, 8)
	stroke(bg, C.border, 1)
	local box = txt("TextBox", {
		PlaceholderText = def.o.Placeholder or def.name, PlaceholderColor3 = C.dim, Text = def.value,
		Font = GB, TextSize = 14, ClearTextOnFocus = false, Position = U2(0, 12, 0, 0), Size = U2(1, -24, 1, 0),
	}, bg)
	table.insert(def._pv._phs, box)
	box.FocusLost:Connect(function()
		def:_typed(box.Text)
	end)
	def._refresh = function()
		box.Text = def.value
	end
	return row
end

CtrlBuilders.Label = function(def, parent, order)
	local l = txt("TextLabel", {
		Text = def.value, TextSize = 14, TextColor3 = def.o.Color or C.dim, TextWrapped = true,
		Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
	}, parent)
	def._refresh = function()
		l.Text = def.value
	end
	return l
end

CtrlBuilders.Divider = function(def, parent, order)
	local row = rowFrame(parent, 18, order)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = U2(0, 0, 0.5, 0), Size = U2(1, 0, 0, 1) }, row)
	if def.o.Label then
		local w = math.min(#tostring(def.o.Label) * 8 + 16, 240)
		local bg = new("Frame", {
			BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = U2(0.5, -w / 2, 0.5, -9), Size = UDim2.fromOffset(w, 18),
		}, row)
		txt("TextLabel", {
			Text = def.o.Label, Font = GB, TextSize = 12, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, Size = U2(1, 0, 1, 0),
		}, bg)
	end
	return row
end

local function initVal(o, default)
	if o.Flag then
		return B.cfgGet(o.Flag, default), B.cfgHas(o.Flag)
	end
	return default, false
end

local function storeFlag(o, val, store)
	if o.Flag then
		B.cfgSet(o.Flag, val, store)
	end
end

local function makeControl(container, kind, o)
	o = o or {}
	local pv = container._pv
	local def = { kind = kind, o = o, _pv = pv, _container = container, name = o.Name or kind }
	local had = false

	if kind == "Toggle" then
		local v
		v, had = initVal(o, o.Default == true)
		def.value = (v == true)
	elseif kind == "Dropdown" then
		def.options = o.Options or {}
		def.multi = (o.MultiSelect == true)
		def.maxSel = o.MaxSelect or (def.multi and math.max(#def.options, 1) or 1)
		local v
		v, had = initVal(o, o.Default)
		def.sel = {}
		if type(v) == "table" then
			for _, x in ipairs(v) do
				def.sel[x] = true
			end
		elseif v ~= nil and v ~= "" then
			def.sel[v] = true
		end
	elseif kind == "ColorPicker" then
		local v
		v, had = initVal(o, o.Default or Color3.new(1, 1, 1))
		if type(v) == "table" then
			v = rgb(v[1] or 255, v[2] or 255, v[3] or 255)
		end
		def.value = v
	elseif kind == "Slider" then
		def.min = o.Min or 0
		def.max = o.Max or 100
		def.step = o.Step or 1
		local v
		v, had = initVal(o, o.Default or def.min)
		def.value = snapNum(tonumber(v) or def.min, def.min, def.max, def.step)
	elseif kind == "Input" then
		local v
		v, had = initVal(o, o.Default or "")
		def.value = tostring(v or "")
	elseif kind == "Label" then
		def.value = tostring(o.Text or o.Name or "")
	end

	function def:Get()
		if kind == "Dropdown" then
			local arr = {}
			for _, opt in ipairs(self.options) do
				if self.sel[opt] then
					arr[#arr + 1] = opt
				end
			end
			if self.multi then
				return arr
			end
			return arr[1]
		end
		return self.value
	end

	function def:Fire()
		safe(o.Callback, self)
	end

	function def:_commit() -- Dropdown
		local v = self:Get()
		storeFlag(o, v)
		if self._refresh then
			self._refresh()
		end
		safe(o.Callback, v)
	end

	function def:_setColor(col, silent)
		self.value = col
		storeFlag(o, col, { math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255) })
		if self._refresh and silent then
			self._refresh()
		end
		if not silent then
			safe(o.Callback, col)
		end
	end

	function def:_slide(v)
		self.value = v
		storeFlag(o, v)
		safe(o.Callback, v)
	end

	function def:_typed(t)
		self.value = t
		storeFlag(o, t)
		safe(o.Callback, t)
	end

	function def:Set(v, silent)
		if kind == "Toggle" then
			self.value = (v == true)
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Dropdown" then
			self.sel = {}
			if type(v) == "table" then
				for _, x in ipairs(v) do
					self.sel[x] = true
				end
			elseif v ~= nil and v ~= "" then
				self.sel[v] = true
			end
			storeFlag(o, self:Get())
			if not silent then
				safe(o.Callback, self:Get())
			end
		elseif kind == "ColorPicker" then
			if type(v) == "table" then
				v = rgb(v[1] or 255, v[2] or 255, v[3] or 255)
			end
			self:_setColor(v, true)
			if not silent then
				safe(o.Callback, v)
			end
		elseif kind == "Slider" then
			self.value = snapNum(tonumber(v) or self.min, self.min, self.max, self.step)
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Input" then
			self.value = tostring(v or "")
			storeFlag(o, self.value)
			if not silent then
				safe(o.Callback, self.value)
			end
		elseif kind == "Label" then
			self.value = tostring(v or "")
			if self._refresh then
				self._refresh()
			end
			return
		else
			return
		end
		if self._refresh then
			self._refresh()
		end
	end

	function def:SetName(t)
		self.name = tostring(t)
		if self._lbl then
			self._lbl.Text = self.name
		elseif self._refresh then
			self._refresh()
		end
	end

	function def:SetOptions(list)
		self.options = list or {}
		for k in pairs(self.sel or {}) do
			local keep = false
			for _, opt in ipairs(self.options) do
				if opt == k then
					keep = true
				end
			end
			if not keep then
				self.sel[k] = nil
			end
		end
		pv:_ctrlChanged()
	end

	function def:Remove()
		for i, d in ipairs(container._controls) do
			if d == self then
				table.remove(container._controls, i)
				break
			end
		end
		if o.Flag and B.registry[o.Flag] == self then
			B.registry[o.Flag] = nil
		end
		pv:_ctrlChanged()
	end
	def.Destroy = def.Remove

	if o.Flag then
		B.registry[o.Flag] = def
		if o.NoSave or kind == "Button" or kind == "Label" then
			B.noSave[o.Flag] = true
		else
			B.noSave[o.Flag] = nil
		end
	end

	container._controls[#container._controls + 1] = def
	pv:_ctrlChanged()
	if had and o.Callback and kind ~= "Button" and kind ~= "Label" then
		safe(o.Callback, def:Get())
	end
	return def
end

local KINDS = { "Button", "Toggle", "Dropdown", "ColorPicker", "Slider", "Input", "Label", "Divider" }

local function attachControls(obj)
	obj._controls = {}
	for _, kind in ipairs(KINDS) do
		obj[kind] = function(selfObj, o)
			return makeControl(selfObj, kind, o)
		end
	end
end

for _, kind in ipairs(KINDS) do
	M[kind] = function(selfObj, o)
		return makeControl(selfObj, kind, o)
	end
end

--------------------------------------------------------------------
-- конструктор и данные
--------------------------------------------------------------------
local function matchQuery(a, q)
	if q == "" then
		return true
	end
	local hay = string.lower(tostring(a.Name or "") .. " " .. tostring(a.Type or "") .. " " .. tostring(a.Creator or ""))
	if type(a.Tags) == "table" then
		hay = hay .. " " .. string.lower(table.concat(a.Tags, " "))
	end
	return string.find(hay, q, 1, true) ~= nil
end

function M.new(bridge, opts)
	B, C, ACCENTS = bridge, bridge.C, bridge.ACCENTS
	opts = opts or {}
	local self = setmetatable({}, M)
	self._pv = self
	self.alive = true
	self.Title = opts.Title or "Preview"
	self.Icon = opts.Icon or "⬡"
	self._opts = opts
	self._tabs, self._side, self._assets = {}, {}, {}
	self._cards = {}
	self._cons = {}
	self._fullCons = {}
	self._closedCbs = {}
	self._scrollers, self._phs = {}, {}
	self._order = 0
	self._type, self._query = "All", ""
	attachControls(self)

	table.insert(B.unloadHooks, function()
		self:Destroy()
	end)
	table.insert(B.themeHooks, function()
		self:_repaintExtras()
	end)
	if opts.Key then
		B.keep(UIS.InputBegan:Connect(function(i, gp)
			if gp or B.isListening() then
				return
			end
			if i.KeyCode == opts.Key then
				self:Toggle()
			end
		end))
	end
	return self
end

function M:Tab(o)
	o = o or {}
	local T = {
		_pv = self, _isTab = true, Name = o.Name or ("Tab " .. tostring(#self._tabs + 1)),
		Icon = o.Icon or "◼", ShowAll = o.ShowAll == true, Filter = o.Filter, assets = {},
	}
	attachControls(T)
	function T:Asset(a)
		return self._pv:_addAsset(self, a)
	end
	function T:Assets(list)
		local out = {}
		for _, a in ipairs(list or {}) do
			out[#out + 1] = self._pv:_addAsset(self, a, true)
		end
		self._pv:_assetsChanged()
		return out
	end
	function T:Clear()
		for i = #self.assets, 1, -1 do
			self.assets[i]:Remove(true)
		end
		self._pv:_assetsChanged()
	end
	function T:Open()
		return self._pv:Open(self)
	end
	function T:Remove()
		self._pv:_removeTab(self)
	end
	self._tabs[#self._tabs + 1] = T
	self._side[#self._side + 1] = { kind = "tab", tab = T }
	if self._gui then
		self:_renderSidebar()
		if not self._activeTab then
			self:_activate(T)
		end
	end
	return T
end

function M:Header(text)
	self._side[#self._side + 1] = { kind = "header", text = tostring(text or "") }
	if self._gui then
		self:_renderSidebar()
	end
	return self
end

function M:GetTab(name)
	for _, t in ipairs(self._tabs) do
		if t.Name == name then
			return t
		end
	end
	return nil
end

function M:GetTabs()
	local out = {}
	for i, t in ipairs(self._tabs) do
		out[i] = t
	end
	return out
end

function M:GetAsset(name)
	for _, a in ipairs(self._assets) do
		if a.Name == name then
			return a
		end
	end
	return nil
end

function M:_removeTab(T)
	for i = #T.assets, 1, -1 do
		T.assets[i]:Remove(true)
	end
	for i, t in ipairs(self._tabs) do
		if t == T then
			table.remove(self._tabs, i)
			break
		end
	end
	for i, e in ipairs(self._side) do
		if e.tab == T then
			table.remove(self._side, i)
			break
		end
	end
	if self._activeTab == T then
		self._activeTab = nil
	end
	if self._gui then
		self:_renderSidebar()
		self:_syncCards()
		if not self._activeTab and self._tabs[1] then
			self:_activate(self._tabs[1])
		else
			self:_applyFilter()
		end
	end
end

function M:_addAsset(tab, a, quiet)
	a = a or {}
	local asset = {}
	for k, v in pairs(a) do
		asset[k] = v
	end
	asset.Name = asset.Name or "Asset"
	asset.tab = tab
	asset._pv = self
	asset._isAsset = true
	asset._alive = true
	self._order = self._order + 1
	asset._order = self._order
	attachControls(asset)
	function asset:Select()
		self._pv:_goto(self)
	end
	function asset:Update(t)
		for k, v in pairs(t or {}) do
			self[k] = v
		end
		self._pv:_assetUpdated(self)
	end
	function asset:Remove(quietRemove)
		if not self._alive then
			return
		end
		self._alive = false
		for i, x in ipairs(self.tab.assets) do
			if x == self then
				table.remove(self.tab.assets, i)
				break
			end
		end
		for i, x in ipairs(self._pv._assets) do
			if x == self then
				table.remove(self._pv._assets, i)
				break
			end
		end
		if self._pv._selected == self then
			self._pv._selected = nil
		end
		if not quietRemove then
			self._pv:_assetsChanged()
		end
	end
	tab.assets[#tab.assets + 1] = asset
	self._assets[#self._assets + 1] = asset
	if not quiet then
		self:_assetsChanged()
	end
	return asset
end

function M:_assetsChanged()
	if not self._gui then
		return
	end
	self:_syncCards()
	self:_applyFilter()
end

function M:_assetUpdated(asset)
	if not self._gui then
		return
	end
	local c = self._cards[asset]
	if c then
		c.frame:Destroy()
		self._cards[asset] = nil
	end
	self:_syncCards()
	self:_applyFilter()
	if self._selected == asset then
		self:_renderDetails()
	end
end

function M:_ctrlChanged()
	if self._gui then
		self:_renderControls()
	end
end

function M:SetTitle(t)
	self.Title = tostring(t)
	if self._titleL then
		self._titleL.Text = self.Title
	end
end

function M:OnClosed(fn)
	if type(fn) == "function" then
		self._closedCbs[#self._closedCbs + 1] = fn
	end
end

function M:IsOpen()
	return self._gui ~= nil and not self._closing
end

--------------------------------------------------------------------
-- открыть / закрыть
--------------------------------------------------------------------
function M:Open(target)
	if not self.alive then
		return self
	end
	if self._closing then
		return self
	end
	if not self._gui then
		self:_build()
		safe(self._opts.OnOpen, self)
	end
	if target ~= nil then
		self:_goto(target)
	end
	return self
end

function M:Close()
	if not self._gui or self._closing then
		return self
	end
	self._closing = true
	if S("anim", true) and self._uiScale then
		tw(self._uiScale, { Scale = (self._scaleTarget or 1) * 0.9 }, 0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.delay(0.17, function()
			if self._closing then
				self:_teardown()
			end
		end)
	else
		self:_teardown()
	end
	return self
end

function M:Toggle(target)
	if self:IsOpen() then
		return self:Close()
	end
	return self:Open(target)
end

-- полная очистка: GUI, соединения, блюр, ссылки на элементы
function M:_teardown()
	self:_closeFull()
	for _, c in ipairs(self._cons) do
		pcall(function() c:Disconnect() end)
	end
	self._cons = {}
	for _, def in ipairs(self:_allControls()) do
		def._refresh = nil
		def._lbl = nil
	end
	for i = #B.extraRoots, 1, -1 do
		if B.extraRoots[i] == self._gui then
			table.remove(B.extraRoots, i)
		end
	end
	if self._gui then
		pcall(function() self._gui:Destroy() end)
	end
	if self._blur then
		pcall(function() self._blur:Destroy() end)
	end
	self._blur = nil
	self._gui, self._main, self._uiScale, self._titleL = nil, nil, nil, nil
	self._sidebar, self._grid, self._d, self._ctrlHolder, self._pholder = nil, nil, nil, nil, nil
	self._cards = {}
	self._sideRefs = {}
	self._scrollers, self._phs = {}, {}
	self._activeTab, self._selected = nil, nil
	self._query = ""
	self._type = "All"
	self._closing = false
	for _, fn in ipairs(self._closedCbs) do
		safe(fn, self)
	end
	safe(self._opts.OnClose, self)
end

function M:_allControls()
	local out = {}
	for _, d in ipairs(self._controls) do
		out[#out + 1] = d
	end
	for _, t in ipairs(self._tabs) do
		for _, d in ipairs(t._controls) do
			out[#out + 1] = d
		end
	end
	for _, a in ipairs(self._assets) do
		for _, d in ipairs(a._controls) do
			out[#out + 1] = d
		end
	end
	return out
end

-- Unload JustLib вызывает именно это: уничтожает UI и стирает данные
function M:Destroy()
	if not self.alive then
		return
	end
	self.alive = false
	self._closing = false
	self:_teardown()
	for _, d in ipairs(self:_allControls()) do
		if d.o.Flag and B.registry[d.o.Flag] == d then
			B.registry[d.o.Flag] = nil
		end
	end
	self._tabs, self._side, self._assets, self._controls = {}, {}, {}, {}
	if B.onDestroyed then
		B.onDestroyed(self)
	end
end

--------------------------------------------------------------------
-- настройки (страница "Preview UI" в Settings JustLib)
--------------------------------------------------------------------
function M:_layout()
	if not self._main then
		return
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or V2(1280, 720)
	local us = (tonumber(S("scale", 100)) or 100) / 100
	local s = math.clamp(v.Y * 0.94 / DESIGN_H, 0.65, 1)
	s = math.min(s, v.X * 0.96 / 900)
	s = math.max(s * us, 0.3)
	local w = math.min(DESIGN_W, v.X * 0.96 / s)
	local h = math.min(DESIGN_H, v.Y * 0.94 / s)
	self._scaleTarget = s
	if not self._animating and not self._closing then
		self._uiScale.Scale = s
	end
	self._main.Size = UDim2.fromOffset(w, h)
	local margin = (h >= 800) and 72 or 20
	if self._d then
		self._d.info.Size = U2(1, 0, 1, -(margin + 47 + 14))
		self._d.play.Position = U2(0, 19, 1, -(margin + 47))
	end
end

function M:_applyBlur()
	local pct = tonumber(S("blur", 0)) or 0
	if self._gui and pct > 0 then
		if not self._blur or not self._blur.Parent then
			self._blur = Instance.new("BlurEffect")
			self._blur.Name = "JLPreviewBlur"
			self._blur.Size = 0
			self._blur.Parent = Lighting
		end
		tw(self._blur, { Size = math.round(pct * 56 / 100) }, 0.25)
	elseif self._blur then
		pcall(function() self._blur:Destroy() end)
		self._blur = nil
	end
end

function M:ApplySettings()
	if not self._gui then
		return
	end
	self:_layout()
	self:_applyBlur()
	if self._autoBtn then
		self._autoBtn.Text = "Auto Rotate: " .. (S("autorotate", true) and "On" or "Off")
	end
end

-- то, что JustLib не перекрашивает сам (он меняет только цвета фона, текста и обводок)
function M:_repaintExtras()
	if not self._gui then
		return
	end
	for _, sf in ipairs(self._scrollers) do
		if sf and sf.Parent then
			sf.ScrollBarImageColor3 = ACCENTS[1]
		end
	end
	for _, tb in ipairs(self._phs) do
		if tb and tb.Parent then
			tb.PlaceholderColor3 = C.dim
		end
	end
	self:_styleSidebar()
	self:_markSelected()
end

--------------------------------------------------------------------
-- сборка окна
--------------------------------------------------------------------
function M:_build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "JLPreview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1000
	local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end)
	if not okp or not gui.Parent then
		gui.Parent = PG
	end
	self._gui = gui
	table.insert(B.extraRoots, gui)
	self._scrollers, self._phs = {}, {}
	self._sideRefs = {}
	self._cards = {}

	local main = new("Frame", {
		Name = "Window", AnchorPoint = V2(0.5, 0.5), Position = U2(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(DESIGN_W, DESIGN_H), BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true,
	}, gui)
	corner(main, 18)
	stroke(main, C.border, 1)
	local uiScale = new("UIScale", {}, main)
	self._main, self._uiScale = main, uiScale

	-- шапка -------------------------------------------------------
	local header = new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Size = U2(1, 0, 0, 76) }, main)
	corner(header, 18)
	new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Position = U2(0, 0, 1, -18), Size = U2(1, 0, 0, 18) }, header)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 76), Size = U2(1, 0, 0, 1) }, main)

	local hic = mkIcon(header, self.Icon, 34, C.dim)
	hic.Position = UDim2.fromOffset(28, 21)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(77, 19), Size = UDim2.fromOffset(1, 40) }, header)
	self._titleL = txt("TextLabel", {
		Text = self.Title, TextSize = 30, Font = GM, Position = UDim2.fromOffset(95, 0), Size = UDim2.fromOffset(500, 76),
	}, header)

	-- перетаскивание за шапку
	local dragArea = txt("TextButton", { Size = U2(1, -80, 1, 0) }, header)
	dragArea.InputBegan:Connect(function(i)
		if not isPtr(i) then
			return
		end
		local start = V2(i.Position.X, i.Position.Y)
		local sp = main.Position
		beginDrag(function(m)
			local d = (V2(m.Position.X, m.Position.Y) - start) / math.max(uiScale.Scale, 0.01)
			main.Position = U2(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end)
	end)

	-- крестик: уничтожает окно целиком
	local closeBtn = txt("TextButton", { AnchorPoint = V2(1, 0.5), Position = U2(1, -13, 0, 38), Size = UDim2.fromOffset(44, 44) }, header)
	local xLines = {}
	for _, rot in ipairs({ 45, -45 }) do
		local l = new("Frame", {
			AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 2.5),
			Rotation = rot, BackgroundColor3 = C.dim, BorderSizePixel = 0,
		}, closeBtn)
		corner(l, 2)
		xLines[#xLines + 1] = l
	end
	closeBtn.MouseEnter:Connect(function()
		if not touchLast() then
			for _, l in ipairs(xLines) do
				tw(l, { BackgroundColor3 = C.danger }, 0.1)
			end
		end
	end)
	closeBtn.MouseLeave:Connect(function()
		for _, l in ipairs(xLines) do
			tw(l, { BackgroundColor3 = C.dim }, 0.1)
		end
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)

	-- сайдбар -----------------------------------------------------
	local side = new("ScrollingFrame", {
		Name = "Sidebar", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 77), Size = U2(0, 267, 1, -77),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, main)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center }, side)
	pad(side, 0, 0, 17, 17)
	self._sidebar = side
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(267, 77), Size = U2(0, 1, 1, -77) }, main)

	-- центр -------------------------------------------------------
	local center = new("Frame", {
		Name = "Center", BackgroundColor3 = C.sidebar, BorderSizePixel = 0,
		Position = UDim2.fromOffset(268, 77), Size = U2(1, -(268 + 316), 1, -77),
	}, main)

	local searchBox = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 17), Size = U2(1, -(16 + 16 + 151 + 16), 0, 45),
	}, center)
	corner(searchBox, 10)
	stroke(searchBox, C.border, 1)
	local lens = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(17, 12), Size = UDim2.fromOffset(17, 17) }, searchBox)
	corner(lens, 9)
	stroke(lens, C.dim, 2)
	new("Frame", {
		BackgroundColor3 = C.dim, BorderSizePixel = 0, Rotation = 45,
		Position = UDim2.fromOffset(28, 28), Size = UDim2.fromOffset(9, 2.5),
	}, searchBox)
	local searchInput = txt("TextBox", {
		PlaceholderText = "Search...", PlaceholderColor3 = C.dim, TextSize = 18, ClearTextOnFocus = false,
		Position = UDim2.fromOffset(50, 0), Size = U2(1, -60, 1, 0),
	}, searchBox)
	table.insert(self._phs, searchInput)
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		self._query = searchInput.Text
		self:_applyFilter()
	end)

	local ddButton = txt("TextButton", {
		BackgroundTransparency = 0, BackgroundColor3 = C.input,
		AnchorPoint = V2(1, 0), Position = U2(1, -16, 0, 17), Size = UDim2.fromOffset(151, 45),
	}, center)
	corner(ddButton, 10)
	stroke(ddButton, C.border, 1)
	local ddText = txt("TextLabel", {
		Text = "All", TextSize = 18, TextColor3 = C.txt, Position = UDim2.fromOffset(18, 0), Size = U2(1, -46, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, ddButton)
	txt("TextLabel", {
		Text = "▾", TextSize = 18, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = V2(1, 0), Position = U2(1, -8, 0, 0), Size = UDim2.fromOffset(24, 45),
	}, ddButton)
	local ddList = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, Visible = false, ZIndex = 30,
		AnchorPoint = V2(1, 0), Position = U2(1, -16, 0, 68), Size = UDim2.fromOffset(151, 46),
	}, center)
	corner(ddList, 10)
	stroke(ddList, C.border, 1)
	pad(ddList, 4, 4, 4, 4)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, ddList)
	ddButton.Activated:Connect(function()
		ddList.Visible = not ddList.Visible
	end)

	local grid = new("ScrollingFrame", {
		Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.fromOffset(13, 82), Size = U2(1, -26, 1, -82),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
	}, center)
	table.insert(self._scrollers, grid)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(197, 210), CellPadding = UDim2.fromOffset(17, 17), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	-- запас вокруг карточек: рамка выбранной карточки не обрезается краями ScrollingFrame
	pad(grid, 5, 5, 5, 16)
	self._grid = grid

	local emptyL = txt("TextLabel", {
		Text = "Nothing found", TextSize = 18, TextColor3 = C.dim, Visible = false,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(0.5, 0), Position = U2(0.5, 0, 0, 130), Size = UDim2.fromOffset(300, 30),
	}, center)

	-- правая панель -----------------------------------------------
	local right = new("Frame", {
		Name = "Details", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = V2(1, 0), Position = U2(1, 0, 0, 77), Size = U2(0, 316, 1, -77),
	}, main)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Size = U2(0, 1, 1, 0) }, right)

	local info = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = U2(1, 0, 1, -133),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
	}, right)
	table.insert(self._scrollers, info)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, info)
	local function spacer(h, o)
		return new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, h), LayoutOrder = o }, info)
	end
	spacer(17, 1)
	local pbox = new("Frame", { BackgroundColor3 = C.badge, BorderSizePixel = 0, Size = U2(1, -38, 0, 235), LayoutOrder = 2 }, info)
	corner(pbox, 14)
	stroke(pbox, C.border, 1)
	spacer(14, 3)
	local title = txt("TextLabel", { Font = GB, TextSize = 22, Size = U2(1, -38, 0, 28), LayoutOrder = 4, TextTruncate = Enum.TextTruncate.AtEnd }, info)
	local typeL = txt("TextLabel", { TextSize = 15, TextColor3 = C.dim, Size = U2(1, -38, 0, 22), LayoutOrder = 5 }, info)
	spacer(10, 6)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Size = U2(1, -38, 0, 1), LayoutOrder = 7 }, info)
	spacer(8, 8)
	local rows = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -38, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 9 }, info)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, rows)
	local div2 = new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Size = U2(1, -38, 0, 1), LayoutOrder = 10 }, info)
	spacer(12, 11)
	local desc = txt("TextLabel", {
		TextSize = 16, TextColor3 = C.txt, TextWrapped = true, LineHeight = 1.4, TextYAlignment = Enum.TextYAlignment.Top,
		Size = U2(1, -38, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 12,
	}, info)
	spacer(12, 13)
	local ctrlHolder = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -38, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 14 }, info)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, ctrlHolder)
	spacer(16, 15)
	self._ctrlHolder = ctrlHolder

	local play = txt("TextButton", {
		Text = self._opts.PreviewText or "Preview", TextSize = 19, Font = GB, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = ACCENTS[1],
		Position = U2(0, 19, 1, -(72 + 47)), Size = U2(1, -38, 0, 47),
	}, right)
	corner(play, 10)
	play.Activated:Connect(function()
		self:_openFull(self._selected)
	end)

	self._d = { pbox = pbox, title = title, type = typeL, rows = rows, div2 = div2, desc = desc, play = play, info = info, empty = emptyL, ddText = ddText, ddList = ddList }

	-- события -----------------------------------------------------
	local cam = workspace.CurrentCamera
	if cam then
		self._cons[#self._cons + 1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_layout()
		end)
	end

	-- первичная отрисовка ----------------------------------------
	self:_renderSidebar()
	self:_syncCards()
	self:_layout()
	local startTab = self._tabs[1]
	local startAsset
	if S("remember", true) then
		local last = S("last", "")
		if type(last) == "string" then
			local tn, an = last:match("^(.-)|(.*)$")
			if tn and self:GetTab(tn) then
				startTab = self:GetTab(tn)
				startAsset = an
			end
		end
	end
	self._restoring = true
	self:_activate(startTab)
	if startAsset then
		for _, a in ipairs(self._assets) do
			if a.Name == startAsset and self._cards[a] and self._cards[a].frame.Visible then
				self:_select(a, true)
				break
			end
		end
	end
	self._restoring = false
	self:_renderControls()
	self:_applyBlur()

	if S("anim", true) then
		self._animating = true
		uiScale.Scale = (self._scaleTarget or 1) * 0.9
		tw(uiScale, { Scale = self._scaleTarget or 1 }, 0.2)
		task.delay(0.22, function()
			self._animating = false
			if self._uiScale and not self._closing then
				self._uiScale.Scale = self._scaleTarget or 1
			end
		end)
	end
end

--------------------------------------------------------------------
-- сайдбар
--------------------------------------------------------------------
function M:_renderSidebar()
	local side = self._sidebar
	if not side then
		return
	end
	for _, ch in ipairs(side:GetChildren()) do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then
			ch:Destroy()
		end
	end
	self._sideRefs = {}
	local ord = 0
	if #self._side == 0 then
		txt("TextLabel", {
			Text = "No tabs yet", TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Size = U2(1, -32, 0, 40), LayoutOrder = 1,
		}, side)
		return
	end
	for _, e in ipairs(self._side) do
		ord = ord + 1
		if e.kind == "header" then
			local h = new("Frame", { BackgroundTransparency = 1, Size = U2(1, -32, 0, 40), LayoutOrder = ord }, side)
			new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 6), Size = U2(1, 0, 0, 1) }, h)
			txt("TextLabel", {
				Text = e.text, Font = GM, TextSize = 17, TextColor3 = C.dim, Position = UDim2.fromOffset(14, 14), Size = U2(1, -14, 0, 22),
			}, h)
		else
			local tab = e.tab
			local b = txt("TextButton", {
				BackgroundTransparency = 1, BackgroundColor3 = ACCENTS[1], Size = U2(1, -32, 0, 50), LayoutOrder = ord,
			}, side)
			corner(b, 10)
			local ic = mkIcon(b, tab.Icon, 22, C.dim)
			ic.Position = UDim2.fromOffset(16, 14)
			local lb = txt("TextLabel", {
				Text = tab.Name, Font = GM, TextSize = 20, TextColor3 = C.dim, Position = UDim2.fromOffset(60, 0),
				Size = U2(1, -66, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
			}, b)
			b.Activated:Connect(function()
				self:_activate(tab)
			end)
			self._sideRefs[tab] = { btn = b, icon = ic, lbl = lb }
		end
	end
	self:_styleSidebar()
end

function M:_styleSidebar()
	for tab, r in pairs(self._sideRefs or {}) do
		if r.btn and r.btn.Parent then
			local on = (tab == self._activeTab)
			r.btn.BackgroundTransparency = on and 0.85 or 1
			local col = on and ACCENTS[1] or C.dim
			r.lbl.TextColor3 = on and C.txt or C.dim
			if r.icon:IsA("TextLabel") then
				r.icon.TextColor3 = col
			else
				r.icon.ImageColor3 = col
			end
		end
	end
end

function M:_activate(tab)
	if not self._gui then
		return
	end
	self._activeTab = tab
	self._type = "All"
	self:_styleSidebar()
	self:_applyFilter()
	self:_renderControls()
end

--------------------------------------------------------------------
-- карточки и фильтры
--------------------------------------------------------------------
function M:_inScope(tab, a)
	if not tab then
		return false
	end
	if tab.Filter then
		local ok, r = pcall(tab.Filter, a)
		return ok and r == true
	end
	if tab.ShowAll then
		return true
	end
	return a.tab == tab
end

function M:_makeCard(asset)
	local card = new("Frame", { Name = asset.Name, LayoutOrder = asset._order, BackgroundColor3 = C.badge, BorderSizePixel = 0, Visible = false }, self._grid)
	corner(card, 10)
	local st = stroke(card, C.border, 1)
	local thumb = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 146) }, card)
	-- внутренний отступ: модель никогда не упирается в рамку
	pad(thumb, 10, 10, 10, 6)
	local label = new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 146), Size = U2(1, 0, 1, -146) }, card)
	corner(label, 10)
	new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Size = U2(1, 0, 0, 14) }, label)
	txt("TextLabel", {
		Text = asset.Name, Font = GM, TextSize = 17, Position = UDim2.fromOffset(14, 8), Size = U2(1, -24, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)
	txt("TextLabel", {
		Text = tostring(asset.Type or asset.Creator or ""), TextSize = 14, TextColor3 = C.dim,
		Position = UDim2.fromOffset(14, 33), Size = U2(1, -24, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)
	local btn = txt("TextButton", { Size = U2(1, 0, 1, 0), ZIndex = 5 }, card)
	btn.Activated:Connect(function()
		self:_select(asset)
	end)
	return { frame = card, stroke = st, thumb = thumb, built = false }
end

function M:_ensureThumb(asset, c)
	if c.built then
		return
	end
	c.built = true
	makeThumb(c.thumb, asset)
end

function M:_syncCards()
	if not self._grid then
		return
	end
	for asset, c in pairs(self._cards) do
		if not asset._alive then
			c.frame:Destroy()
			self._cards[asset] = nil
		end
	end
	for _, asset in ipairs(self._assets) do
		if not self._cards[asset] then
			self._cards[asset] = self:_makeCard(asset)
		end
	end
end

function M:_buildTypeList()
	local d = self._d
	if not d then
		return
	end
	for _, ch in ipairs(d.ddList:GetChildren()) do
		if ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
	local types = self._types or { "All" }
	d.ddList.Size = UDim2.fromOffset(151, #types * 38 + 8)
	for i, t in ipairs(types) do
		local on = (t == self._type)
		local ob = txt("TextButton", {
			Text = t, TextSize = 17, TextColor3 = on and ACCENTS[1] or C.txt, BackgroundColor3 = ACCENTS[1],
			BackgroundTransparency = on and 0.85 or 1, Size = U2(1, 0, 0, 38), LayoutOrder = i, ZIndex = 31,
		}, d.ddList)
		pad(ob, 12, 0, 0, 0)
		corner(ob, 8)
		ob.Activated:Connect(function()
			self._type = t
			d.ddList.Visible = false
			self:_applyFilter()
		end)
	end
	d.ddText.Text = self._type
end

function M:_applyFilter()
	if not self._grid or not self._d then
		return
	end
	local tab = self._activeTab
	local types, seen = { "All" }, { All = true }
	for _, a in ipairs(self._assets) do
		if self:_inScope(tab, a) and a.Type and not seen[a.Type] then
			seen[a.Type] = true
			types[#types + 1] = a.Type
		end
	end
	if not seen[self._type] then
		self._type = "All"
	end
	self._types = types
	local q = string.lower(self._query or "")
	local shown, first, selVisible = 0, nil, false
	for _, a in ipairs(self._assets) do
		local c = self._cards[a]
		if c then
			local ok = tab ~= nil and self:_inScope(tab, a) and (self._type == "All" or a.Type == self._type) and matchQuery(a, q)
			c.frame.Visible = ok
			if ok then
				shown = shown + 1
				if not first then
					first = a
				end
				if a == self._selected then
					selVisible = true
				end
				self:_ensureThumb(a, c)
			end
		end
	end
	self._d.empty.Visible = (shown == 0)
	self:_buildTypeList()
	if selVisible then
		self:_markSelected()
	else
		self:_select(first, true)
	end
end

function M:_markSelected()
	for asset, c in pairs(self._cards) do
		local on = (asset == self._selected)
		c.stroke.Color = on and ACCENTS[1] or C.border
		c.stroke.Thickness = on and 2 or 1
	end
end

function M:_select(asset, silent)
	self._selected = asset
	if asset and not self._restoring and S("remember", true) then
		B.cfgSet("_pv_last", (self._activeTab and self._activeTab.Name or asset.tab.Name) .. "|" .. asset.Name)
	end
	self:_markSelected()
	self:_renderDetails()
	self:_renderControls()
	if asset and not silent then
		safe(asset.Callback, asset)
	end
end

function M:_goto(target)
	if not self._gui then
		return
	end
	local tab, asset
	if type(target) == "string" then
		tab = self:GetTab(target)
	elseif type(target) == "table" then
		if target._isAsset then
			asset, tab = target, target.tab
		elseif target._isTab then
			tab = target
		else
			if target.Tab then
				tab = (type(target.Tab) == "string") and self:GetTab(target.Tab) or target.Tab
			end
			if target.Asset then
				if type(target.Asset) == "string" then
					asset = self:GetAsset(target.Asset)
				else
					asset = target.Asset
				end
				if asset and not tab then
					tab = asset.tab
				end
			end
		end
	end
	if tab then
		self:_activate(tab)
	end
	if asset then
		self._query = ""
		self:_select(asset)
	end
end

--------------------------------------------------------------------
-- правая панель
--------------------------------------------------------------------
function M:_renderDetails()
	local d = self._d
	if not d then
		return
	end
	local a = self._selected
	if self._pholder then
		self._pholder:Destroy()
	end
	self._pholder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, d.pbox)
	pad(self._pholder, 12, 12, 12, 12)
	for _, ch in ipairs(d.rows:GetChildren()) do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
	if not a then
		d.title.Text = "Nothing selected"
		d.type.Text = ""
		d.desc.Text = ""
		d.desc.Visible = false
		d.div2.Visible = false
		d.play.Visible = false
		return
	end
	makeThumb(self._pholder, a)
	d.title.Text = tostring(a.Name)
	d.type.Text = tostring(a.Type or "")
	d.desc.Text = tostring(a.Description or "")
	d.desc.Visible = (a.Description ~= nil and a.Description ~= "")

	local list = {}
	if a.Creator then
		list[#list + 1] = { "☺", "Creator", a.Creator }
	end
	if a.Size then
		list[#list + 1] = { "⛶", "Size", a.Size }
	end
	if a.Created then
		list[#list + 1] = { "▤", "Created", a.Created }
	end
	for _, r in ipairs(a.Info or {}) do
		list[#list + 1] = { r.Icon or "•", r.Label or "", r.Value or "" }
	end
	for i, r in ipairs(list) do
		local row = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 34), LayoutOrder = i }, d.rows)
		local ic = mkIcon(row, r[1], 20, C.dim)
		ic.Position = UDim2.fromOffset(4, 7)
		txt("TextLabel", { Text = tostring(r[2]), TextSize = 16, TextColor3 = C.dim, Position = UDim2.fromOffset(36, 0), Size = UDim2.fromOffset(100, 34) }, row)
		txt("TextLabel", {
			Text = tostring(r[3]), TextSize = 16, TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Right,
			Position = U2(0, 130, 0, 0), Size = U2(1, -134, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
	end
	d.div2.Visible = #list > 0
	d.play.Visible = (a.Preview ~= false) and ((a.Model or a.Build or a.Image) ~= nil)
	d.play.Text = self._opts.PreviewText or "Preview"
end

function M:_renderControls()
	local holder = self._ctrlHolder
	if not holder then
		return
	end
	for _, def in ipairs(self:_allControls()) do
		def._refresh = nil
		def._lbl = nil
	end
	for _, ch in ipairs(holder:GetChildren()) do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
	local list, seen = {}, {}
	local function addFrom(container)
		if container and not seen[container] then
			seen[container] = true
			for _, d in ipairs(container._controls or {}) do
				list[#list + 1] = d
			end
		end
	end
	local a = self._selected
	if a then
		addFrom(a)
		addFrom(a.tab)
	end
	addFrom(self._activeTab)
	addFrom(self)
	for i, def in ipairs(list) do
		local b = CtrlBuilders[def.kind]
		if b then
			local ok, err = pcall(b, def, holder, i)
			if not ok then
				warn("[PreviewUI] control '" .. tostring(def.name) .. "' failed: " .. tostring(err))
			end
		end
	end
end

--------------------------------------------------------------------
-- полный просмотр (вращение, зум, Auto Rotate)
--------------------------------------------------------------------
function M:_closeFull()
	for _, c in ipairs(self._fullCons or {}) do
		pcall(function() c:Disconnect() end)
	end
	self._fullCons = {}
	if self._full then
		pcall(function() self._full:Destroy() end)
	end
	self._full, self._autoBtn = nil, nil
end

function M:_openFull(asset)
	if not self._gui or not asset or asset.Preview == false then
		return
	end
	self:_closeFull()
	local overlay = new("Frame", {
		Name = "Full", BackgroundColor3 = C.backdrop, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 50,
	}, self._gui)
	self._full = overlay
	local back = txt("TextButton", { Size = UDim2.fromScale(1, 1) }, overlay)
	back.Activated:Connect(function()
		self:_closeFull()
	end)
	local panel = new("Frame", {
		Active = true, ZIndex = 2, AnchorPoint = V2(0.5, 0.5), Position = U2(0.5, 0, 0.5, 0),
		Size = UDim2.fromScale(0.84, 0.84), BackgroundColor3 = C.panel, BorderSizePixel = 0,
	}, overlay)
	new("UISizeConstraint", { MaxSize = V2(840, 620), MinSize = V2(300, 240) }, panel)
	corner(panel, 16)
	stroke(panel, C.border, 1)

	txt("TextLabel", {
		Text = tostring(asset.Name), Font = GB, TextSize = 22, Position = UDim2.fromOffset(20, 14), Size = U2(1, -360, 0, 34),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, panel)

	local bar = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(1, 0), Position = U2(1, -14, 0, 14), Size = UDim2.fromOffset(340, 34) }, panel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)
	local function barBtn(text, w, order, cb)
		local b = txt("TextButton", {
			Text = text, Font = GB, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 0, BackgroundColor3 = C.btnBg, Size = UDim2.fromOffset(w, 34), LayoutOrder = order,
		}, bar)
		corner(b, 8)
		stroke(b, C.border, 1)
		b.Activated:Connect(cb)
		return b
	end

	local holder = new("Frame", {
		BackgroundColor3 = C.badge, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 60), Size = U2(1, -32, 1, -104),
	}, panel)
	corner(holder, 14)
	local vpHolder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, holder)
	pad(vpHolder, 16, 16, 16, 16)
	local h = makeThumb(vpHolder, asset)
	txt("TextLabel", {
		Text = "Drag to rotate  ·  Scroll / pinch to zoom", TextSize = 14, TextColor3 = C.dim,
		TextXAlignment = Enum.TextXAlignment.Center, Position = U2(0, 16, 1, -34), Size = U2(1, -32, 0, 22),
	}, panel)

	self._autoBtn = barBtn("", 150, 1, function()
		B.cfgSet("_pv_autorotate", not S("autorotate", true))
		self:ApplySettings()
	end)
	self._autoBtn.Text = "Auto Rotate: " .. (S("autorotate", true) and "On" or "Off")
	barBtn("Reset", 70, 2, function()
		if h then
			h.set(asset.Yaw or 0)
			h.setZoom(1)
		end
	end)
	barBtn("Close", 80, 3, function()
		self:_closeFull()
	end)

	if h then
		local dragging, resumeAt = false, 0
		local hit = txt("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5 }, holder)
		hit.InputBegan:Connect(function(i)
			if not isPtr(i) then
				return
			end
			dragging = true
			local lastX = i.Position.X
			beginDrag(function(m)
				h.set(h.yaw + (m.Position.X - lastX) * 0.012)
				lastX = m.Position.X
			end, function()
				dragging = false
				resumeAt = os.clock() + 1.2
			end)
		end)
		hit.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseWheel then
				h.setZoom(h.zoom * (1 - i.Position.Z * 0.1))
			end
		end)
		local pinchBase = 1
		self._fullCons[#self._fullCons + 1] = UIS.TouchPinch:Connect(function(_, scale, _, state)
			if state == Enum.UserInputState.Begin then
				pinchBase = h.zoom
			elseif state == Enum.UserInputState.Change then
				h.setZoom(pinchBase / math.max(scale, 0.05))
			end
		end)
		local last = os.clock()
		self._fullCons[#self._fullCons + 1] = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local dt = now - last
			last = now
			if S("autorotate", true) and not dragging and now > resumeAt then
				h.set(h.yaw + math.rad(tonumber(S("rotspeed", 40)) or 40) * dt)
			end
		end)
	end
end

return M
