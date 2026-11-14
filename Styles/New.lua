--[[
	JustLib style: "New"
	Верхняя панель, широкий сайдбар с подписями, карточки-секции с плиткой иконки,
	градиентные кнопки и переключатели, слайдер в одну строку.

	Файл возвращает таблицу: токены (числа/флаги) + хуки (функции для структурных отличий).
	Подключение:
		JL:RegisterStyle("New", loadstring(game:HttpGet(URL .. "/Styles/New.lua"))())
	или через опции окна:
		JL:Window({ Style = "New", StyleBase = "https://raw.githubusercontent.com/<user>/<repo>/main/Styles" })
]]

local function kp(t, c) return ColorSequenceKeypoint.new(t, c) end

return {
	name = "New",
	defaultTheme = "Violet", -- применяется, только если пользователь сам не выбирал тему

	----------------------------------------------------------------
	-- Окно
	----------------------------------------------------------------
	forceLabels = true,   -- сайдбар всегда с подписями
	sbw = 176,            -- ширина сайдбара
	gap = 10,             -- расстояние сайдбар -> контент
	colGap = 10,          -- расстояние между колонками секций
	padX = 12,            -- отступ окна по бокам
	padB = 12,            -- отступ окна снизу
	topH = 62,            -- высота верхней панели
	contentTop = 0,       -- место под кнопку поиска в контенте больше не нужно (поиск живёт в верхней панели)
	cardCorner = 16,      -- скругление карточки контента

	----------------------------------------------------------------
	-- Сайдбар и вкладки
	----------------------------------------------------------------
	sbFull = true,        -- сайдбар на всю высоту окна
	sbCorner = 16,
	sbTransp = 0.3,
	sbStrokeT = 0.65,
	sbGap = 4,
	sbFooterH = 76,       -- место под карточку внизу сайдбара
	tabRow = true,        -- вкладка = строка: иконка слева, подпись справа
	tabH = 40,
	tabInset = 20,
	tabCorner = 12,
	tabIdleT = 1,         -- неактивная вкладка прозрачная
	tabActiveT = 0,
	tabIndPos = UDim2.new(0, 2, 0.5, -7),
	tabActiveBgFn = function(C, ACC) return ACC[1]:Lerp(C.panel, 0.6) end,
	tabActiveTextIsTxt = true,

	----------------------------------------------------------------
	-- Секции
	----------------------------------------------------------------
	uniformAccent = true, -- один акцент на все секции (а не по кругу)
	secHH = 54,
	secPad = 12,
	secGap = 8,
	secCorner = 16,
	secStrokeT = 0.4,
	-- Адаптивные колонки: мелкий экран 2, средний 3, большой 4.
	-- Считается по «эффективной» ширине экрана = ширина / масштаб UI, поэтому при меньшем масштабе влезает больше колонок.
	-- Окно подбирает ширину под число колонок (opts.FixedWidth = true отключает это и берёт opts.Width).
	autoColumns = { bp1 = 1050, bp2 = 1350, small = 2, medium = 3, large = 4 },
	colTarget = 300,      -- желаемая ширина одной колонки
	minColW = 250,        -- минимальная ширина колонки: окно сворачивает число колонок, а не сжимает секции
	sliderInlineMin = 260, -- слайдер в одну строку только если секция не уже этого; иначе стопкой внутри карточки
	sliderCard = true,

	----------------------------------------------------------------
	-- Контролы
	----------------------------------------------------------------
	rowMin = 40,
	ctrlCorner = 10,
	swW = 40, swH = 22, swKnob = 16, swGradient = true,
	trackCorner = 3, knob = 16, sliderGradient = true, sliderInline = true,
	btnFill = true, btnGradient = true, btnChevron = true,
	cpW = 24, cpH = 24, cpCorner = 12, cpChev = true,
	inputLabeled = true,  -- Input: название слева, поле справа (как Textbox на макете)
	chipW = 84, chipH = 28, chipCorner = 8, -- плашка клавиши в Keybind
	ddCorner = 12, optMin = 34, optCorner = 9, ddTint = true, -- Dropdown: список, высота пунктов, подсветка выбранных

	----------------------------------------------------------------
	-- Хуки
	----------------------------------------------------------------

	----------------------------------------------------------------
	-- Settings, Home, окна Info
	----------------------------------------------------------------
	setCorner = 16, setNavH = 38, setNavCorner = 11, setNavActiveT = 0.72,
	homeCorner = 16,
	metaCorner = 16, capsuleCorner = 8,

	-- Баннер Home: логотип, название, подпись, плашка версии, диагональные полосы и блик
	homeHero = function(parent, info, u)
		local C, ACC = u.C, u.ACC
		local TweenService = game:GetService("TweenService")

		local hero = Instance.new("Frame")
		hero.Name = "JLHomeHero"
		hero.Size = UDim2.new(1, 0, 0, 108)
		hero.LayoutOrder = info.order
		hero.BackgroundColor3 = Color3.new(1, 1, 1)
		hero.BorderSizePixel = 0
		hero.ClipsDescendants = true
		hero.Parent = parent
		u.corner(16, hero)

		local heroStroke = u.stroke(Color3.new(1, 1, 1), 1.5, hero)
		local strokeG = Instance.new("UIGradient")
		strokeG.Parent = heroStroke
		local fillG = Instance.new("UIGradient")
		fillG.Rotation = 15
		fillG.Parent = hero
		u.bind(function() -- цвета следуют за темой
			fillG.Color = ColorSequence.new(C.panel:Lerp(ACC[1], 0.32), C.panel:Lerp(ACC[1], 0.06))
			strokeG.Color = ColorSequence.new(ACC[1], ACC[2] or ACC[1])
		end)

		for i = 1, 2 do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Size = UDim2.new(0, 34 - i * 10, 0, 280)
			bar.Position = UDim2.new(0.58 + i * 0.1, 0, 0.5, 0)
			bar.Rotation = 24
			bar.BackgroundColor3 = ACC[1]
			bar.BackgroundTransparency = 0.8 + i * 0.05
			bar.BorderSizePixel = 0
			bar.ZIndex = 2
			bar.Parent = hero
		end

		local shine = Instance.new("Frame")
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Size = UDim2.new(0, 70, 0, 280)
		shine.Position = UDim2.new(-0.2, 0, 0.5, 0)
		shine.Rotation = 24
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.BorderSizePixel = 0
		shine.ZIndex = 3
		shine.Parent = hero
		local shineG = Instance.new("UIGradient")
		shineG.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1),
		})
		shineG.Parent = shine
		TweenService:Create(shine, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 3),
			{Position = UDim2.new(1.2, 0, 0.5, 0)}):Play()

		local x = 22
		if info.Icon then
			local ic = u.mkIcon(hero, info.Icon, 56, 6)
			ic.Position = UDim2.new(0, 18, 0.5, -28)
			ic.Size = UDim2.new(0, 56, 0, 56)
			x = 90
		end
		local hasTag = info.Tagline and info.Tagline ~= ""
		u.newTxt({Parent = hero, Text = tostring(info.Title), Font = u.GB, Size = 22,
			Sz = UDim2.new(1, -(x + 130), 0, 28), Pos = UDim2.new(0, x, 0.5, hasTag and -28 or -14), Z = 6})
		if hasTag then
			u.newTxt({Parent = hero, Text = tostring(info.Tagline), Font = u.GM, Size = 12, Color = C.dim,
				Sz = UDim2.new(1, -(x + 130), 0, 16), Pos = UDim2.new(0, x, 0.5, 4), Z = 6})
		end

		local pill = Instance.new("Frame")
		pill.AnchorPoint = Vector2.new(1, 0.5)
		pill.Size = UDim2.new(0, 96, 0, 28)
		pill.Position = UDim2.new(1, -16, 0.5, 0)
		pill.BackgroundColor3 = C.badge
		pill.BackgroundTransparency = 0.2
		pill.BorderSizePixel = 0
		pill.ZIndex = 6
		pill.Parent = hero
		u.corner(14, pill)
		local ps = u.stroke(C.border, 1, pill)
		ps.Transparency = 0.3
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 8, 0, 8)
		dot.Position = UDim2.new(0, 12, 0.5, -4)
		dot.BackgroundColor3 = C.fpsGrn
		dot.BorderSizePixel = 0
		dot.ZIndex = 7
		dot.Parent = pill
		u.corner(4, dot)
		u.newTxt({Parent = pill, Text = "v" .. tostring(info.Version or ""), Font = u.GB, Size = 12,
			Sz = UDim2.new(1, -30, 1, 0), Pos = UDim2.new(0, 26, 0, 0), Z = 7})

		return hero
	end,

	-- Кнопка поиска: справа в верхней панели (слева от «свернуть» и «закрыть»)
	searchPos = function(i)
		return UDim2.new(0, i.WW - i.OX - 124, 0, math.floor((i.OY - 30) / 2))
	end,

	-- Фон окна: тёмная карточка с неоновой рамкой, которая медленно вращается
	windowCard = function(ctx, u)
		local C, ACC = u.C, u.ACC
		local card = Instance.new("Frame")
		card.Name = "JLWindowCard"
		card.Size = UDim2.new(1, 0, 1, 0)
		card.BackgroundColor3 = C.backdrop
		card.BorderSizePixel = 0
		card.ZIndex = -1
		card.Parent = ctx.win
		u.corner(22, card)

		local fillG = Instance.new("UIGradient")
		fillG.Rotation = 90
		fillG.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 196, 222))
		fillG.Parent = card

		local line = u.stroke(Color3.new(1, 1, 1), 2, card)
		local glow = u.stroke(Color3.new(1, 1, 1), 7, card)
		glow.Transparency = 0.88
		local g1, g2 = Instance.new("UIGradient"), Instance.new("UIGradient")
		g1.Parent = line
		g2.Parent = glow

		u.bind(function()
			local seq = ColorSequence.new({
				kp(0, ACC[2] or ACC[1]),
				kp(0.5, ACC[1]),
				kp(1, ACC[4] or ACC[1]),
			})
			g1.Color = seq
			g2.Color = seq
		end)
		u.connect(u.RunService.Heartbeat, function(dt)
			local r = (g1.Rotation + dt * 35) % 360
			g1.Rotation = r
			g2.Rotation = r
		end)
	end,

	-- Верхняя панель: логотип, название, подпись, свернуть и закрыть. За панель можно двигать окно.
	topBar = function(ctx, u)
		local C = u.C
		local bar = Instance.new("Frame")
		bar.Name = "JLTopBar"
		bar.Size = UDim2.new(1, 0, 0, ctx.OY)
		bar.BackgroundTransparency = 1
		bar.ZIndex = 30
		bar.Parent = ctx.win

		local x = ctx.OX + 10
		if ctx.Icon then
			local ic = u.mkIcon(bar, ctx.Icon, 30, 31)
			ic.Position = UDim2.new(0, x, 0.5, -15)
			ic.Size = UDim2.new(0, 30, 0, 30)
			x = x + 42
		end
		local hasTag = ctx.Tagline and ctx.Tagline ~= ""
		u.newTxt({Parent = bar, Text = ctx.Title, Font = u.GB, Size = 18, Sz = UDim2.new(0, 320, 0, 22),
			Pos = UDim2.new(0, x, 0.5, hasTag and -20 or -11), Z = 31})
		if hasTag then
			u.newTxt({Parent = bar, Text = ctx.Tagline, Font = u.GM, Size = 11, Color = C.dim,
				Sz = UDim2.new(0, 320, 0, 16), Pos = UDim2.new(0, x, 0.5, 2), Z = 31})
		end

		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, -2 * ctx.OX, 0, 1)
		sep.Position = UDim2.new(0, ctx.OX, 0, ctx.OY - 1)
		sep.BackgroundColor3 = C.divLine
		sep.BackgroundTransparency = 0.5
		sep.BorderSizePixel = 0
		sep.ZIndex = 30
		sep.Parent = ctx.win

		local function mk(kind, rightOff, onClick, danger)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 36, 0, 30)
			b.Position = UDim2.new(0, ctx.WW - ctx.OX - rightOff, 0, math.floor((ctx.OY - 30) / 2))
			b.BackgroundColor3 = C.btnBg
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.Text = ""
			b.ZIndex = 32
			b.Parent = ctx.win
			u.corner(9, b)
			u.stroke(C.border, 1, b)
			-- значок рисуется рамками, а не символом шрифта: на части устройств «✕» и «—» отображаются квадратиками
			local function bar(w, rot)
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.new(0.5, 0, 0.5, 0)
				f.Size = UDim2.new(0, w, 0, 2)
				f.Rotation = rot
				f.BackgroundColor3 = C.txt
				f.BorderSizePixel = 0
				f.ZIndex = 33
				f.Parent = b
				u.corner(1, f)
			end
			if kind == "min" then bar(12, 0) else bar(15, 45); bar(15, -45) end
			b.MouseEnter:Connect(function()
				if u.touchLast() then return end
				u.tw(b, {BackgroundColor3 = danger and C.danger or C.btnHov}, 0.1)
			end)
			b.MouseLeave:Connect(function() u.tw(b, {BackgroundColor3 = C.btnBg}, 0.1) end)
			b.MouseButton1Click:Connect(onClick)
		end
		mk("min", 80, ctx.Close)
		mk("close", 36, ctx.Unload, true)

		u.draggable(bar, ctx.win)
	end,

	-- Карточка внизу сайдбара: название, версия, подпись
	sbFooter = function(frame, info, u)
		local C = u.C
		local hasFooter = info.Footer and info.Footer ~= ""
		local card = Instance.new("Frame")
		card.Name = "JLSidebarFooter"
		card.Size = UDim2.new(1, -16, 0, hasFooter and 62 or 48)
		card.AnchorPoint = Vector2.new(0.5, 1)
		card.Position = UDim2.new(0.5, 0, 1, -8)
		card.BackgroundColor3 = C.btnBg
		card.BackgroundTransparency = 0.2
		card.BorderSizePixel = 0
		card.Parent = frame
		u.corner(12, card)
		local st = u.stroke(C.border, 1, card)
		st.Transparency = 0.45
		u.newTxt({Parent = card, Text = tostring(info.Title or "JustLib"), Font = u.GB, Size = 12,
			Sz = UDim2.new(1, -20, 0, 18), Pos = UDim2.new(0, 10, 0, 8), Z = 5})
		u.newTxt({Parent = card, Text = "v" .. tostring(info.Version or ""), Font = u.GM, Size = 11, Color = C.dim,
			Sz = UDim2.new(1, -20, 0, 14), Pos = UDim2.new(0, 10, 0, 26), Z = 5})
		if hasFooter then
			u.newTxt({Parent = card, Text = tostring(info.Footer), Font = u.GM, Size = 10, Color = C.dim,
				Sz = UDim2.new(1, -20, 0, 14), Pos = UDim2.new(0, 10, 0, 43), Z = 5})
		end
	end,

	-- Заголовок секции: плитка с иконкой, название, подзаголовок (so.Subtitle), стрелка сворачивания
	sectionHeader = function(ctx, u)
		local C = u.C
		local panel, HH, ac, so = ctx.panel, ctx.HH, ctx.ac, ctx.so or {}

		local hdr = Instance.new("Frame")
		hdr.Size = UDim2.new(1, 0, 0, HH)
		hdr.BackgroundTransparency = 1
		hdr.BorderSizePixel = 0
		hdr.Parent = panel
		local hfix = Instance.new("Frame") -- заглушка: библиотека переключает ей Visible
		hfix.Size = UDim2.new(0, 0, 0, 0)
		hfix.BackgroundTransparency = 1
		hfix.Parent = hdr

		local tile = Instance.new("Frame")
		tile.Size = UDim2.new(0, 34, 0, 34)
		tile.Position = UDim2.new(0, 12, 0.5, -17)
		tile.BackgroundColor3 = C.btnBg
		tile.BorderSizePixel = 0
		tile.ZIndex = 3
		tile.Parent = hdr
		u.corner(10, tile)
		local ts = u.stroke(C.border, 1, tile)
		ts.Transparency = 0.5
		if so.Icon then
			local ic = u.mkIcon(tile, so.Icon, 18, 4)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.new(0.5, 0, 0.5, 0)
			ic.Size = UDim2.new(0, 18, 0, 18)
			if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
		else
			u.newTxt({Parent = tile, Text = string.upper(string.sub(tostring(ctx.title or "?"), 1, 1)), Font = u.GB, Size = 15,
				Color = ac, XAlign = Enum.TextXAlignment.Center, Z = 4})
		end

		local sub = so.Subtitle or so.Description
		u.newTxt({Parent = hdr, Text = tostring(ctx.title or "Section"), Font = u.GB, Size = 14,
			Sz = UDim2.new(1, -108, 0, 18), Pos = UDim2.new(0, 56, 0, sub and 9 or math.floor((HH - 18) / 2)), Z = 3})
		if sub then
			u.newTxt({Parent = hdr, Text = tostring(sub), Font = u.GM, Size = 11, Color = C.dim,
				Sz = UDim2.new(1, -108, 0, 14), Pos = UDim2.new(0, 56, 0, 28), Z = 3})
		end

		local chev = Instance.new("Frame")
		chev.Size = UDim2.new(0, 28, 0, 28)
		chev.Position = UDim2.new(1, -40, 0.5, -14)
		chev.BackgroundColor3 = C.btnBg
		chev.BorderSizePixel = 0
		chev.ZIndex = 3
		chev.Parent = hdr
		u.corner(9, chev)
		local arrow = u.newTxt({Parent = chev, Text = "▼", Font = u.GB, Size = 9, Color = C.dim,
			XAlign = Enum.TextXAlignment.Center, Z = 4})

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.ZIndex = 5
		btn.Parent = hdr
		if ctx.attachTip and so.Tooltip then ctx.attachTip(hdr, so.Tooltip) end

		local hline = Instance.new("Frame")
		hline.Size = UDim2.new(1, -24, 0, 1)
		hline.Position = UDim2.new(0, 12, 0, HH)
		hline.BackgroundColor3 = C.divLine
		hline.BackgroundTransparency = 0.5
		hline.BorderSizePixel = 0
		hline.Parent = panel

		return {hdr = hdr, hfix = hfix, arrow = arrow, btn = btn, hline = hline}
	end,

	-- Лёгкий диагональный градиент на карточке секции
	decoratePanel = function(panel, ac, u)
		local g = Instance.new("UIGradient")
		g.Rotation = 125
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 198, 228))
		g.Parent = panel
	end,
}
