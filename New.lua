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

	----------------------------------------------------------------
	-- Хуки
	----------------------------------------------------------------

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

		local function mk(glyph, rightOff, onClick, danger)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 36, 0, 30)
			b.Position = UDim2.new(0, ctx.WW - ctx.OX - rightOff, 0, math.floor((ctx.OY - 30) / 2))
			b.BackgroundColor3 = C.btnBg
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.Text = glyph
			b.Font = u.GB
			b.TextSize = 15
			b.TextColor3 = C.txt
			b.ZIndex = 32
			b.Parent = ctx.win
			u.corner(9, b)
			u.stroke(C.border, 1, b)
			b.MouseEnter:Connect(function()
				if u.touchLast() then return end
				u.tw(b, {BackgroundColor3 = danger and C.danger or C.btnHov}, 0.1)
			end)
			b.MouseLeave:Connect(function() u.tw(b, {BackgroundColor3 = C.btnBg}, 0.1) end)
			b.MouseButton1Click:Connect(onClick)
		end
		mk("—", 80, ctx.Close)
		mk("✕", 36, ctx.Unload, true)

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
