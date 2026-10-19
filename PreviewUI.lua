--[[
	PreviewUI.lua  v2  —  отдельный модуль для JustLib (лежит в репозитории рядом с JustLib.lua)

	Загружается библиотекой сам:   local Preview = JL:Preview({ Title = "Preview" })
	Модуль берёт у JustLib темы, конфиг, Unload и уведомления.

	КАК ЭТО РАБОТАЕТ
	  Нажал на ассет  ->  справа из-под окна выезжает панель (drawer) с иконками страниц.
	  Нажал на тот же ассет ещё раз  ->  панель плавно задвигается обратно в окно.
	  Нажал на другой ассет  ->  панель остаётся и показывает его.
	  У каждой карточки возле названия три точки: меню быстрых действий (до 5 кнопок).
	  Страницы панели: Actions (кнопки/тогглы/колорпикеры...), Info, Preview (3D) и свои.

	========================  API  ========================
	local Preview = JL:Preview({
		Title = "Preview", Icon = "⬡",
		Key = Enum.KeyCode.P,                      -- (необязательно) открыть/закрыть окно
		OnOpen = function(pv) end, OnClose = function(pv) end,
	})

	Preview:Open(target)    target: nil | "TabName" | Tab | Asset | {Tab="Models", Asset="Tree", Page="preview"}
	Preview:Close()         крестик делает то же самое: окно уничтожается полностью
	Preview:CloseDrawer()   Preview:Toggle(target)  Preview:IsOpen()  Preview:SetTitle(text)  Preview:Destroy()
	Preview:OnClosed(fn)    Preview:GetTab(name)  Preview:GetTabs()  Preview:GetAsset(name)

	-- сайдбар
	local Models = Preview:Tab({ Name = "Models", Icon = "⬡" })
	local All    = Preview:Tab({ Name = "All", Icon = "▦", ShowAll = true })
	Preview:Header("Categories")
	Preview:Tab({ Name = "Weapons", Filter = function(asset) return asset.Type == "Weapon" end })

	-- ассеты
	local Tree = Models:Asset({
		Name = "Tree", Type = "Model",
		Creator = "Roblox", Created = "01.03.2024", Size = "1.5 MB", Version = "1.2",   -- всё необязательно
		Avatar = "rbxassetid://123",  или  AvatarUserId = 1,                           -- аватарка автора (по желанию)
		Description = "A simple tree.", Tags = { "nature" },
		Info = { { Label = "Polygons", Value = "1.2k", Icon = "▤" } },                  -- свои строки в Info
		Build = function(model) ... end,   или  Model = instance,  или  Image = "rbxassetid://..",
		Yaw = 0, Tilt = CFrame.Angles(0, 0, 0), Preview = true,
		Callback = function(asset) end,                                                 -- при выборе
		Actions = { { Name = "Equip", Icon = "✓", Callback = function(asset) end } },   -- меню "три точки"
	})
	Tree:Action({ Name, Icon, Callback })   -- ещё одно действие (максимум 5 на ассет)
	Models:Assets({ {...}, {...} })   Tree:Select()   Tree:Update({...})   Tree:Remove()
	Models:Clear()  Models:Open()  Models:Remove()

	-- свои страницы панели (иконка в верхней строке панели)
	Preview:Page({ Name = "Stats", Icon = "▤", Visible = function(asset) return true end,
		Build = function(parent, asset, pv) ... return function() end end })   -- вернуть функцию очистки (необязательно)

	-- контролы для страницы Actions. Вешаются на Preview (всегда), Tab (на вкладке) или Asset (только на нём)
	X:Button({ Name, Icon, Callback })              X:Toggle({ Name, Default, Flag, Callback(v) })
	X:Dropdown({ Name, Options, MultiSelect, MaxSelect, Default, Flag, Callback(v) })
	X:ColorPicker({ Name, Default, Flag, Callback(color) })
	X:Slider({ Name, Min, Max, Step, Default, Suffix, Flag, Callback(v) })
	X:Input({ Name, Placeholder, Default, Flag, Callback(text) })
	X:Label({ Text })     X:Divider({ Label })
	Каждый контрол возвращает объект: :Get() :Set(v) :Remove()   Flag пишется в конфиг JustLib.
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
local QUINT, QUART = Enum.EasingStyle.Quint, Enum.EasingStyle.Quart
local OUT, INN = Enum.EasingDirection.Out, Enum.EasingDirection.In

local MAIN_W, DESIGN_H, DRAWER_W, GAP = 931, 833, 352, 12
local TOTAL_W = MAIN_W + GAP + DRAWER_W
local MAX_ACTIONS = 5

local B, C, ACCENTS -- заполняются в M.new (берутся у JustLib, темы меняются «на месте»)

local M = {}
M.__index = M
M.Version = "2.0"

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
	if not o or not o.Parent then
		return
	end
	TS:Create(o, TweenInfo.new(t or 0.15, style or QUART, dir or OUT), p):Play()
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
end

-- Перетаскивание внутри ScrollingFrame: пока тянешь ползунок / колорпикер, окно не прокручивается
local function dragLocked(inst, onMove, onEnd)
	local frames = {}
	local sf = inst:FindFirstAncestorWhichIsA("ScrollingFrame")
	while sf do
		frames[#frames + 1] = sf
		sf.ScrollingEnabled = false
		sf = sf.Parent and sf.Parent:FindFirstAncestorWhichIsA("ScrollingFrame") or nil
	end
	beginDrag(onMove, function()
		for _, f in ipairs(frames) do
			f.ScrollingEnabled = true
		end
		if onEnd then
			onEnd()
		end
	end)
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

local function setIconColor(ic, col)
	if ic:IsA("TextLabel") then
		tw(ic, { TextColor3 = col }, 0.18)
	else
		tw(ic, { ImageColor3 = col }, 0.18)
	end
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
		tw(track, { BackgroundColor3 = v and C.togOn or C.togOff }, 0.16)
		tw(knob, { Position = v and U2(1, -19, 0.5, -8) or U2(0, 3, 0.5, -8) }, 0.2, QUINT)
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
			dragLocked(hit, from)
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

-- ViewportFrame с орбитальной камерой. Модель не двигается (только камера), поэтому вращение плавное.
-- Модель вписывается с запасом, поэтому края не обрезаются.
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
	local center = cf.Position
	if src.Tilt then
		model:PivotTo(CF(center) * src.Tilt)
	end

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
	local dir = V3(0.45, 0.4, -1).Unit
	local light = V3(-0.4, -1, 0.8)
	local startYaw = -(src.Yaw or 0)
	local h = { yaw = startYaw, tYaw = startYaw, zoom = 1, tZoom = 1, vel = 0 }

	local function place()
		local rot = ANG(0, h.yaw, 0)
		cam.CFrame = CFrame.lookAt(center + rot:VectorToWorldSpace(dir) * base * h.zoom, center)
		vp.LightDirection = rot:VectorToWorldSpace(light)
	end
	-- dt-независимое сглаживание: движение не «ступенчатое» ни на каком FPS
	function h.step(dt, auto, speed)
		dt = math.min(dt, 0.1)
		if math.abs(h.vel) > 0.01 then
			h.tYaw = h.tYaw + h.vel * dt
			h.vel = h.vel * math.exp(-dt * 2.8)
		else
			h.vel = 0
		end
		if auto then
			h.tYaw = h.tYaw + speed * dt
		end
		local a = 1 - math.exp(-dt * 13)
		h.yaw = h.yaw + (h.tYaw - h.yaw) * a
		h.zoom = h.zoom + (h.tZoom - h.zoom) * a
		place()
	end
	function h.drag(rad)
		h.tYaw = h.tYaw + rad
	end
	function h.zoomBy(f)
		h.tZoom = math.clamp(h.tZoom * f, 0.45, 2.4)
	end
	function h.reset()
		local two = math.pi * 2
		h.yaw = h.yaw % two
		h.tYaw = startYaw % two
		if h.yaw - h.tYaw > math.pi then
			h.tYaw = h.tYaw + two
		end
		h.tZoom = 1
		h.vel = 0
	end
	place()
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

local function hasPreview(a)
	return a.Preview ~= false and (a.Model ~= nil or a.Build ~= nil or a.Image ~= nil)
end

--------------------------------------------------------------------
-- контролы (страница Actions)
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
			tw(b, { BackgroundColor3 = C.btnHov }, 0.12)
		end
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = C.btnBg }, 0.12)
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
		tw(b, { BackgroundColor3 = ACCENTS[1] }, 0.07)
		task.delay(0.15, function()
			tw(b, { BackgroundColor3 = C.btnBg }, 0.2)
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
		tw(row, { Size = U2(1, 0, 0, open and (HEAD + 6 + lh) or HEAD) }, 0.28, QUINT)
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
	-- dragLocked: пока тянешь цвет, окно справа не прокручивается вверх-вниз
	svHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			svFrom(i)
			dragLocked(svHit, svFrom)
		end
	end)
	hueHit.InputBegan:Connect(function(i)
		if isPtr(i) then
			hueFrom(i)
			dragLocked(hueHit, hueFrom)
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
		tw(row, { Size = U2(1, 0, 0, on and (HEAD + 6 + PH) or HEAD) }, 0.28, QUINT)
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
-- страницы панели (drawer)
--------------------------------------------------------------------
local PAGES = {}

local function infoRow(parent, order, icon, label, value)
	local row = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 32), LayoutOrder = order }, parent)
	local ic = mkIcon(row, icon, 18, C.dim)
	ic.Position = UDim2.fromOffset(2, 7)
	txt("TextLabel", {
		Text = tostring(label), TextSize = 15, TextColor3 = C.dim, Position = UDim2.fromOffset(32, 0), Size = UDim2.fromOffset(96, 32),
	}, row)
	txt("TextLabel", {
		Text = tostring(value), TextSize = 15, TextColor3 = C.txt, TextXAlignment = Enum.TextXAlignment.Right,
		Position = U2(0, 126, 0, 0), Size = U2(1, -126, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
end

-- Actions: все контролы ассета, его вкладки и самого Preview
PAGES.actions = {
	id = "actions", name = "Actions", icon = "☰",
	build = function(parent, asset, pv)
		local sf = new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
		}, parent)
		table.insert(pv._scrollers, sf)
		pad(sf, 16, 16, 14, 16)
		local holder = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, sf)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, holder)
		local list = pv:_controlsFor(asset)
		for i, def in ipairs(list) do
			local b = CtrlBuilders[def.kind]
			if b then
				local ok, err = pcall(b, def, holder, i)
				if not ok then
					warn("[PreviewUI] control '" .. tostring(def.name) .. "' failed: " .. tostring(err))
				end
			end
		end
		return function()
			for _, def in ipairs(list) do
				def._refresh = nil
				def._lbl = nil
			end
		end
	end,
}

-- Info: название, автор, аватарка, даты и любые свои строки
PAGES.info = {
	id = "info", name = "Info", icon = "ℹ",
	build = function(parent, a, pv)
		local sf = new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
		}, parent)
		table.insert(pv._scrollers, sf)
		pad(sf, 16, 16, 14, 18)
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, sf)

		local avatar = a.Avatar
		if not avatar and a.AvatarUserId then
			avatar = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(a.AvatarUserId) .. "&w=150&h=150"
		end
		local top = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 84), LayoutOrder = 1 }, sf)
		local tx = 0
		if avatar then
			local av = new("ImageLabel", {
				BackgroundColor3 = C.badge, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(0, 6),
				Image = normImage(avatar), ScaleType = Enum.ScaleType.Crop,
			}, top)
			corner(av, 36)
			stroke(av, ACCENTS[1], 2)
			av:SetAttribute("JLNoRepaint", true)
			tx = 86
		end
		txt("TextLabel", {
			Text = tostring(a.Name), Font = GB, TextSize = 21, Position = UDim2.fromOffset(tx, 12), Size = U2(1, -tx, 0, 28),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, top)
		local sub = tostring(a.Type or "")
		if a.Creator then
			sub = (sub ~= "" and (sub .. "  ·  ") or "") .. "by " .. tostring(a.Creator)
		end
		txt("TextLabel", {
			Text = sub, TextSize = 14, TextColor3 = C.dim, Position = UDim2.fromOffset(tx, 44), Size = U2(1, -tx, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, top)

		new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Size = U2(1, 0, 0, 1), LayoutOrder = 2 }, sf)

		local order = 3
		local function add(icon, label, value)
			if value ~= nil and value ~= "" then
				infoRow(sf, order, icon, label, value)
				order = order + 1
			end
		end
		add("☺", "Creator", a.Creator)
		add("▤", "Created", a.Created)
		add("⛶", "Size", a.Size)
		add("◈", "Version", a.Version)
		add("▦", "Category", a.Cat)
		for _, r in ipairs(a.Info or {}) do
			add(r.Icon or "•", r.Label or "", r.Value or "")
		end

		if a.Description and a.Description ~= "" then
			new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Size = U2(1, 0, 0, 1), LayoutOrder = order }, sf)
			order = order + 1
			txt("TextLabel", {
				Text = tostring(a.Description), TextSize = 15, TextColor3 = C.txt, TextWrapped = true, LineHeight = 1.35,
				TextYAlignment = Enum.TextYAlignment.Top, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order,
			}, sf)
			order = order + 1
		end

		if type(a.Tags) == "table" and #a.Tags > 0 then
			local wrap = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, sf)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, wrap)
			for i, t in ipairs(a.Tags) do
				local chip = txt("TextLabel", {
					Text = tostring(t), Font = GM, TextSize = 13, TextColor3 = ACCENTS[1], BackgroundTransparency = 0.85,
					BackgroundColor3 = ACCENTS[1], TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i,
				}, wrap)
				pad(chip, 10, 10, 0, 0)
				corner(chip, 12)
			end
		end
	end,
}

-- Preview: плавное 3D (камера крутится вокруг модели, инерция при перетаскивании, зум колесом/щипком)
PAGES.preview = {
	id = "preview", name = "Preview", icon = "⬡",
	build = function(parent, a, pv)
		local cleanups = {}
		local box = new("Frame", {
			BackgroundColor3 = C.badge, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 8), Size = U2(1, -32, 1, -76),
		}, parent)
		corner(box, 14)
		stroke(box, C.border, 1)
		local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, box)
		pad(inner, 14, 14, 14, 14)
		local h = makeThumb(inner, a)

		local autoBtn, resetBtn
		local function refreshAuto()
			if autoBtn and autoBtn.Parent then
				autoBtn.Text = "Auto Rotate: " .. (S("autorotate", true) and "On" or "Off")
			end
		end
		pv._previewRefresh = refreshAuto

		local bar = new("Frame", { BackgroundTransparency = 1, Position = U2(0, 16, 1, -58), Size = U2(1, -32, 0, 34) }, parent)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
		local function chip(text, w, order, cb)
			local b = txt("TextButton", {
				Text = text, Font = GB, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundTransparency = 0, BackgroundColor3 = C.btnBg, Size = UDim2.fromOffset(w, 34), LayoutOrder = order,
			}, bar)
			corner(b, 8)
			stroke(b, C.border, 1)
			b.MouseEnter:Connect(function()
				if not touchLast() then
					tw(b, { BackgroundColor3 = C.btnHov }, 0.12)
				end
			end)
			b.MouseLeave:Connect(function()
				tw(b, { BackgroundColor3 = C.btnBg }, 0.12)
			end)
			b.Activated:Connect(cb)
			return b
		end
		autoBtn = chip("", 160, 1, function()
			B.cfgSet("_pv_autorotate", not S("autorotate", true))
			pv:ApplySettings()
		end)
		refreshAuto()
		resetBtn = chip("Reset", 76, 2, function()
			if h then
				h.reset()
			end
		end)
		txt("TextLabel", {
			Text = "Drag to rotate  ·  scroll / pinch to zoom", TextSize = 13, TextColor3 = C.dim,
			TextXAlignment = Enum.TextXAlignment.Center, Position = U2(0, 16, 1, -22), Size = U2(1, -32, 0, 18),
		}, parent)

		if h then
			local st = { dragging = false, resumeAt = 0 }
			pv._viewers[h] = st
			cleanups[#cleanups + 1] = function()
				pv._viewers[h] = nil
			end
			local hit = txt("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 5 }, box)
			hit.InputBegan:Connect(function(i)
				if not isPtr(i) then
					return
				end
				st.dragging = true
				h.vel = 0
				local lastX, lastT = i.Position.X, os.clock()
				beginDrag(function(m)
					local now = os.clock()
					local dx = m.Position.X - lastX
					local dt = math.max(now - lastT, 1 / 240)
					local rad = dx * 0.011
					h.drag(rad)
					h.vel = math.clamp(h.vel * 0.5 + (rad / dt) * 0.5, -14, 14)
					lastX, lastT = m.Position.X, now
				end, function()
					st.dragging = false
					st.resumeAt = os.clock() + 1.2
					if os.clock() - lastT > 0.08 then
						h.vel = 0
					end
				end)
			end)
			hit.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseWheel then
					h.zoomBy(1 - i.Position.Z * 0.1)
				end
			end)
			local pinchBase = 1
			local pc = UIS.TouchPinch:Connect(function(_, scale, _, state)
				if state == Enum.UserInputState.Begin then
					pinchBase = h.tZoom
				elseif state == Enum.UserInputState.Change then
					h.tZoom = math.clamp(pinchBase / math.max(scale, 0.05), 0.45, 2.4)
				end
			end)
			cleanups[#cleanups + 1] = function()
				pc:Disconnect()
			end
		end
		return function()
			pv._previewRefresh = nil
			for _, fn in ipairs(cleanups) do
				fn()
			end
		end
	end,
}

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
	self._tabs, self._side, self._assets, self._pages = {}, {}, {}, {}
	self._cards = {}
	self._cons = {}
	self._closedCbs = {}
	self._scrollers, self._phs = {}, {}
	self._viewers = {}
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

-- своя страница панели: Preview:Page({ Name, Icon, Visible = function(asset), Build = function(parent, asset, pv) return cleanup end })
function M:Page(o)
	o = o or {}
	local p = {
		id = "custom" .. tostring(#self._pages + 1), name = o.Name or "Page", icon = o.Icon or "◆",
		build = o.Build, visible = o.Visible, custom = true,
	}
	self._pages[#self._pages + 1] = p
	if self._gui and self._selected then
		self:_refreshDrawer(false)
	end
	return p
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
		self:_assetsChanged()
		if not self._activeTab and self._tabs[1] then
			self:_activate(self._tabs[1])
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
	asset._actions = {}
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
	-- пункт меню "три точки" (до MAX_ACTIONS штук на ассет)
	function asset:Action(o2)
		o2 = o2 or {}
		if #self._actions >= MAX_ACTIONS then
			warn("[PreviewUI] '" .. tostring(self.Name) .. "': максимум " .. MAX_ACTIONS .. " действий")
			return nil
		end
		local act = { Name = o2.Name or "Action", Icon = o2.Icon, Callback = o2.Callback }
		self._actions[#self._actions + 1] = act
		function act:Remove()
			for i, x in ipairs(asset._actions) do
				if x == self then
					table.remove(asset._actions, i)
					break
				end
			end
		end
		return act
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
	for _, act in ipairs(asset.Actions or {}) do
		asset:Action(act)
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
	if not self._selected and self._drawerOpen then
		self:_setDrawer(false)
	end
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
	if self._selected == asset and self._drawerOpen then
		self:_refreshDrawer(false)
	end
end

function M:_ctrlChanged()
	if self._gui and self._selected and self._drawerOpen then
		self:_refreshDrawer(false)
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
-- открыть / закрыть окно
--------------------------------------------------------------------
function M:Open(target)
	if not self.alive or self._closing then
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
		tw(self._uiScale, { Scale = (self._scaleTarget or 1) * 0.92 }, 0.18, QUART, INN)
		task.delay(0.19, function()
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

function M:CloseDrawer()
	if self._gui and self._drawerOpen then
		self._selected = nil
		self:_markSelected()
		self:_setDrawer(false)
	end
	return self
end

-- полная очистка: GUI, соединения, блюр, ссылки на элементы
function M:_teardown()
	self:_closeMenu()
	self:_cleanupPage()
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
	self._gui, self._holder, self._root, self._main, self._drawer, self._uiScale, self._titleL = nil, nil, nil, nil, nil, nil, nil
	self._sidebar, self._grid, self._d = nil, nil, nil
	self._dTitle, self._dType, self._dTabs, self._dPages, self._pageRoot = nil, nil, nil, nil, nil
	self._cards, self._sideRefs, self._tabRefs, self._curPages = {}, {}, {}, {}
	self._scrollers, self._phs, self._viewers = {}, {}, {}
	self._activeTab, self._selected, self._drawerOpen, self._page = nil, nil, false, nil
	self._query, self._type = "", "All"
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
	self._tabs, self._side, self._assets, self._controls, self._pages = {}, {}, {}, {}, {}
	if B.onDestroyed then
		B.onDestroyed(self)
	end
end

--------------------------------------------------------------------
-- раскладка и настройки (страница "Preview UI" в Settings JustLib)
--------------------------------------------------------------------
function M:_cacheSettings()
	self._auto = S("autorotate", true) == true
	self._speed = math.rad(tonumber(S("rotspeed", 40)) or 40)
end

function M:_pairX(open)
	local RW, mw = self._RW, self._mainW
	if open then
		local mx = math.floor((RW - (mw + GAP + DRAWER_W)) / 2)
		return mx, mx + mw + GAP
	end
	local mx = math.floor((RW - mw) / 2)
	return mx, mx + mw - DRAWER_W
end

function M:_layout()
	if not self._root then
		return
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or V2(1280, 720)
	local us = (tonumber(S("scale", 100)) or 100) / 100
	local s = math.clamp(v.Y * 0.94 / DESIGN_H, 0.65, 1)
	s = math.min(s, v.X * 0.96 / 900)
	s = math.max(s * us, 0.3)
	local RW = math.min(TOTAL_W, v.X * 0.96 / s)
	local RH = math.min(DESIGN_H, v.Y * 0.94 / s)
	self._scaleTarget, self._RW, self._RH = s, RW, RH
	self._mainW = math.max(math.min(MAIN_W, RW - DRAWER_W - GAP), 560)
	if not self._animating and not self._closing then
		self._uiScale.Scale = s
	end
	self._root.Size = UDim2.fromOffset(RW, RH)
	self._main.Size = UDim2.fromOffset(self._mainW, RH)
	self._drawer.Size = UDim2.fromOffset(DRAWER_W, RH)
	if not self._sliding then
		local mx, dx = self:_pairX(self._drawerOpen == true)
		self._main.Position = UDim2.fromOffset(mx, 0)
		self._drawer.Position = UDim2.fromOffset(dx, 0)
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
		tw(self._blur, { Size = math.round(pct * 56 / 100) }, 0.35)
	elseif self._blur then
		pcall(function() self._blur:Destroy() end)
		self._blur = nil
	end
end

function M:ApplySettings()
	self:_cacheSettings()
	if not self._gui then
		return
	end
	self:_layout()
	self:_applyBlur()
	if self._previewRefresh then
		self._previewRefresh()
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
	self:_styleDrawerTabs(true)
	self:_markSelected(true)
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
	self._scrollers, self._phs, self._viewers = {}, {}, {}
	self._sideRefs, self._tabRefs, self._cards, self._curPages = {}, {}, {}, {}
	self._drawerOpen, self._selected, self._page = false, nil, nil
	self:_cacheSettings()

	-- holder двигается при перетаскивании (в пикселях), root масштабируется (UIScale)
	local holder = new("Frame", { Name = "Holder", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, gui)
	local root = new("Frame", {
		Name = "Root", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = V2(0.5, 0.5),
		Position = U2(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(TOTAL_W, DESIGN_H),
	}, holder)
	local uiScale = new("UIScale", {}, root)
	self._holder, self._root, self._uiScale = holder, root, uiScale

	local main = new("Frame", {
		Name = "Window", BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ZIndex = 2,
		Size = UDim2.fromOffset(MAIN_W, DESIGN_H),
	}, root)
	corner(main, 18)
	stroke(main, C.border, 1)
	self._main = main

	local drawer = new("Frame", {
		Name = "Drawer", BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ZIndex = 1, Visible = false,
		Size = UDim2.fromOffset(DRAWER_W, DESIGN_H),
	}, root)
	corner(drawer, 18)
	stroke(drawer, C.border, 1)
	self._drawer = drawer

	-- шапка -------------------------------------------------------
	local header = new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Size = U2(1, 0, 0, 76) }, main)
	corner(header, 18)
	new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Position = U2(0, 0, 1, -18), Size = U2(1, 0, 0, 18) }, header)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 76), Size = U2(1, 0, 0, 1) }, main)

	local hic = mkIcon(header, self.Icon, 34, C.dim)
	hic.Position = UDim2.fromOffset(28, 21)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(77, 19), Size = UDim2.fromOffset(1, 40) }, header)
	self._titleL = txt("TextLabel", {
		Text = self.Title, TextSize = 30, Font = GM, Position = UDim2.fromOffset(95, 0), Size = U2(1, -170, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)

	local dragArea = txt("TextButton", { Size = U2(1, -80, 1, 0) }, header)
	dragArea.InputBegan:Connect(function(i)
		if not isPtr(i) then
			return
		end
		local start = V2(i.Position.X, i.Position.Y)
		local sp = holder.Position
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or V2(1280, 720)
		beginDrag(function(m)
			local d = V2(m.Position.X, m.Position.Y) - start
			local ox = math.clamp(sp.X.Offset + d.X, -vs.X * 0.45, vs.X * 0.45)
			local oy = math.clamp(sp.Y.Offset + d.Y, -vs.Y * 0.45, vs.Y * 0.45)
			holder.Position = U2(sp.X.Scale, ox, sp.Y.Scale, oy)
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
				tw(l, { BackgroundColor3 = C.danger }, 0.12)
			end
		end
	end)
	closeBtn.MouseLeave:Connect(function()
		for _, l in ipairs(xLines) do
			tw(l, { BackgroundColor3 = C.dim }, 0.12)
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

	-- центр: «плавающая» панель с отступами (углы окна не торчат) ----
	local center = new("Frame", {
		Name = "Center", BackgroundColor3 = C.sidebar, BorderSizePixel = 0,
		Position = UDim2.fromOffset(278, 89), Size = U2(1, -288, 1, -99),
	}, main)
	corner(center, 14)
	stroke(center, C.border, 1)

	local searchBox = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14), Size = U2(1, -(14 + 14 + 151 + 12), 0, 45),
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
		AnchorPoint = V2(1, 0), Position = U2(1, -14, 0, 14), Size = UDim2.fromOffset(151, 45),
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
		AnchorPoint = V2(1, 0), Position = U2(1, -14, 0, 66), Size = UDim2.fromOffset(151, 46),
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
		Position = UDim2.fromOffset(4, 72), Size = U2(1, -8, 1, -76),
		CanvasSize = U2(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = ACCENTS[1], ScrollingDirection = Enum.ScrollingDirection.Y,
	}, center)
	table.insert(self._scrollers, grid)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(197, 210), CellPadding = UDim2.fromOffset(17, 17), SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	-- запас вокруг карточек: рамка и подъём карточки при наведении не обрезаются краями
	pad(grid, 6, 6, 6, 18)
	self._grid = grid

	local emptyL = txt("TextLabel", {
		Text = "Nothing found", TextSize = 18, TextColor3 = C.dim, Visible = false,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = V2(0.5, 0), Position = U2(0.5, 0, 0, 130), Size = UDim2.fromOffset(300, 30),
	}, center)
	self._d = { empty = emptyL, ddText = ddText, ddList = ddList }

	-- панель (drawer) ---------------------------------------------
	local dHead = new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Size = U2(1, 0, 0, 76) }, drawer)
	corner(dHead, 18)
	new("Frame", { BackgroundColor3 = C.pHdr, BorderSizePixel = 0, Position = U2(0, 0, 1, -18), Size = U2(1, 0, 0, 18) }, dHead)
	self._dTitle = txt("TextLabel", {
		Font = GB, TextSize = 21, Position = UDim2.fromOffset(20, 13), Size = U2(1, -76, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd,
	}, dHead)
	self._dType = txt("TextLabel", {
		TextSize = 14, TextColor3 = C.dim, Position = UDim2.fromOffset(20, 43), Size = U2(1, -76, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
	}, dHead)
	local collapse = txt("TextButton", {
		Text = "›", Font = GB, TextSize = 30, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = V2(1, 0.5), Position = U2(1, -10, 0, 38), Size = UDim2.fromOffset(40, 40),
	}, dHead)
	collapse.MouseEnter:Connect(function()
		if not touchLast() then
			tw(collapse, { TextColor3 = C.txt }, 0.12)
		end
	end)
	collapse.MouseLeave:Connect(function()
		tw(collapse, { TextColor3 = C.dim }, 0.12)
	end)
	collapse.Activated:Connect(function()
		self:CloseDrawer()
	end)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 76), Size = U2(1, 0, 0, 1) }, drawer)

	self._dTabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 84), Size = U2(1, -24, 0, 54) }, drawer)
	new("Frame", { BackgroundColor3 = C.divLine, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 142), Size = U2(1, 0, 0, 1) }, drawer)
	self._dPages = new("Frame", {
		BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, 144), Size = U2(1, 0, 1, -146),
	}, drawer)

	-- события -----------------------------------------------------
	local cam = workspace.CurrentCamera
	if cam then
		self._cons[#self._cons + 1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_layout()
		end)
	end
	-- один общий цикл для всех 3D-превью: плавно на любом FPS
	self._cons[#self._cons + 1] = RunService.RenderStepped:Connect(function(dt)
		for h, st in pairs(self._viewers) do
			h.step(dt, self._auto and not st.dragging and os.clock() > st.resumeAt, self._speed)
		end
	end)

	-- первичная отрисовка ----------------------------------------
	self:_renderSidebar()
	self:_syncCards()
	self:_layout()
	local startTab = self._tabs[1]
	if S("remember", true) then
		local last = S("last", "")
		if type(last) == "string" then
			local tn = last:match("^[^|]*")
			if tn and self:GetTab(tn) then
				startTab = self:GetTab(tn)
			end
		end
		local pg = S("page", "")
		if type(pg) == "string" and pg ~= "" then
			self._page = pg
		end
	end
	self._restoring = true
	self:_activate(startTab)
	self._restoring = false
	self:_applyBlur()

	if S("anim", true) then
		self._animating = true
		uiScale.Scale = (self._scaleTarget or 1) * 0.92
		tw(uiScale, { Scale = self._scaleTarget or 1 }, 0.35, QUINT)
		task.delay(0.37, function()
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
	if #self._side == 0 then
		txt("TextLabel", {
			Text = "No tabs yet", TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Size = U2(1, -32, 0, 40), LayoutOrder = 1,
		}, side)
		return
	end
	local ord = 0
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
			b.MouseEnter:Connect(function()
				if not touchLast() and tab ~= self._activeTab then
					tw(lb, { TextColor3 = C.txt }, 0.12)
				end
			end)
			b.MouseLeave:Connect(function()
				if tab ~= self._activeTab then
					tw(lb, { TextColor3 = C.dim }, 0.12)
				end
			end)
			b.Activated:Connect(function()
				if tab ~= self._activeTab then
					self:_activate(tab)
				end
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
			tw(r.btn, { BackgroundTransparency = on and 0.85 or 1 }, 0.22)
			tw(r.lbl, { TextColor3 = on and C.txt or C.dim }, 0.18)
			setIconColor(r.icon, on and ACCENTS[1] or C.dim)
		end
	end
end

function M:_activate(tab)
	if not self._gui then
		return
	end
	if self._drawerOpen then
		self:CloseDrawer()
	end
	self._activeTab = tab
	self._type = "All"
	if tab and not self._restoring and S("remember", true) then
		B.cfgSet("_pv_last", tab.Name)
	end
	self:_styleSidebar()
	self:_applyFilter()
	self:_popGrid()
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
	local card = new("Frame", {
		Name = asset.Name, LayoutOrder = asset._order, BackgroundColor3 = C.badge, BorderSizePixel = 0, Visible = false,
	}, self._grid)
	corner(card, 10)
	local st = stroke(card, C.border, 1)
	local sc = new("UIScale", {}, card)
	local thumb = new("Frame", { BackgroundTransparency = 1, Size = U2(1, 0, 0, 146) }, card)
	-- внутренний отступ: модель никогда не упирается в рамку
	pad(thumb, 10, 10, 10, 6)
	local label = new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 146), Size = U2(1, 0, 1, -146) }, card)
	corner(label, 10)
	new("Frame", { BackgroundColor3 = C.btnBg, BorderSizePixel = 0, Size = U2(1, 0, 0, 14) }, label)
	txt("TextLabel", {
		Text = asset.Name, Font = GM, TextSize = 17, Position = UDim2.fromOffset(14, 8), Size = U2(1, -58, 0, 22),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)
	txt("TextLabel", {
		Text = tostring(asset.Type or asset.Creator or ""), TextSize = 14, TextColor3 = C.dim,
		Position = UDim2.fromOffset(14, 33), Size = U2(1, -24, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
	}, label)

	-- три точки: меню действий
	local dots = txt("TextButton", {
		BackgroundTransparency = 1, BackgroundColor3 = C.badge, AnchorPoint = V2(1, 0),
		Position = U2(1, -8, 0, 152), Size = UDim2.fromOffset(34, 26), ZIndex = 6,
	}, card)
	corner(dots, 7)
	for i = 0, 2 do
		local d = new("Frame", {
			BackgroundColor3 = C.dim, BorderSizePixel = 0, Size = UDim2.fromOffset(4, 4),
			Position = UDim2.fromOffset(7 + i * 8, 11), ZIndex = 7,
		}, dots)
		corner(d, 2)
	end
	dots.MouseEnter:Connect(function()
		if not touchLast() then
			tw(dots, { BackgroundTransparency = 0 }, 0.12)
		end
	end)
	dots.MouseLeave:Connect(function()
		tw(dots, { BackgroundTransparency = 1 }, 0.12)
	end)
	dots.Activated:Connect(function()
		self:_openMenu(asset, dots)
	end)

	local btn = txt("TextButton", { Size = U2(1, 0, 1, 0), ZIndex = 5 }, card)
	btn.MouseEnter:Connect(function()
		if not touchLast() and not card:GetAttribute("pop") then
			tw(sc, { Scale = 1.025 }, 0.22, QUINT)
			if asset ~= self._selected then
				tw(st, { Color = C.dim }, 0.18)
			end
		end
	end)
	btn.MouseLeave:Connect(function()
		tw(sc, { Scale = 1 }, 0.25, QUINT)
		if asset ~= self._selected then
			tw(st, { Color = C.border }, 0.18)
		end
	end)
	btn.Activated:Connect(function()
		self:_onCardClick(asset)
	end)
	return { frame = card, stroke = st, thumb = thumb, scale = sc, built = false }
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

-- плавное появление карточек при смене вкладки
function M:_popGrid()
	if not self._grid or not S("anim", true) then
		return
	end
	local n = 0
	for _, a in ipairs(self._assets) do
		local c = self._cards[a]
		if c and c.frame.Visible then
			n = n + 1
			local sc, frame = c.scale, c.frame
			sc.Scale = 0.9
			frame:SetAttribute("pop", true)
			task.delay(math.min(n * 0.025, 0.3), function()
				if sc.Parent then
					tw(sc, { Scale = 1 }, 0.4, QUINT)
				end
			end)
			task.delay(math.min(n * 0.025, 0.3) + 0.4, function()
				if frame.Parent then
					frame:SetAttribute("pop", nil)
				end
			end)
		end
	end
	self._grid.CanvasPosition = V2(0, 0)
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
			self:_popGrid()
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
	local shown = 0
	for _, a in ipairs(self._assets) do
		local c = self._cards[a]
		if c then
			local ok = tab ~= nil and self:_inScope(tab, a) and (self._type == "All" or a.Type == self._type) and matchQuery(a, q)
			c.frame.Visible = ok
			if ok then
				shown = shown + 1
				self:_ensureThumb(a, c)
			end
		end
	end
	self._d.empty.Visible = (shown == 0)
	self:_buildTypeList()
	self:_markSelected(true)
end

function M:_markSelected(instant)
	for asset, c in pairs(self._cards) do
		local on = (asset == self._selected)
		local props = { Color = on and ACCENTS[1] or C.border, Thickness = on and 2 or 1 }
		if instant then
			c.stroke.Color, c.stroke.Thickness = props.Color, props.Thickness
		else
			tw(c.stroke, props, 0.22)
		end
	end
end

-- первый клик: выезжает панель, второй клик по тому же ассету: задвигается
function M:_onCardClick(asset)
	if self._drawerOpen and self._selected == asset then
		self:CloseDrawer()
	else
		self:_select(asset)
		self:_setDrawer(true)
	end
end

function M:_select(asset)
	self._selected = asset
	self:_markSelected()
	if asset then
		self:_refreshDrawer(self._drawerOpen)
		safe(asset.Callback, asset)
	end
end

function M:_goto(target)
	if not self._gui then
		return
	end
	local tab, asset, page
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
			page = target.Page
		end
	end
	if tab and tab ~= self._activeTab then
		self:_activate(tab)
	end
	if asset then
		if page then
			self._page = page
		end
		self:_select(asset)
		self:_setDrawer(true)
	end
end

--------------------------------------------------------------------
-- меню "три точки"
--------------------------------------------------------------------
function M:_closeMenu()
	if self._menuBack then
		pcall(function() self._menuBack:Destroy() end)
	end
	self._menu, self._menuBack = nil, nil
end

function M:_openMenu(asset, anchor)
	if not self._root then
		return
	end
	self:_closeMenu()
	local items = {}
	for _, a in ipairs(asset._actions) do
		items[#items + 1] = { name = a.Name, icon = a.Icon, fn = function() safe(a.Callback, asset, a) end }
	end
	if #items == 0 then
		local function openPage(id)
			return function()
				self._page = id
				self:_select(asset)
				self:_setDrawer(true)
			end
		end
		items[#items + 1] = { name = "Info", icon = "ℹ", fn = openPage("info") }
		if hasPreview(asset) then
			items[#items + 1] = { name = "Preview", icon = "⬡", fn = openPage("preview") }
		end
	end

	local back = txt("TextButton", { Size = UDim2.fromScale(1, 1), ZIndex = 39 }, self._root)
	self._menuBack = back
	back.Activated:Connect(function()
		self:_closeMenu()
	end)
	local W, ITEM = 190, 38
	local H = #items * ITEM + 8
	local panel = new("Frame", {
		BackgroundColor3 = C.input, BorderSizePixel = 0, ZIndex = 40, Active = true, Size = UDim2.fromOffset(W, H),
	}, back)
	corner(panel, 10)
	stroke(panel, C.border, 1)
	pad(panel, 4, 4, 4, 4)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	local s = math.max(self._uiScale.Scale, 0.01)
	local rp, bp, bs = self._root.AbsolutePosition, anchor.AbsolutePosition, anchor.AbsoluteSize
	local x = (bp.X - rp.X) / s + bs.X / s - W
	local y = (bp.Y - rp.Y) / s + bs.Y / s + 4
	x = math.clamp(x, 8, math.max(8, self._RW - W - 8))
	if y + H > self._RH - 8 then
		y = (bp.Y - rp.Y) / s - H - 4
	end
	panel.Position = UDim2.fromOffset(x, math.max(8, y))
	local ps = new("UIScale", { Scale = 0.88 }, panel)
	tw(ps, { Scale = 1 }, 0.22, QUINT)
	for i, it in ipairs(items) do
		local b = txt("TextButton", {
			BackgroundTransparency = 1, BackgroundColor3 = ACCENTS[1], Size = U2(1, 0, 0, ITEM), LayoutOrder = i, ZIndex = 41,
		}, panel)
		corner(b, 7)
		local tx = 12
		if it.icon then
			local ic = mkIcon(b, it.icon, 18, ACCENTS[1])
			ic.Position = U2(0, 10, 0.5, -9)
			ic.ZIndex = 42
			tx = 38
		end
		txt("TextLabel", {
			Text = tostring(it.name), Font = GM, TextSize = 16, Position = UDim2.fromOffset(tx, 0), Size = U2(1, -tx - 6, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 42,
		}, b)
		b.MouseEnter:Connect(function()
			if not touchLast() then
				tw(b, { BackgroundTransparency = 0.85 }, 0.1)
			end
		end)
		b.MouseLeave:Connect(function()
			tw(b, { BackgroundTransparency = 1 }, 0.1)
		end)
		b.Activated:Connect(function()
			self:_closeMenu()
			it.fn()
		end)
	end
	self._menu = panel
end

--------------------------------------------------------------------
-- панель (drawer)
--------------------------------------------------------------------
function M:_setDrawer(open)
	if not self._drawer then
		return
	end
	open = open == true
	if open == (self._drawerOpen == true) then
		return
	end
	self._drawerOpen = open
	local mx, dx = self:_pairX(open)
	local main, drawer = self._main, self._drawer
	if open then
		drawer.Visible = true
	end
	self._slideTok = (self._slideTok or 0) + 1
	local tok = self._slideTok
	if not S("anim", true) then
		main.Position, drawer.Position = UDim2.fromOffset(mx, 0), UDim2.fromOffset(dx, 0)
		if not open then
			drawer.Visible = false
			self:_cleanupPage()
		end
		return
	end
	self._sliding = true
	local info = TweenInfo.new(open and 0.5 or 0.42, QUINT, OUT)
	TS:Create(main, info, { Position = UDim2.fromOffset(mx, 0) }):Play()
	TS:Create(drawer, info, { Position = UDim2.fromOffset(dx, 0) }):Play()
	task.delay(open and 0.52 or 0.44, function()
		if self._slideTok ~= tok or not self._drawer then
			return
		end
		self._sliding = false
		if not open then
			self._drawer.Visible = false
			self:_cleanupPage()
		end
	end)
end

function M:_controlsFor(asset)
	local list, seen = {}, {}
	local function addFrom(container)
		if container and not seen[container] then
			seen[container] = true
			for _, d in ipairs(container._controls or {}) do
				list[#list + 1] = d
			end
		end
	end
	if asset then
		addFrom(asset)
		addFrom(asset.tab)
	end
	addFrom(self._activeTab)
	addFrom(self)
	return list
end

function M:_pagesFor(asset)
	local out = {}
	if #self:_controlsFor(asset) > 0 then
		out[#out + 1] = PAGES.actions
	end
	out[#out + 1] = PAGES.info
	if hasPreview(asset) then
		out[#out + 1] = PAGES.preview
	end
	for _, p in ipairs(self._pages) do
		local show = true
		if p.visible then
			local ok, r = pcall(p.visible, asset)
			show = ok and r ~= false
		end
		if show and p.build then
			out[#out + 1] = p
		end
	end
	return out
end

function M:_cleanupPage()
	if self._pageCleanup then
		pcall(self._pageCleanup)
		self._pageCleanup = nil
	end
	if self._pageRoot then
		pcall(function() self._pageRoot:Destroy() end)
		self._pageRoot = nil
	end
end

function M:_renderDrawerTabs()
	local bar = self._dTabs
	if not bar then
		return
	end
	for _, ch in ipairs(bar:GetChildren()) do
		ch:Destroy()
	end
	self._tabRefs = {}
	local pages = self._curPages
	local n = #pages
	for i, p in ipairs(pages) do
		local b = txt("TextButton", {
			BackgroundTransparency = 1, Size = U2(1 / n, -4, 1, -6), Position = U2((i - 1) / n, 2, 0, 0),
		}, bar)
		corner(b, 10)
		local ic = mkIcon(b, p.icon, 20, C.dim)
		ic.AnchorPoint = V2(0.5, 0)
		ic.Position = U2(0.5, 0, 0, 6)
		local lb = txt("TextLabel", {
			Text = p.name, Font = GM, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
			Position = U2(0, 0, 0, 29), Size = U2(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
		}, b)
		b.MouseEnter:Connect(function()
			if not touchLast() and p.id ~= self._page then
				tw(b, { BackgroundTransparency = 0.9 }, 0.12)
			end
		end)
		b.MouseLeave:Connect(function()
			tw(b, { BackgroundTransparency = 1 }, 0.12)
		end)
		b.Activated:Connect(function()
			if p.id ~= self._page then
				self:_showPage(p.id, true)
			end
		end)
		self._tabRefs[p.id] = { btn = b, icon = ic, lbl = lb, idx = i }
	end
	local ind = new("Frame", {
		Name = "Indicator", BackgroundColor3 = ACCENTS[1], BorderSizePixel = 0, AnchorPoint = V2(0.5, 1),
		Position = U2(0.5, 0, 1, 0), Size = UDim2.fromOffset(30, 3),
	}, bar)
	corner(ind, 2)
	self._indicator = ind
	self._indN = n
end

function M:_styleDrawerTabs(instant)
	for id, r in pairs(self._tabRefs or {}) do
		if r.btn and r.btn.Parent then
			local on = (id == self._page)
			local col = on and ACCENTS[1] or C.dim
			if instant then
				r.lbl.TextColor3 = on and C.txt or C.dim
				if r.icon:IsA("TextLabel") then
					r.icon.TextColor3 = col
				else
					r.icon.ImageColor3 = col
				end
			else
				tw(r.lbl, { TextColor3 = on and C.txt or C.dim }, 0.18)
				setIconColor(r.icon, col)
			end
			if on and self._indicator and self._indicator.Parent then
				local pos = U2((r.idx - 0.5) / math.max(self._indN, 1), 0, 1, 0)
				if instant then
					self._indicator.Position = pos
				else
					tw(self._indicator, { Position = pos }, 0.4, QUINT)
				end
			end
		end
	end
end

function M:_showPage(id, animate)
	local a = self._selected
	if not a or not self._dPages then
		return
	end
	local page
	for _, p in ipairs(self._curPages) do
		if p.id == id then
			page = p
		end
	end
	if not page then
		page = self._curPages[1]
	end
	if not page then
		return
	end
	local changed = (self._page ~= page.id)
	self._page = page.id
	self:_cleanupPage()
	local pr = new("Frame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Position = U2(0, 0, 0, animate and 16 or 0),
	}, self._dPages)
	self._pageRoot = pr
	local ok, cleanup = pcall(page.build, pr, a, self)
	if ok then
		if type(cleanup) == "function" then
			self._pageCleanup = cleanup
		end
	else
		warn("[PreviewUI] page '" .. tostring(page.name) .. "' failed: " .. tostring(cleanup))
	end
	if animate then
		tw(pr, { Position = U2(0, 0, 0, 0) }, 0.45, QUINT)
	end
	self:_styleDrawerTabs(not changed and not animate)
	if changed and S("remember", true) then
		B.cfgSet("_pv_page", page.id)
	end
end

function M:_refreshDrawer(animate)
	if not self._drawer then
		return
	end
	local a = self._selected
	if not a then
		return
	end
	self._dTitle.Text = tostring(a.Name)
	local sub = tostring(a.Type or "")
	if a.Creator then
		sub = (sub ~= "" and (sub .. "  ·  ") or "") .. tostring(a.Creator)
	end
	self._dType.Text = sub
	self._curPages = self:_pagesFor(a)
	self:_renderDrawerTabs()
	self:_showPage(self._page, animate)
end

return M
