--[[
	Just X Library — Preview UI (Asset Browser + Preview)
	Модуль для JustLib: подключается через JL:Preview({...}) вместо старого PreviewUI.lua.

	* Asset Browser : боковая панель, поиск, фильтры, сетка / список, страницы
	* Preview       : окно с вкладками Controllers / Info / Preview (открывается по клику на карточку)
	* Viewer        : плавная камера, вращение, перемещение, масштаб, щипок, автоповорот, полный экран

	Использование:
		local Preview = JL:Preview({
			Assets   = { ... },            -- необязательно: свой список ассетов (формат как в ASSETS ниже)
			Icons    = { close = "rbxassetid://..." },   -- необязательно: иконки вместо символов
			Config   = { PageSize = 9, Blur = 14 },      -- необязательно: переопределение CFG
			AutoOpen = true,               -- открыть окно сразу (по умолчанию окно открывается через Preview:Open())
		})
		Preview:Open()                     -- браузер
		Preview:Open("Info")               -- вкладка Info для выбранного (или первого) ассета
		Preview:Open("Oak Tree")           -- сразу Preview этого ассета (имя или Id)
		Preview:Close()

	Методы объекта: Open(target), Close(), Toggle(), IsOpen(), OnClosed(fn), GetTabs(), ApplySettings(), Destroy()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Строит всё окно и возвращает управляющий handle. Вызывается при каждом открытии, закрытие уничтожает окно целиком.
local function Run(bridge, popts, hooks)
	--==================================================================--
	--  CONFIG
	--==================================================================--
	local CFG = {
		PageSize = 9,
		AutoRotate = true,
		Blur = 14, -- blur behind Preview window (0 = off)
		LogoImage = "rbxassetid://139597074554691", -- X icon
		LogoZoom = 1.5, -- transparent margins fix
		BrowseUrl = "https://create.roblox.com/store/models",
	}
	for k, v in pairs(popts.Config or {}) do CFG[k] = v end

	-- Optional: put "rbxassetid://..." here to replace text glyphs with real icons
	local ICONS = {
		cube = "", models = "", parts = "", meshes = "", decals = "", images = "",
		sounds = "", plugins = "", others = "", all = "", gamepad = "", info = "",
		eye = "", rotate = "", pan = "", zoom = "", expand = "", star = "", close = "",
	}

	for k, v in pairs(popts.Icons or {}) do ICONS[k] = v end

	local GLYPH = {
		cube = "◈", models = "◈", parts = "◇", meshes = "⬡", decals = "▣", images = "▤",
		sounds = "♪", plugins = "✚", others = "•••", all = "▦", gamepad = "◉", info = "i",
		eye = "◉", rotate = "⟳", pan = "✥", zoom = "⌕", expand = "⛶", star = "★", close = "✕",
	}

	--==================================================================--
	--  THEME
	--==================================================================--
	local T = {
		bg = Color3.fromRGB(20, 19, 36),
		side = Color3.fromRGB(16, 15, 29),
		card = Color3.fromRGB(30, 29, 52),
		cardHover = Color3.fromRGB(38, 36, 68),
		field = Color3.fromRGB(29, 28, 50),
		stroke = Color3.fromRGB(52, 49, 92),
		track = Color3.fromRGB(46, 44, 76),
		popup = Color3.fromRGB(26, 25, 45),
		accent = Color3.fromRGB(124, 92, 255),
		accent2 = Color3.fromRGB(150, 124, 255),
		text = Color3.fromRGB(240, 240, 252),
		sub = Color3.fromRGB(150, 148, 186),
		star = Color3.fromRGB(255, 208, 92),
	}

	--==================================================================--
	--  DATA  (demo assets – replace with yours)
	--==================================================================--
	local function AutoRot()
		if bridge and bridge.cfgGet then return bridge.cfgGet("_pv_autorotate", CFG.AutoRotate) ~= false end
		return CFG.AutoRotate
	end
	local function RotSpeed() -- рад/с (в настройках хаба задаётся в °/с)
		if bridge and bridge.cfgGet then return math.rad(tonumber(bridge.cfgGet("_pv_rotspeed", 20)) or 20) end
		return 0.35
	end
	local conns = {} -- глобальные подключения окна, отключаются при закрытии

	local function RGB(r, g, b) return Color3.fromRGB(r, g, b) end

	local ASSETS = {
		{ Name = "Oak Tree", Kind = "oak", Type = "Model", Cat = "Models", Pop = 100, Created = "12.06.2023", Creator = "Roblox", Id = 123456789, UseReal = false,
			Variants = { { Name = "Oak Tree" }, { Name = "Autumn Oak", Tint = RGB(204, 118, 38) }, { Name = "Spring Oak", Tint = RGB(124, 196, 84) } } },
		{ Name = "Pine Tree", Kind = "pine", Type = "Model", Cat = "Models", Pop = 95, Created = "03.07.2023", Creator = "Roblox", Id = 123456790, Variants = { { Name = "Pine Tree" }, { Name = "Frost Pine", Tint = RGB(150, 200, 210) } } },
		{ Name = "Birch Tree", Kind = "birch", Type = "Model", Cat = "Models", Pop = 90, Created = "21.08.2023", Creator = "Roblox", Id = 123456791, Variants = { { Name = "Birch Tree" } } },
		{ Name = "Bush", Kind = "bush", Type = "Model", Cat = "Models", Pop = 80, Created = "02.09.2023", Creator = "Roblox", Id = 123456792, Variants = { { Name = "Bush" }, { Name = "Dry Bush", Tint = RGB(160, 140, 70) } } },
		{ Name = "Rock", Kind = "rock", Type = "Mesh", Cat = "Meshes", Pop = 78, Created = "14.09.2023", Creator = "Roblox", Id = 123456793, Variants = { { Name = "Rock" } } },
		{ Name = "Wooden Crate", Kind = "crate", Type = "Model", Cat = "Models", Pop = 85, Created = "30.09.2023", Creator = "Roblox", Id = 123456794, Variants = { { Name = "Wooden Crate" } } },
		{ Name = "Barrel", Kind = "barrel", Type = "Model", Cat = "Models", Pop = 70, Created = "11.10.2023", Creator = "Roblox", Id = 123456795, Variants = { { Name = "Barrel" } } },
		{ Name = "Lantern", Kind = "lantern", Type = "Model", Cat = "Models", Pop = 75, Created = "19.10.2023", Creator = "Roblox", Id = 123456796, Variants = { { Name = "Lantern" } } },
		{ Name = "Campfire", Kind = "campfire", Type = "Model", Cat = "Models", Pop = 88, Created = "05.11.2023", Creator = "Roblox", Id = 123456797, Variants = { { Name = "Campfire" } } },
		{ Name = "Fence", Kind = "fence", Type = "Model", Cat = "Parts", Pop = 60, Created = "17.11.2023", Creator = "Roblox", Id = 123456798, Variants = { { Name = "Fence" } } },
		{ Name = "Stone Block", Kind = "crate", Type = "Part", Cat = "Parts", Pop = 55, Created = "01.12.2023", Creator = "Roblox", Id = 123456799, Variants = { { Name = "Stone Block", Tint = RGB(130, 130, 140) } } },
		{ Name = "Small Rock", Kind = "rock", Type = "Mesh", Cat = "Meshes", Pop = 50, Created = "09.12.2023", Creator = "Roblox", Id = 123456800, Variants = { { Name = "Small Rock" } } },
	}

	if type(popts.Assets) == "table" and #popts.Assets > 0 then ASSETS = popts.Assets end

	local CATS = { "All Assets", "Models", "Parts", "Meshes", "Decals", "Images", "Sounds", "Plugins", "Others" }
	local CAT_ICON = { ["All Assets"] = "all", Models = "models", Parts = "parts", Meshes = "meshes", Decals = "decals", Images = "images", Sounds = "sounds", Plugins = "plugins", Others = "others" }

	--==================================================================--
	--  UTILS
	--==================================================================--
	local function New(class, props, kids)
		local o = Instance.new(class)
		local parent
		for k, v in pairs(props or {}) do
			if k == "Parent" then parent = v else o[k] = v end
		end
		for _, c in ipairs(kids or {}) do c.Parent = o end
		if parent then o.Parent = parent end
		return o
	end

	local function Round(o, r) return New("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end

	local function Stroke(o, color, thick, trans)
		return New("UIStroke", { Color = color, Thickness = thick or 1, Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
	end

	local function Tween(o, t, props, style, dir)
		local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
		tw:Play()
		return tw
	end

	local function Label(parent, text, size, color, font, align, props)
		local l = New("TextLabel", {
			BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or T.text,
			Font = font or Enum.Font.GothamMedium, TextXAlignment = align or Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
		})
		if props then for k, v in pairs(props) do l[k] = v end end
		return l
	end

	local function Icon(parent, key, size, color, pos)
		local id = ICONS[key]
		if id and id ~= "" then
			return New("ImageLabel", { BackgroundTransparency = 1, Image = id, Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), ImageColor3 = color or T.text, Parent = parent })
		end
		return New("TextLabel", {
			BackgroundTransparency = 1, Text = GLYPH[key] or "?", TextColor3 = color or T.text, Font = Enum.Font.GothamBold,
			TextSize = size, Size = UDim2.fromOffset(size, size), Position = pos or UDim2.new(), Parent = parent,
		})
	end

	local function Hover(btn, target, normal, hover)
		btn.MouseEnter:Connect(function() Tween(target, 0.15, { BackgroundColor3 = hover }) end)
		btn.MouseLeave:Connect(function() Tween(target, 0.2, { BackgroundColor3 = normal }) end)
	end

	local function DateKey(s)
		local d, m, y = string.match(s or "", "(%d+)%.(%d+)%.(%d+)")
		return (tonumber(y) or 0) * 10000 + (tonumber(m) or 0) * 100 + (tonumber(d) or 0)
	end

	--==================================================================--
	--  ROOT GUIS
	--==================================================================--
	local genv = (getgenv and getgenv()) or _G
	if genv.JustXLibraryUnload then pcall(genv.JustXLibraryUnload) end

	local function Mount(gui)
		local ok = pcall(function() gui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
		if not ok or not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
	end

	local Main = New("ScreenGui", { Name = "JustXLibrary", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local Overlay = New("ScreenGui", { Name = "JustXLibraryOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	Mount(Main)
	Mount(Overlay)

	local Blur
	if CFG.Blur > 0 then
		pcall(function() Blur = New("BlurEffect", { Size = 0, Parent = Lighting }) end)
	end

	local State = { Cat = "All Assets", Type = "All Types", Sort = "Popular", Search = "", Mode = "Grid", Page = 1, FavOnly = false, Selected = nil, Scale = 1 }
	local Favs = {}
	local Preview -- current preview object
	local OpenPreview
	local RefreshBrowser
	local scaleObjects = {}

	local function UpdateScale()
		local vs = Overlay.AbsoluteSize
		if vs.X <= 0 then return end
		State.Scale = math.clamp(math.min(vs.X * 0.94 / 760, vs.Y * 0.94 / 500), 0.4, 1.1)
		for o in pairs(scaleObjects) do
			if o.Parent then o.Scale = State.Scale else scaleObjects[o] = nil end
		end
	end
	Overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateScale)
	task.defer(UpdateScale)

	local function ScaledWindow(frame)
		local sc = New("UIScale", { Scale = State.Scale * 0.9, Parent = frame })
		scaleObjects[sc] = true
		return sc
	end

	--==================================================================--
	--  FALLBACK MODEL BUILDERS (so everything works without real assets)
	--==================================================================--
	local WOOD, SMOOTH = Enum.Material.Wood, Enum.Material.SmoothPlastic

	local function NewPart(m, size, cf, color, mat, tint, shape)
		local p = Instance.new("Part")
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false
		p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or SMOOTH
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if shape == "Cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == "Blob" then
			New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
		end
		if tint then p:SetAttribute("Tint", true) end
		p.Parent = m
		return p
	end
	local function Blob(m, size, pos, color, mat, tint) return NewPart(m, size, CFrame.new(pos), color, mat, tint, "Blob") end
	local function Cyl(m, h, d, pos, color, mat, tint) return NewPart(m, Vector3.new(h, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, mat, tint, "Cyl") end
	local function Box(m, size, pos, color, mat, ry) return NewPart(m, size, CFrame.new(pos) * CFrame.Angles(0, ry or 0, 0), color, mat) end
	local V = Vector3.new

	local Builders = {}
	Builders.oak = function(m)
		local g = RGB(72, 132, 52)
		Cyl(m, 6, 1.3, V(0, 3, 0), RGB(110, 72, 42), WOOD)
		Blob(m, V(6, 5, 6), V(0, 7.8, 0), g, SMOOTH, true)
		Blob(m, V(4.4, 3.8, 4.4), V(2.3, 6.4, 0.8), RGB(64, 120, 46), SMOOTH, true)
		Blob(m, V(4.4, 3.8, 4.4), V(-2.3, 6.6, -0.6), RGB(80, 144, 58), SMOOTH, true)
		Blob(m, V(3.6, 3.2, 3.6), V(0.4, 10.2, 0.4), RGB(86, 150, 62), SMOOTH, true)
		Blob(m, V(4, 3, 4), V(-0.8, 6.2, 2.2), RGB(60, 112, 44), SMOOTH, true)
	end
	Builders.pine = function(m)
		Cyl(m, 2, 0.9, V(0, 1, 0), RGB(100, 66, 40), WOOD)
		local y, d = 2.3, 5
		for i = 1, 5 do
			Cyl(m, 1.5, d, V(0, y, 0), RGB(30 + i * 4, 90 + i * 6, 52), SMOOTH, true)
			y = y + 1.25; d = d - 0.85
		end
	end
	Builders.birch = function(m)
		Cyl(m, 7, 0.85, V(0, 3.5, 0), RGB(232, 230, 222), SMOOTH)
		Blob(m, V(4.4, 4, 4.4), V(0, 8, 0), RGB(104, 168, 70), SMOOTH, true)
		Blob(m, V(3.2, 3, 3.2), V(1.6, 6.6, 0.4), RGB(92, 154, 62), SMOOTH, true)
		Blob(m, V(3.2, 3, 3.2), V(-1.5, 9.2, -0.4), RGB(116, 180, 80), SMOOTH, true)
	end
	Builders.bush = function(m)
		Blob(m, V(4.2, 2.8, 4), V(0, 1.4, 0), RGB(64, 130, 48), SMOOTH, true)
		Blob(m, V(3, 2.2, 3), V(1.7, 1.1, 0.8), RGB(76, 146, 56), SMOOTH, true)
		Blob(m, V(3, 2.4, 3), V(-1.6, 1.2, -0.6), RGB(58, 120, 44), SMOOTH, true)
		Blob(m, V(2.6, 2, 2.6), V(0.2, 2.4, -0.4), RGB(84, 154, 60), SMOOTH, true)
	end
	Builders.rock = function(m)
		local g = RGB(128, 128, 138)
		Blob(m, V(5, 3, 4), V(0, 1.4, 0), g, Enum.Material.Slate)
		Blob(m, V(3, 2.2, 2.8), V(1.6, 0.9, 1), RGB(150, 150, 160), Enum.Material.Slate)
		Blob(m, V(2.6, 2, 2.4), V(-1.8, 0.8, -0.8), RGB(110, 110, 120), Enum.Material.Slate)
	end
	Builders.crate = function(m)
		local w, d = RGB(176, 124, 70), RGB(120, 80, 44)
		Box(m, V(3, 3, 3), V(0, 1.5, 0), w, WOOD)
		for _, x in ipairs({ -1.4, 1.4 }) do
			for _, z in ipairs({ -1.4, 1.4 }) do Box(m, V(0.3, 3.1, 0.3), V(x, 1.5, z), d, WOOD) end
		end
		Box(m, V(3.1, 0.3, 3.1), V(0, 0.15, 0), d, WOOD)
		Box(m, V(3.1, 0.3, 3.1), V(0, 2.85, 0), d, WOOD)
	end
	Builders.barrel = function(m)
		Cyl(m, 3.4, 2.4, V(0, 1.7, 0), RGB(150, 100, 56), WOOD)
		Cyl(m, 0.25, 2.55, V(0, 0.7, 0), RGB(70, 60, 56), Enum.Material.Metal)
		Cyl(m, 0.25, 2.55, V(0, 2.7, 0), RGB(70, 60, 56), Enum.Material.Metal)
	end
	Builders.lantern = function(m)
		local dark = RGB(34, 34, 40)
		Cyl(m, 0.3, 1.5, V(0, 0.15, 0), dark, Enum.Material.Metal)
		NewPart(m, V(1.1, 1.8, 1.1), CFrame.new(0, 1.2, 0), RGB(255, 196, 96), Enum.Material.Neon)
		Cyl(m, 0.3, 1.5, V(0, 2.25, 0), dark, Enum.Material.Metal)
		Cyl(m, 0.5, 0.9, V(0, 2.65, 0), dark, Enum.Material.Metal)
		for _, x in ipairs({ -0.6, 0.6 }) do
			for _, z in ipairs({ -0.6, 0.6 }) do Box(m, V(0.14, 1.8, 0.14), V(x, 1.2, z), dark, Enum.Material.Metal) end
		end
	end
	Builders.campfire = function(m)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			Blob(m, V(1, 0.8, 1), V(math.cos(a) * 1.8, 0.4, math.sin(a) * 1.8), RGB(110 + (i % 3) * 12, 108, 116), Enum.Material.Slate)
		end
		for i = 1, 3 do
			local a = i / 3 * math.pi
			NewPart(m, V(2.8, 0.45, 0.45), CFrame.new(0, 0.55, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, 0.25), RGB(100, 64, 38), WOOD, false, "Cyl")
		end
		Blob(m, V(1.4, 2.4, 1.4), V(0, 1.7, 0), RGB(255, 120, 30), Enum.Material.Neon)
		Blob(m, V(0.8, 1.5, 0.8), V(0, 1.4, 0), RGB(255, 214, 90), Enum.Material.Neon)
	end
	Builders.fence = function(m)
		local w = RGB(150, 100, 58)
		for i = -2, 2 do Box(m, V(0.5, 3, 0.5), V(i * 1.6, 1.5, 0), w, WOOD) end
		Box(m, V(7, 0.4, 0.3), V(0, 2.3, 0.1), w, WOOD)
		Box(m, V(7, 0.4, 0.3), V(0, 1.2, 0.1), w, WOOD)
	end

	local RealCache = {}
	local function BuildModel(asset, variant)
		local id = (variant and variant.Id) or asset.Id
		local m
		if asset.UseReal and id then
			local key = tostring(id)
			if RealCache[key] == nil then
				local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. id)[1] end)
				RealCache[key] = (ok and res) or false
			end
			local src = RealCache[key]
			if src then
				if src:IsA("Model") then
					m = src:Clone()
				elseif src:IsA("BasePart") then
					m = Instance.new("Model"); src:Clone().Parent = m
				end
				if m then
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("LuaSourceContainer") then d:Destroy() elseif d:IsA("BasePart") then d.Anchored = true end
					end
				end
			end
		end
		if not m then
			m = Instance.new("Model")
			;(Builders[asset.Kind] or Builders.crate)(m)
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Tint") then m:SetAttribute("HasTint", true) break end
		end
		return m
	end

	local function ApplyTint(model, color)
		local hasTint = model:GetAttribute("HasTint")
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				if p:GetAttribute("Orig") == nil then p:SetAttribute("Orig", p.Color) end
				if color then
					if p:GetAttribute("Tint") or not hasTint then p.Color = color end
				else
					p.Color = p:GetAttribute("Orig")
				end
			end
		end
	end

	local function FirstTintColor(model)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") and (p:GetAttribute("Tint") or not model:GetAttribute("HasTint")) then
				return p:GetAttribute("Orig") or p.Color
			end
		end
		return RGB(120, 120, 140)
	end

	local function SetupViewport(vp)
		vp.Ambient = RGB(150, 150, 178)
		vp.LightColor = RGB(255, 246, 232)
		vp.LightDirection = V(-0.8, -1.4, -0.6)
		local cam = Instance.new("Camera")
		cam.FieldOfView = 38
		cam.Parent = vp
		vp.CurrentCamera = cam
		return cam
	end

	--==================================================================--
	--  POPUPS + TOAST
	--==================================================================--
	local PopupCatcher
	local function ClosePopup()
		if PopupCatcher then PopupCatcher:Destroy(); PopupCatcher = nil end
	end

	-- items: { {text=, glyph=, color=} ... }
	local function OpenListPopup(anchor, items, current, onPick, opts)
		ClosePopup()
		opts = opts or {}
		local catcher = New("TextButton", { Name = "PopupCatcher", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 50, AutoButtonColor = false, Parent = Overlay })
		PopupCatcher = catcher
		catcher.Activated:Connect(ClosePopup)

		local s = State.Scale
		local aw = anchor.AbsoluteSize.X
		local w = math.max(aw, (opts.MinWidth or 0) * s)
		local rowH = 32
		local h = #items * rowH + 10
		local pop = New("Frame", { BackgroundColor3 = T.popup, Size = UDim2.fromOffset(w / s, h), ZIndex = 51, Parent = catcher })
		Round(pop, 12); Stroke(pop, T.stroke, 1, 0)
		local sc = New("UIScale", { Scale = s * 0.92, Parent = pop })

		local ap, screen = anchor.AbsolutePosition, Overlay.AbsoluteSize
		local x = opts.AlignRight and (ap.X + aw - w) or ap.X
		local y = ap.Y + anchor.AbsoluteSize.Y + 6
		if y + h * s > screen.Y - 8 then y = ap.Y - h * s - 6 end
		x = math.clamp(x, 8, math.max(8, screen.X - w - 8))
		y = math.max(8, y)
		pop.Position = UDim2.fromOffset(x, y)

		for i, it in ipairs(items) do
			local sel = (it.text == current)
			local b = New("TextButton", {
				AutoButtonColor = false, Text = "", BackgroundColor3 = T.accent, BackgroundTransparency = sel and 0.75 or 1,
				Size = UDim2.new(1, -10, 0, rowH - 4), Position = UDim2.fromOffset(5, 5 + (i - 1) * rowH), Parent = pop,
			})
			Round(b, 8)
			local tx = 12
			if it.color then
				local dot = New("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 10, 0.5, -8), BackgroundColor3 = it.color, Parent = b })
				Round(dot, 8); tx = 34
			elseif it.glyph then
				Icon(b, it.glyph, 16, sel and T.accent2 or T.sub, UDim2.new(0, 10, 0.5, -8)); tx = 34
			end
			Label(b, it.text, 13, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.new(0, tx, 0, 0), Size = UDim2.new(1, -tx - 6, 1, 0) })
			b.MouseEnter:Connect(function() if not sel then Tween(b, 0.12, { BackgroundTransparency = 0.88 }) end end)
			b.MouseLeave:Connect(function() if not sel then Tween(b, 0.15, { BackgroundTransparency = 1 }) end end)
			b.Activated:Connect(function() ClosePopup(); onPick(it) end)
		end
		Tween(sc, 0.18, { Scale = s }, Enum.EasingStyle.Back)
	end

	local function Dropdown(parent, size, pos, items, value, onPick, dotColor)
		local btn = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Size = size, Position = pos, Parent = parent })
		Round(btn, 10)
		local st = Stroke(btn, T.stroke, 1, 0)
		local dot, tx = nil, 12
		if dotColor then
			dot = New("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 10, 0.5, -9), BackgroundColor3 = dotColor, Parent = btn })
			Round(dot, 9); tx = 36
		end
		local lbl = Label(btn, value, 13, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.new(0, tx, 0, 0), Size = UDim2.new(1, -tx - 30, 1, 0) })
		Label(btn, "▾", 14, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.new(1, -28, 0, 0), Size = UDim2.new(0, 24, 1, 0) })
		btn.MouseEnter:Connect(function() Tween(st, 0.15, { Color = T.accent }) end)
		btn.MouseLeave:Connect(function() Tween(st, 0.2, { Color = T.stroke }) end)
		btn.Activated:Connect(function()
			local its = {}
			for _, n in ipairs(items) do table.insert(its, { text = n }) end
			OpenListPopup(btn, its, lbl.Text, function(it) lbl.Text = it.text; onPick(it.text) end, {})
		end)
		return { Button = btn, Set = function(v) lbl.Text = v end, SetDot = function(c) if dot then dot.BackgroundColor3 = c end end }
	end

	local function Toast(text)
		local f = New("Frame", { BackgroundColor3 = T.popup, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 30), Size = UDim2.fromOffset(240, 38), ZIndex = 80, Parent = Overlay })
		Round(f, 12); Stroke(f, T.accent, 1, 0.3)
		New("UIScale", { Scale = State.Scale, Parent = f })
		Label(f, text, 13, T.text, Enum.Font.GothamMedium, Enum.TextXAlignment.Center, { Size = UDim2.fromScale(1, 1), ZIndex = 81 })
		Tween(f, 0.3, { Position = UDim2.new(0.5, 0, 1, -24) }, Enum.EasingStyle.Back)
		task.delay(1.8, function()
			Tween(f, 0.25, { Position = UDim2.new(0.5, 0, 1, 40) })
			task.delay(0.3, function() f:Destroy() end)
		end)
	end

	--==================================================================--
	--  SMALL WIDGETS (slider / toggle)
	--==================================================================--
	local function Slider(parent, pos, width, min, max, init, onChange, track, onDrag)
		local bar = New("Frame", { Position = pos, Size = UDim2.fromOffset(width, 6), BackgroundColor3 = T.track, Parent = parent })
		Round(bar, 3)
		local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent, Parent = bar })
		Round(fill, 3)
		local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.accent2, Parent = bar })
		Round(knob, 9)
		local hit = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.new(1, 20, 0, 32), Position = UDim2.new(0, -10, 0.5, -16), Parent = bar })

		local function set(v, silent)
			v = math.clamp(v, min, max)
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1); knob.Position = UDim2.fromScale(a, 0.5)
			if not silent and onChange then onChange(v) end
		end
		local dragging = false
		local function fromX(x) set(min + (max - min) * math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)) end
		hit.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; if onDrag then onDrag(true) end
				fromX(i.Position.X)
			end
		end)
		track(UIS.InputChanged, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
		end)
		track(UIS.InputEnded, function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				dragging = false; if onDrag then onDrag(false) end
			end
		end)
		set(init, true)
		return set
	end

	local function Toggle(parent, init, cb)
		local on = init
		local sw = New("TextButton", { AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(46, 26), BackgroundColor3 = on and T.accent or T.track, Parent = parent })
		Round(sw, 13)
		local k = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, on and 23 or 3, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sw })
		Round(k, 10)
		sw.Activated:Connect(function()
			on = not on
			Tween(sw, 0.2, { BackgroundColor3 = on and T.accent or T.track })
			Tween(k, 0.25, { Position = UDim2.new(0, on and 23 or 3, 0.5, 0) }, Enum.EasingStyle.Back)
			cb(on)
		end)
	end

	--==================================================================--
	--  PREVIEW WINDOW
	--==================================================================--
	local COLORS = {
		{ text = "Default" },
		{ text = "Green", color = RGB(86, 150, 62) },
		{ text = "Red", color = RGB(200, 70, 70) },
		{ text = "Blue", color = RGB(70, 120, 210) },
		{ text = "Orange", color = RGB(220, 130, 50) },
		{ text = "Purple", color = RGB(140, 90, 220) },
		{ text = "Gray", color = RGB(140, 140, 150) },
	}

	local FullHolder = New("Frame", { Visible = false, BackgroundColor3 = RGB(10, 9, 20), BackgroundTransparency = 0.1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Active = true, Parent = Overlay })

	local function DestroyPreview(instant)
		if not Preview then return end
		local p = Preview
		Preview = nil
		p.Destroy(instant)
	end

	OpenPreview = function(asset, tab)
		tab = tab or "Controllers"
		if Preview then
			if Preview.Asset == asset then Preview.SetTab(tab) return end
			DestroyPreview(true)
		end

		local conns, destroyed = {}, false
		local function Track(sig, fn) table.insert(conns, sig:Connect(fn)) end

		local variants = asset.Variants or { { Name = asset.Name } }
		local variantIndex, userColor, curScale, castShadow = 1, nil, 1, true
		local model, loadId, scaleDirty = nil, 0, false
		local curTab

		-- backdrop
		local dim = New("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = Overlay })
		Tween(dim, 0.25, { BackgroundTransparency = 0.5 })
		if Blur then Tween(Blur, 0.3, { Size = CFG.Blur }) end

		-- window
		local win = New("Frame", { BackgroundColor3 = T.bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 430), ZIndex = 3, Parent = Overlay })
		Round(win, 16); Stroke(win, T.stroke, 1.5, 0)
		local sc = ScaledWindow(win)
		Tween(sc, 0.35, { Scale = State.Scale }, Enum.EasingStyle.Back)

		Icon(win, "cube", 30, T.text, UDim2.fromOffset(20, 14))
		Label(win, "Preview", 22, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(62, 12), Size = UDim2.fromOffset(300, 34) })
		local closeBtn = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(640 - 50, 10), Size = UDim2.fromOffset(36, 36), Parent = win })
		Round(closeBtn, 10); Icon(closeBtn, "close", 18, T.text, UDim2.fromOffset(9, 9))
		Hover(closeBtn, closeBtn, T.field, RGB(160, 60, 80))

		-- tabs
		local tabs, tabNames = {}, { { "Controllers", "gamepad" }, { "Info", "info" }, { "Preview", "eye" } }
		for i, tn in ipairs(tabNames) do
			local b = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(16 + (i - 1) * 142, 60), Size = UDim2.fromOffset(134, 36), Parent = win })
			Round(b, 10)
			Icon(b, tn[2], 16, T.text, UDim2.fromOffset(12, 10))
			local l = Label(b, tn[1], 14, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0) })
			tabs[tn[1]] = b
			b.Activated:Connect(function() Preview.SetTab(tn[1]) end)
		end
		New("Frame", { BackgroundColor3 = T.stroke, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 1), Parent = win })

		-- left panel
		local left = New("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 114), Size = UDim2.fromOffset(250, 302),
			ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = win,
		})
		New("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
		New("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = left })

		local function Section(title, glyph, order)
			local sec = New("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order, Parent = left })
			New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sec })
			local h = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = sec })
			Icon(h, glyph, 18, T.sub, UDim2.fromOffset(2, 3))
			Label(h, title, 17, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0) })
			return sec
		end

		-- viewer box (right)
		local BOX_SMALL = { UDim2.fromOffset(280, 114), UDim2.fromOffset(344, 302) }
		local BOX_WIDE = { UDim2.fromOffset(16, 114), UDim2.fromOffset(608, 302) }
		local box = New("Frame", { BackgroundColor3 = RGB(48, 52, 84), Position = BOX_SMALL[1], Size = BOX_SMALL[2], ClipsDescendants = true, Active = true, Parent = win })
		Round(box, 14)
		New("UIGradient", { Color = ColorSequence.new(RGB(66, 72, 108), RGB(34, 38, 66)), Rotation = 90, Parent = box })
		local vp = New("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = box })
		local cam = SetupViewport(vp)
		local floor = NewPart(vp, V(0.2, 40, 40), CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), RGB(44, 50, 82), SMOOTH, false, "Cyl")
		floor.Transparency = 0.25
		local shadow = NewPart(vp, V(0.05, 8, 8), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), RGB(8, 8, 18), SMOOTH, false, "Cyl")
		shadow.Transparency = 0.55
		local loading = Label(box, "Loading…", 14, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Center, { Size = UDim2.fromScale(1, 1), ZIndex = 5 })

		-- Controllers: Variants
		local secVar = Section("Variants", "models", 1)
		local varDD
		do
			local names = {}
			for _, v in ipairs(variants) do table.insert(names, v.Name) end
			varDD = Dropdown(secVar, UDim2.new(1, 0, 0, 44), UDim2.new(), names, variants[1].Name, function(n)
				for i, v in ipairs(variants) do if v.Name == n then Preview.SetVariant(i) end end
			end, variants[1].Tint or T.accent)
			varDD.Button.LayoutOrder = 1
		end

		-- Controllers: Settings
		local secSet = Section("Settings", "others", 2)
		local setBox = New("Frame", { BackgroundColor3 = T.field, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = secSet })
		Round(setBox, 12)
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = setBox })
		local r1 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1, Parent = setBox })
		Label(r1, "Cast Shadows", 14, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0) })
		Toggle(r1, true, function(on) castShadow = on; Tween(shadow, 0.25, { Transparency = on and 0.55 or 1 }) end)

		local r2 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 2, Parent = setBox })
		Label(r2, "Scale", 14, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(100, 26) })
		local scaleBox = New("TextBox", { Text = "1.00", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = T.text, BackgroundColor3 = T.bg, Position = UDim2.new(1, -72, 0, 5), Size = UDim2.fromOffset(60, 28), Parent = r2 })
		Round(scaleBox, 8); Stroke(scaleBox, T.stroke, 1, 0)
		local setScale
		setScale = Slider(r2, UDim2.fromOffset(12, 46), 200, 0.25, 3, 1, function(v)
			curScale = v; scaleDirty = true; scaleBox.Text = string.format("%.2f", v)
		end, Track, function(d) left.ScrollingEnabled = not d end)
		scaleBox.FocusLost:Connect(function()
			local n = tonumber(scaleBox.Text) or curScale
			n = math.clamp(n, 0.25, 3)
			curScale = n; scaleDirty = true; scaleBox.Text = string.format("%.2f", n); setScale(n, true)
		end)

		local r3 = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 3, Parent = setBox })
		Label(r3, "Color", 14, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -90, 1, 0) })
		local swatch = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.bg, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(68, 30), Parent = r3 })
		Round(swatch, 8); Stroke(swatch, T.stroke, 1, 0)
		local swDot = New("Frame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(34, 20), BackgroundColor3 = RGB(86, 150, 62), Parent = swatch })
		Round(swDot, 6)
		Label(swatch, "▾", 13, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(18, 30) })

		-- Info
		local secInfo = Section("Info", "info", 3)
		local infoBox = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = secInfo })
		New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = infoBox })
		local extraRows = {}
		local function InfoRow(k, v, order, extra, copy)
			local r = New("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Parent = infoBox })
			Label(r, k, 13, T.sub, Enum.Font.Gotham, nil, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(70, 24) })
			local l = Label(r, v, 13, copy and T.accent2 or T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(78, 0), Size = UDim2.new(1, -80, 1, 0) })
			if copy then
				local b = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = r })
				b.Activated:Connect(function()
					if setclipboard then pcall(setclipboard, v); Toast("ID copied") else Toast("Clipboard not supported") end
				end)
			end
			if extra then r.Visible = false; table.insert(extraRows, r) end
		end
		InfoRow("Name:", asset.Name, 1)
		InfoRow("Type:", asset.Type, 2)
		InfoRow("ID:", "rbxassetid://" .. tostring(asset.Id or "—"), 3, false, true)
		InfoRow("Creator:", asset.Creator or "—", 4)
		InfoRow("Created:", asset.Created or "—", 5)
		InfoRow("Category:", asset.Cat or "—", 6, true)
		InfoRow("Variants:", tostring(#variants), 7, true)

		-- Favorites button
		local favBtn = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4, Parent = left })
		Round(favBtn, 10); Stroke(favBtn, T.stroke, 1, 0)
		local favIcon = Label(favBtn, "☆", 16, T.star, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(24, 40) })
		local favText = Label(favBtn, "Add to Favorites", 14, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(70, 0), Size = UDim2.new(1, -74, 1, 0) })
		Hover(favBtn, favBtn, T.field, T.cardHover)
		local function RefreshFav()
			local f = Favs[asset.Name]
			favIcon.Text = f and "★" or "☆"
			favText.Text = f and "In Favorites" or "Add to Favorites"
		end
		favBtn.Activated:Connect(function()
			Favs[asset.Name] = (not Favs[asset.Name]) or nil
			RefreshFav(); RefreshBrowser(false)
		end)
		RefreshFav()

		-- Viewer controls
		local mode = "Rotate"
		local modeBtns = {}
		local modeDefs = { { "Rotate", "rotate" }, { "Pan", "pan" }, { "Zoom", "zoom" } }
		local function StyleModes()
			for name, b in pairs(modeBtns) do Tween(b, 0.15, { BackgroundColor3 = (name == mode) and T.accent or RGB(34, 36, 62) }) end
		end
		for i, d in ipairs(modeDefs) do
			local b = New("TextButton", { AutoButtonColor = false, Text = "", AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = RGB(34, 36, 62), Position = UDim2.new(0, 10 + (i - 1) * 48, 1, -10), Size = UDim2.fromOffset(40, 40), Parent = box })
			Round(b, 10); Icon(b, d[2], 20, T.text, UDim2.fromOffset(10, 10))
			modeBtns[d[1]] = b
			b.Activated:Connect(function() mode = d[1]; StyleModes() end)
		end
		StyleModes()

		local pager = New("Frame", { AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = RGB(34, 36, 62), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(112, 40), Parent = box })
		Round(pager, 10)
		local pageLbl = Label(pager, "1 / " .. #variants, 14, T.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(52, 40) })
		for _, d in ipairs({ { "◀", 0, -1 }, { "▶", 82, 1 } }) do
			local b = New("TextButton", { BackgroundTransparency = 1, Text = d[1], TextColor3 = T.text, TextSize = 14, Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(d[2], 0), Size = UDim2.fromOffset(30, 40), Parent = pager })
			b.Activated:Connect(function()
				local n = variantIndex + d[3]
				if n >= 1 and n <= #variants then Preview.SetVariant(n) end
			end)
		end

		local fsBtn = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = RGB(34, 36, 62), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36), Parent = box })
		Round(fsBtn, 10); Icon(fsBtn, "expand", 18, T.text, UDim2.fromOffset(9, 9))
		Hover(fsBtn, fsBtn, RGB(34, 36, 62), T.accent)

		--==============  camera / smoothing  ==============--
		local yaw, pitch, dist, pan = 0.6, 0.28, 14, V(0, 0, 0)
		local tYaw, tPitch, tDist, tPan = yaw, pitch, dist, pan
		local center, radius, baseDist = V(0, 3, 0), 5, 14
		local lastInput = os.clock()
		local dragging, dragInput, pinching, pinchBase = false, nil, false, nil

		local function UpdateFloor()
			if not model then return end
			local cf, size = model:GetBoundingBox()
			local bottom = cf.Position.Y - size.Y / 2
			local fcf = CFrame.new(cf.Position.X, bottom - 0.06, cf.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
			floor.CFrame = fcf; floor.Size = V(0.12, radius * 6, radius * 6)
			local w = math.max(size.X, size.Z) * 1.15
			shadow.CFrame = CFrame.new(cf.Position.X, bottom + 0.02, cf.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
			shadow.Size = V(0.05, w, w)
		end

		local function ApplyAppearance()
			if not model then return end
			ApplyTint(model, userColor or variants[variantIndex].Tint)
			local c = userColor or variants[variantIndex].Tint or FirstTintColor(model)
			Tween(swDot, 0.2, { BackgroundColor3 = c })
			varDD.SetDot(variants[variantIndex].Tint or c)
		end

		local function Fit(keepAngles)
			local cf, size = model:GetBoundingBox()
			center = cf.Position; radius = math.max(size.Magnitude / 2, 0.5)
			baseDist = radius * 2.5
			tDist = baseDist; dist = baseDist * 1.3
			tPan = V(0, 0, 0); pan = tPan
			if not keepAngles then tPitch = 0.28 end
			UpdateFloor()
		end

		local function LoadVariant(i)
			variantIndex = i; loadId += 1
			local my = loadId
			varDD.Set(variants[i].Name)
			pageLbl.Text = i .. " / " .. #variants
			loading.Visible = true
			task.spawn(function()
				local m = BuildModel(asset, variants[i])
				if destroyed or my ~= loadId then m:Destroy() return end
				if model then model:Destroy() end
				model = m
				pcall(function() model:ScaleTo(curScale) end)
				model.Parent = vp
				Fit(true)
				ApplyAppearance()
				loading.Visible = false
			end)
		end

		local function Clamp() tPitch = math.clamp(tPitch, -1.3, 1.3); tDist = math.clamp(tDist, radius * 0.7, radius * 8) end

		Track(RunService.RenderStepped, function(dt)
			if destroyed then return end
			if scaleDirty and model then
				scaleDirty = false
				pcall(function() model:ScaleTo(curScale) end)
				UpdateFloor()
			end
			if AutoRot() and not dragging and not pinching and os.clock() - lastInput > 2.5 then tYaw -= dt * RotSpeed() end
			local a = 1 - math.exp(-dt * 12)
			yaw += (tYaw - yaw) * a
			pitch += (tPitch - pitch) * a
			dist += (tDist - dist) * a
			pan = pan:Lerp(tPan, a)
			local dir = V(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
			local tgt = center + pan
			cam.CFrame = CFrame.lookAt(tgt + dir * dist, tgt)
		end)

		box.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton2 then
				dragging = true; dragInput = i; lastInput = os.clock()
				if i.UserInputType == Enum.UserInputType.MouseButton2 then dragInput.UserInputType = i.UserInputType end
			end
		end)
		Track(UIS.InputEnded, function(i) if i == dragInput then dragging = false; dragInput = nil end end)
		Track(UIS.InputChanged, function(i)
			if dragging and not pinching and (i.UserInputType == Enum.UserInputType.MouseMovement or i == dragInput) then
				local d = i.Delta
				lastInput = os.clock()
				local m = mode
				if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then m = "Pan" end
				if m == "Rotate" then
					tYaw -= d.X * 0.008; tPitch += d.Y * 0.008
				elseif m == "Pan" then
					local cf = cam.CFrame
					tPan = tPan + (-cf.RightVector * d.X + cf.UpVector * d.Y) * (tDist * 0.0016)
				else
					tDist = tDist * (1 + d.Y * 0.006)
				end
				Clamp()
			end
		end)
		box.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseWheel then
				lastInput = os.clock()
				tDist = tDist * (1 - i.Position.Z * 0.1); Clamp()
			end
		end)
		Track(UIS.TouchPinch, function(pos, scale, _, st)
			local p = pos[1]
			local ap, as = box.AbsolutePosition, box.AbsoluteSize
			if not p or p.X < ap.X or p.Y < ap.Y or p.X > ap.X + as.X or p.Y > ap.Y + as.Y then if st == Enum.UserInputState.End then pinching = false end return end
			lastInput = os.clock()
			if st == Enum.UserInputState.Begin then pinching = true; pinchBase = tDist
			elseif st == Enum.UserInputState.Change and pinchBase then tDist = pinchBase / math.max(scale, 0.05); Clamp()
			elseif st == Enum.UserInputState.End then pinching = false end
		end)

		swatch.Activated:Connect(function()
			OpenListPopup(swatch, COLORS, userColor and "" or "Default", function(it)
				userColor = it.color; ApplyAppearance()
			end, { AlignRight = true, MinWidth = 150 })
		end)

		--==============  fullscreen  ==============--
		local full = false
		fsBtn.Activated:Connect(function()
			full = not full
			if full then
				FullHolder.Visible = true
				box.Parent = FullHolder; box.Position = UDim2.fromOffset(10, 10); box.Size = UDim2.new(1, -20, 1, -20)
			else
				box.Parent = win
				local t = (curTab == "Preview") and BOX_WIDE or BOX_SMALL
				box.Position = t[1]; box.Size = t[2]
				FullHolder.Visible = false
			end
		end)

		--==============  tabs / layout  ==============--
		local P = {}
		P.Asset = asset
		function P.SetTab(name)
			curTab = name
			for n, b in pairs(tabs) do Tween(b, 0.2, { BackgroundColor3 = (n == name) and T.accent or T.field }) end
			secVar.Visible = (name == "Controllers"); secSet.Visible = (name == "Controllers")
			secInfo.Visible = (name ~= "Preview")
			favBtn.Visible = (name ~= "Preview")
			left.Visible = (name ~= "Preview")
			for _, r in ipairs(extraRows) do r.Visible = (name == "Info") end
			left.CanvasPosition = Vector2.zero
			if not full then
				local t = (name == "Preview") and BOX_WIDE or BOX_SMALL
				Tween(box, 0.35, { Position = t[1], Size = t[2] })
			end
		end
		function P.SetVariant(i) LoadVariant(i) end
		function P.Destroy(instant)
			if destroyed then return end
			destroyed = true
			for _, c in ipairs(conns) do c:Disconnect() end
			ClosePopup()
			FullHolder.Visible = false
			if Blur then Tween(Blur, 0.25, { Size = 0 }) end
			local function kill()
				if box then box:Destroy() end
				win:Destroy(); dim:Destroy()
			end
			if instant then kill() return end
			Tween(dim, 0.2, { BackgroundTransparency = 1 })
			Tween(sc, 0.2, { Scale = State.Scale * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.22, kill)
		end
		Preview = P

		closeBtn.Activated:Connect(function() DestroyPreview(false) end)
		dim.Activated:Connect(function() DestroyPreview(false) end)

		P.SetTab(tab)
		LoadVariant(1)
	end

	--==================================================================--
	--  ASSET BROWSER
	--==================================================================--
	local Win = New("Frame", { Name = "Browser", BackgroundColor3 = T.bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 500), Parent = Main })
	Round(Win, 18); Stroke(Win, T.stroke, 1.5, 0)
	local WinScale = ScaledWindow(Win)
	Tween(WinScale, 0.4, { Scale = State.Scale }, Enum.EasingStyle.Back)

	-- Sidebar
	local side = New("Frame", { BackgroundColor3 = T.side, Size = UDim2.fromOffset(180, 500), Parent = Win })
	Round(side, 18)
	New("Frame", { BackgroundColor3 = T.side, BorderSizePixel = 0, Position = UDim2.new(1, -20, 0, 0), Size = UDim2.new(0, 20, 1, 0), Parent = side })

	local logoClip = New("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(34, 34), Parent = side })
	New("ImageLabel", { BackgroundTransparency = 1, Image = CFG.LogoImage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(CFG.LogoZoom, CFG.LogoZoom), ScaleType = Enum.ScaleType.Fit, Parent = logoClip })
	Label(side, "Just X Library", 15, T.sub, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(58, 14), Size = UDim2.fromOffset(116, 34) })
	New("Frame", { BackgroundColor3 = T.stroke, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 1), Parent = side })

	local catButtons, catCounts = {}, {}
	local function CountCat(c)
		if c == "All Assets" then return #ASSETS end
		local n = 0
		for _, a in ipairs(ASSETS) do if a.Cat == c then n += 1 end end
		return n
	end
	local function StyleCats()
		for c, b in pairs(catButtons) do
			Tween(b, 0.2, { BackgroundTransparency = (c == State.Cat) and 0 or 1 })
		end
	end
	for i, c in ipairs(CATS) do
		local b = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.accent, BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 72 + (i - 1) * 38), Size = UDim2.fromOffset(160, 34), Parent = side })
		Round(b, 10)
		Icon(b, CAT_ICON[c], 18, T.text, UDim2.fromOffset(10, 8))
		Label(b, c, 14, T.text, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(38, 0), Size = UDim2.fromOffset(86, 34) })
		local pill = New("Frame", { BackgroundColor3 = RGB(44, 42, 76), Position = UDim2.new(1, -38, 0.5, -10), Size = UDim2.fromOffset(32, 20), Parent = b })
		Round(pill, 10)
		Label(pill, tostring(CountCat(c)), 11, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Size = UDim2.fromScale(1, 1) })
		catButtons[c] = b
		b.MouseEnter:Connect(function() if State.Cat ~= c then Tween(b, 0.15, { BackgroundTransparency = 0.85 }) end end)
		b.MouseLeave:Connect(function() if State.Cat ~= c then Tween(b, 0.2, { BackgroundTransparency = 1 }) end end)
		b.Activated:Connect(function() State.Cat = c; State.Page = 1; StyleCats(); RefreshBrowser(true) end)
	end

	local browse = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(10, 500 - 70), Size = UDim2.fromOffset(160, 56), Parent = side })
	Round(browse, 12); Stroke(browse, T.stroke, 1, 0)
	Label(browse, "✦", 22, T.accent2, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(34, 56) })
	Label(browse, "Browse more assets in Roblox", 12, T.sub, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(112, 56), TextWrapped = true, TextTruncate = Enum.TextTruncate.None })
	Hover(browse, browse, T.field, T.cardHover)
	browse.Activated:Connect(function()
		if setclipboard then pcall(setclipboard, CFG.BrowseUrl); Toast("Link copied") else Toast(CFG.BrowseUrl) end
	end)

	-- Header
	Icon(Win, "cube", 30, T.text, UDim2.fromOffset(198, 14))
	Label(Win, "Asset Browser", 21, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(238, 12), Size = UDim2.fromOffset(180, 34) })

	local closeMain = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(760 - 50, 10), Size = UDim2.fromOffset(36, 36), Parent = Win })
	Round(closeMain, 10); Icon(closeMain, "close", 18, T.text, UDim2.fromOffset(9, 9))
	Hover(closeMain, closeMain, T.field, RGB(160, 60, 80))

	local favPill = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(760 - 50 - 138, 10), Size = UDim2.fromOffset(128, 36), Parent = Win })
	Round(favPill, 10)
	local favStroke = Stroke(favPill, T.stroke, 1, 0)
	Label(favPill, "★", 15, T.star, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(22, 36) })
	Label(favPill, "Favorites", 14, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(32, 0), Size = UDim2.fromOffset(66, 36) })
	local favCountPill = New("Frame", { BackgroundColor3 = T.accent, Position = UDim2.new(1, -32, 0.5, -10), Size = UDim2.fromOffset(26, 20), Parent = favPill })
	Round(favCountPill, 10)
	local favCount = Label(favCountPill, "0", 12, Color3.new(1, 1, 1), Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Size = UDim2.fromScale(1, 1) })
	favPill.Activated:Connect(function()
		State.FavOnly = not State.FavOnly; State.Page = 1
		Tween(favStroke, 0.2, { Color = State.FavOnly and T.accent or T.stroke })
		RefreshBrowser(true)
	end)

	-- Toolbar
	local search = New("Frame", { BackgroundColor3 = T.field, Position = UDim2.fromOffset(196, 62), Size = UDim2.fromOffset(222, 38), Parent = Win })
	Round(search, 10)
	local searchStroke = Stroke(search, T.stroke, 1, 0)
	Label(search, "⌕", 18, T.sub, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(28, 38) })
	local searchBox = New("TextBox", { BackgroundTransparency = 1, ClearTextOnFocus = false, Text = "", PlaceholderText = "Search assets…", PlaceholderColor3 = T.sub, TextColor3 = T.text, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Parent = search })
	searchBox.Focused:Connect(function() Tween(searchStroke, 0.15, { Color = T.accent }) end)
	searchBox.FocusLost:Connect(function() Tween(searchStroke, 0.2, { Color = T.stroke }) end)
	local searchToken = 0
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchToken += 1
		local my = searchToken
		task.delay(0.18, function()
			if my == searchToken then State.Search = searchBox.Text; State.Page = 1; RefreshBrowser(true) end
		end)
	end)

	local typeList = { "All Types" }
	do
		local seen = {}
		for _, a in ipairs(ASSETS) do if not seen[a.Type] then seen[a.Type] = true; table.insert(typeList, a.Type) end end
	end
	Dropdown(Win, UDim2.fromOffset(112, 38), UDim2.fromOffset(426, 62), typeList, "All Types", function(v) State.Type = v; State.Page = 1; RefreshBrowser(true) end)
	Dropdown(Win, UDim2.fromOffset(112, 38), UDim2.fromOffset(546, 62), { "Popular", "Name A-Z", "Newest" }, "Popular", function(v) State.Sort = v; State.Page = 1; RefreshBrowser(true) end)

	local modeGrid = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.accent, Position = UDim2.fromOffset(666, 62), Size = UDim2.fromOffset(38, 38), Parent = Win })
	Round(modeGrid, 10); Icon(modeGrid, "all", 18, T.text, UDim2.fromOffset(10, 10))
	local modeList = New("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = T.field, Position = UDim2.fromOffset(708, 62), Size = UDim2.fromOffset(38, 38), Parent = Win })
	Round(modeList, 10); Label(modeList, "☰", 18, T.text, Enum.Font.GothamBold, Enum.TextXAlignment.Center, { Size = UDim2.fromScale(1, 1) })
	local function StyleMode()
		Tween(modeGrid, 0.2, { BackgroundColor3 = State.Mode == "Grid" and T.accent or T.field })
		Tween(modeList, 0.2, { BackgroundColor3 = State.Mode == "List" and T.accent or T.field })
	end
	modeGrid.Activated:Connect(function() State.Mode = "Grid"; StyleMode(); RefreshBrowser(true) end)
	modeList.Activated:Connect(function() State.Mode = "List"; StyleMode(); RefreshBrowser(true) end)

	-- Content
	local Content = New("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(196, 110), Size = UDim2.fromOffset(552, 338),
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = Win,
	})
	local emptyLbl = Label(Win, "No assets found", 15, T.sub, Enum.Font.GothamMedium, Enum.TextXAlignment.Center, { Position = UDim2.fromOffset(196, 220), Size = UDim2.fromOffset(552, 30), Visible = false })

	local footerLbl = Label(Win, "", 13, T.sub, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(198, 462), Size = UDim2.fromOffset(200, 30) })
	local pageBar = New("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(748, 460), Size = UDim2.fromOffset(300, 32), Parent = Win })
	New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pageBar })

	local function Filtered()
		local out, q = {}, string.lower(State.Search or "")
		for _, a in ipairs(ASSETS) do
			if (State.Cat == "All Assets" or a.Cat == State.Cat)
				and (State.Type == "All Types" or a.Type == State.Type)
				and (q == "" or string.find(string.lower(a.Name), q, 1, true))
				and (not State.FavOnly or Favs[a.Name]) then
				table.insert(out, a)
			end
		end
		table.sort(out, function(a, b)
			if State.Sort == "Name A-Z" then return a.Name < b.Name end
			if State.Sort == "Newest" then
				local x, y = DateKey(a.Created), DateKey(b.Created)
				if x ~= y then return x > y end
			else
				if (a.Pop or 0) ~= (b.Pop or 0) then return (a.Pop or 0) > (b.Pop or 0) end
			end
			return a.Name < b.Name
		end)
		return out
	end

	local function Thumb(parent, asset, size, pos)
		local vp = New("ViewportFrame", { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), Parent = parent })
		local cam = SetupViewport(vp)
		task.spawn(function()
			local m = BuildModel(asset, asset.Variants and asset.Variants[1])
			if not vp.Parent then m:Destroy() return end
			m.Parent = vp
			local cf, sz = m:GetBoundingBox()
			local r = math.max(sz.Magnitude / 2, 0.5)
			cam.CFrame = CFrame.lookAt(cf.Position + V(0.55, 0.3, 1).Unit * r * 2.4, cf.Position + V(0, -r * 0.05, 0))
		end)
		return vp
	end

	local function BuildCard(asset, index, grid)
		local card = New("CanvasGroup", { Name = asset.Name, BackgroundColor3 = T.card, GroupTransparency = 1, LayoutOrder = index, Size = grid and UDim2.fromOffset(176, 106) or UDim2.new(1, -4, 0, 52), Parent = Content })
		Round(card, 12)
		local st = Stroke(card, (State.Selected == asset.Name) and T.accent or T.stroke, (State.Selected == asset.Name) and 2 or 1, (State.Selected == asset.Name) and 0 or 0.3)
		local cs = New("UIScale", { Scale = 0.92, Parent = card })

		local hit = New("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = card })
		hit.MouseEnter:Connect(function() Tween(card, 0.15, { BackgroundColor3 = T.cardHover }); Tween(st, 0.15, { Color = T.accent }) end)
		hit.MouseLeave:Connect(function() Tween(card, 0.2, { BackgroundColor3 = T.card }); Tween(st, 0.2, { Color = (State.Selected == asset.Name) and T.accent or T.stroke }) end)
		hit.Activated:Connect(function()
			State.Selected = asset.Name
			for _, c in ipairs(Content:GetChildren()) do
				if c:IsA("CanvasGroup") then
					local s = c:FindFirstChildOfClass("UIStroke")
					if s then local sel = (c.Name == asset.Name); s.Thickness = sel and 2 or 1; s.Color = sel and T.accent or T.stroke; s.Transparency = sel and 0 or 0.3 end
				end
			end
			OpenPreview(asset, "Controllers")
		end)

		local nameL, typeRow
		if grid then
			Thumb(card, asset, UDim2.new(1, 0, 0, 70), UDim2.new())
			nameL = Label(card, asset.Name, 13, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -44, 0, 18), ZIndex = 2 })
			typeRow = Label(card, "◈ " .. asset.Type, 11, T.sub, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(10, 88), Size = UDim2.new(1, -44, 0, 14), ZIndex = 2 })
		else
			Thumb(card, asset, UDim2.fromOffset(44, 44), UDim2.fromOffset(8, 4))
			nameL = Label(card, asset.Name, 14, T.text, Enum.Font.GothamBold, nil, { Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -150, 0, 18), ZIndex = 2 })
			typeRow = Label(card, "◈ " .. asset.Type .. "  ·  " .. (asset.Cat or ""), 11, T.sub, Enum.Font.GothamMedium, nil, { Position = UDim2.fromOffset(64, 28), Size = UDim2.new(1, -150, 0, 14), ZIndex = 2 })
		end

		local star = New("TextButton", { BackgroundTransparency = 1, Text = Favs[asset.Name] and "★" or "☆", TextColor3 = Favs[asset.Name] and T.star or T.sub, Font = Enum.Font.GothamBold, TextSize = 18, AnchorPoint = Vector2.new(1, 0), Position = grid and UDim2.new(1, -4, 0, 4) or UDim2.new(1, -44, 0.5, -14), Size = UDim2.fromOffset(28, 28), ZIndex = 3, Parent = card })
		star.Activated:Connect(function()
			Favs[asset.Name] = (not Favs[asset.Name]) or nil
			star.Text = Favs[asset.Name] and "★" or "☆"
			Tween(star, 0.2, { TextColor3 = Favs[asset.Name] and T.star or T.sub })
			if Preview and Preview.Asset == asset then Preview.RefreshFav() end
			RefreshBrowser(false, State.FavOnly)
		end)

		local dots = New("TextButton", { AutoButtonColor = false, Text = "···", TextColor3 = T.text, Font = Enum.Font.GothamBold, TextSize = 16, BackgroundColor3 = RGB(44, 42, 76), AnchorPoint = Vector2.new(1, 1), Position = grid and UDim2.new(1, -8, 1, -8) or UDim2.new(1, -8, 0.5, 13), Size = UDim2.fromOffset(28, 22), ZIndex = 3, Parent = card })
		Round(dots, 7)
		Hover(dots, dots, RGB(44, 42, 76), T.accent)
		dots.Activated:Connect(function()
			OpenListPopup(dots, {
				{ text = "Controllers", glyph = "gamepad" }, { text = "Info", glyph = "info" }, { text = "Preview", glyph = "eye" },
			}, nil, function(it) State.Selected = asset.Name; OpenPreview(asset, it.text) end, { AlignRight = true, MinWidth = 150 })
		end)

		task.delay(math.min(index, 12) * 0.03, function()
			if card.Parent then
				Tween(card, 0.35, { GroupTransparency = 0 })
				Tween(cs, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
		return card
	end

	local function BuildPager(total)
		for _, c in ipairs(pageBar:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		local order = 0
		local function Btn(text, page, active, enabled)
			order += 1
			local b = New("TextButton", { AutoButtonColor = false, Text = text, TextColor3 = active and Color3.new(1, 1, 1) or T.text, Font = Enum.Font.GothamBold, TextSize = 13, BackgroundColor3 = active and T.accent or T.field, LayoutOrder = order, Size = UDim2.fromOffset(30, 30), Parent = pageBar })
			Round(b, 8)
			if page and enabled ~= false then
				b.Activated:Connect(function() State.Page = page; Content.CanvasPosition = Vector2.zero; RefreshBrowser(true) end)
				if not active then Hover(b, b, T.field, T.cardHover) end
			else
				b.TextTransparency = (page == nil and not active) and 0.4 or 0
			end
		end
		Btn("‹", State.Page - 1, false, State.Page > 1)
		local last = 0
		for p = 1, total do
			if p == 1 or p == total or math.abs(p - State.Page) <= 1 then
				if last ~= 0 and p - last > 1 then Btn("…", nil, false) end
				Btn(tostring(p), p, p == State.Page)
				last = p
			end
		end
		Btn("›", State.Page + 1, false, State.Page < total)
	end

	RefreshBrowser = function(animate, keepPage)
		local list = Filtered()
		local total = math.max(1, math.ceil(#list / CFG.PageSize))
		State.Page = math.clamp(State.Page, 1, total)

		local n = 0
		for _ in pairs(Favs) do n += 1 end
		favCount.Text = tostring(n)

		if animate ~= false then
			for _, c in ipairs(Content:GetChildren()) do if not c:IsA("UIBase") or c:IsA("UIGridLayout") or c:IsA("UIListLayout") or c:IsA("UIPadding") then c:Destroy() end end
			local grid = State.Mode == "Grid"
			if grid then
				New("UIGridLayout", { CellSize = UDim2.fromOffset(176, 106), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })
			else
				New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Content })
			end
			New("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingTop = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), Parent = Content })
			local first = (State.Page - 1) * CFG.PageSize + 1
			for i = first, math.min(first + CFG.PageSize - 1, #list) do BuildCard(list[i], i - first + 1, grid) end
			emptyLbl.Visible = (#list == 0)
			local from = #list == 0 and 0 or first
			local to = math.min(first + CFG.PageSize - 1, #list)
			footerLbl.Text = string.format("Showing %d–%d of %d assets", from, to, #list)
			BuildPager(total)
		end
	end

	-- keep star in preview in sync when toggled from the grid
	do
		local oldOpen = OpenPreview
		OpenPreview = function(asset, tab)
			oldOpen(asset, tab)
			if Preview then Preview.RefreshFav = function() end end
		end
	end

	--==================================================================--
	--  DRAGGING (browser header)
	--==================================================================--
	do
		local handle = New("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(190, 0), Size = UDim2.fromOffset(450, 56), Parent = Win })
		local dragging, startMouse, startPos
		handle.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; startMouse = i.Position; startPos = Win.Position
				i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
			end
		end)
		conns[#conns + 1] = UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - startMouse
				Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
	end

	--==================================================================--
	--  UNLOAD / CLOSE
	--==================================================================--
	local unloaded = false
	local function Unload()
		if unloaded then return end
		unloaded = true
		pcall(DestroyPreview, true)
		pcall(ClosePopup)
		if Blur then pcall(function() Blur:Destroy() end) end
		pcall(function() Main:Destroy() end)
		pcall(function() Overlay:Destroy() end)
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		conns = {}
		if genv.JustXLibraryUnload == Unload then genv.JustXLibraryUnload = nil end
		if hooks and hooks.closed then pcall(hooks.closed) end
	end
	genv.JustXLibraryUnload = Unload

	closeMain.Activated:Connect(function()
		DestroyPreview(false)
		Tween(WinScale, 0.2, { Scale = State.Scale * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.22, Unload)
	end)

	--==================================================================--
	--  BOOT
	--==================================================================--
	StyleCats()
	StyleMode()
	RefreshBrowser(true)

	--==================================================================--
	--  HANDLE (управление из модуля)
	--==================================================================--
	local handle = { Unload = Unload }
	-- target: имя вкладки окна (Controllers / Info / Preview), имя или Id ассета, либо таблица ассета; nil = просто браузер
	function handle.Open(target)
		if target == nil or unloaded then return end
		local tab, asset
		if type(target) == "table" then
			asset = target
		else
			local ts = tostring(target):lower()
			for _, t in ipairs({ "Controllers", "Info", "Preview" }) do
				if ts == t:lower() then tab = t end
			end
			if not tab then
				for _, a in ipairs(ASSETS) do
					if a.Name == target or tostring(a.Id) == tostring(target) then asset = a; break end
				end
			else
				for _, a in ipairs(ASSETS) do
					if a.Name == State.Selected then asset = a; break end
				end
				asset = asset or ASSETS[1]
			end
		end
		if asset then
			State.Selected = asset.Name
			OpenPreview(asset, tab or "Controllers")
		end
	end
	return handle

end

return {
	new = function(bridge, popts)
		popts = popts or {}
		local obj = { alive = true }
		local handle
		local closedCbs = {}

		local function ensure()
			if obj.alive == false then return false end
			if handle then return true end
			local ok, res = pcall(Run, bridge, popts, {
				closed = function()
					handle = nil
					for _, cb in ipairs(closedCbs) do pcall(cb) end
				end,
			})
			if ok and type(res) == "table" then handle = res; return true end
			warn("[PreviewUI] could not build the window: " .. tostring(res))
			if bridge and bridge.notify then
				pcall(bridge.notify, { Title = "Preview UI", Desc = "Could not build the window: " .. tostring(res), Type = "Error", Duration = 8 })
			end
			return false
		end

		function obj:Open(target)
			if ensure() then handle.Open(target) end
			return self
		end
		function obj:Close()
			if handle then handle.Unload() end
			return self
		end
		function obj:IsOpen() return handle ~= nil end
		function obj:Toggle(target)
			if handle then handle.Unload() else self:Open(target) end
			return self
		end
		function obj:OnClosed(cb)
			if type(cb) == "function" then closedCbs[#closedCbs + 1] = cb end
			return self
		end
		function obj:GetTabs()
			return { { Name = "Controllers" }, { Name = "Info" }, { Name = "Preview" } }
		end
		function obj:ApplySettings() return self end -- Auto Rotate / Rotate Speed читаются из настроек хаба на лету
		function obj:Destroy()
			if handle then handle.Unload() end
			obj.alive = false
			if bridge and bridge.onDestroyed then pcall(bridge.onDestroyed, obj) end
		end

		if bridge and bridge.unloadHooks then
			table.insert(bridge.unloadHooks, function() obj:Destroy() end)
		end
		if popts.AutoOpen then obj:Open(popts.Target) end
		return obj
	end,
}
