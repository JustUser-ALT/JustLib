-- ══════════════════════════════════════════════════════════
--  JustLib v2.0 · Fixed & Grid-Only
-- ══════════════════════════════════════════════════════════
local JL = {}; JL.Flags = {}
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HTTP = game:GetService("HttpService")
local LP = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")
local RunSvc = game:GetService("RunService")

local function getContainer()
    local ok, res = pcall(function() return (gethui and gethui()) or CoreGui end)
    return (ok and res) or LP:WaitForChild("PlayerGui")
end

-- Стилистика и цвета (в стиле Minimal)
local C = {
    panel = Color3.fromRGB(17, 17, 23),
    pHdr = Color3.fromRGB(23, 23, 31),
    border = Color3.fromRGB(42, 42, 58),
    txt = Color3.fromRGB(222, 222, 235),
    dim = Color3.fromRGB(108, 108, 132),
    togOn = Color3.fromRGB(72, 198, 112),
    togOff = Color3.fromRGB(48, 48, 66),
    slTrack = Color3.fromRGB(36, 36, 50),
    btnBg = Color3.fromRGB(26, 26, 38),
    btnHov = Color3.fromRGB(40, 40, 56),
    sidebar = Color3.fromRGB(12, 12, 17),
    fpsGrn = Color3.fromRGB(72, 214, 92),
    input = Color3.fromRGB(20, 20, 30),
}

local ACCENTS = {
    Color3.fromRGB(148, 92, 255),
    Color3.fromRGB(82, 152, 255),
    Color3.fromRGB(72, 198, 138),
    Color3.fromRGB(255, 132, 72),
}
local _ai = 0
local function nxAc() _ai = _ai + 1; return ACCENTS[((_ai - 1) % #ACCENTS) + 1] end

local function tw(o, p, t, s, d)
    return TS:Create(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
end

local function corner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
end

local function stroke(col, t, p)
    local s = Instance.new("UIStroke")
    s.Color = col
    s.Thickness = t
    s.Parent = p
    return s
end

local function pad(l, r, t, b, p)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0, l); u.PaddingRight = UDim.new(0, r)
    u.PaddingTop = UDim.new(0, t); u.PaddingBottom = UDim.new(0, b)
    u.Parent = p
end

local function newTxt(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.Font or Enum.Font.Gotham
    l.TextSize = props.Size or 11
    l.TextColor3 = props.Color or C.txt
    l.Text = props.Text or ""
    l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.ZIndex = props.Z or 17
    if props.Wrap then l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.None end
    l.Size = props.Sz or UDim2.new(1, 0, 1, 0)
    l.Position = props.Pos or UDim2.new(0, 0, 0, 0)
    l.Parent = props.Parent
    return l
end

local function draggable(handle, frame)
    local down, moved, ds, sp = false, false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            down = true; moved = false; ds = Vector2.new(i.Position.X, i.Position.Y); sp = frame.Position
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if not down then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = Vector2.new(i.Position.X, i.Position.Y) - ds
        if d.Magnitude > 4 then moved = true end
        if moved then
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            down = false
        end
    end)
end

-- Создание корневого ScreenGui с DisplayOrder = 999999999
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "JustLib_UI"
MainGui.DisplayOrder = 999999999
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.Parent = getContainer()

-- Нотификации
shared._JLNotifs = shared._JLNotifs or {}
local activeNotifs = shared._JLNotifs
local function updNotifPos()
    for i, n in ipairs(activeNotifs) do
        if n and n.f then
            tw(n.f, {Position = UDim2.new(1, -220, 1, -70 - ((#activeNotifs - i) * 62))}, .3)
        end
    end
end

function JL:Notify(cfg)
    local title = cfg.Title or "JustLib"
    local desc = cfg.Desc or ""
    local dur = cfg.Duration or 3
    local typ = cfg.Type or "Info"
    local col = Color3.fromRGB(148, 92, 255)

    if typ == "Error" then col = Color3.fromRGB(255, 82, 82)
    elseif typ == "Success" then col = Color3.fromRGB(145, 255, 128)
    elseif typ == "Warn" then col = Color3.fromRGB(255, 225, 117) end

    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = C.panel
    f.Size = UDim2.new(0, 200, 0, 52)
    f.Position = UDim2.new(1, 20, 1, -70)
    f.ZIndex = 2000
    f.Parent = MainGui
    corner(8, f)
    stroke(C.border, 1, f)

    local bar = Instance.new("Frame")
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = col
    bar.Size = UDim2.new(0, 4, 1, -12)
    bar.Position = UDim2.new(0, 6, 0, 6)
    bar.ZIndex = 2001
    bar.Parent = f
    corner(2, bar)

    newTxt({Parent = f, Text = title, Font = Enum.Font.GothamBold, Size = 12, Color = C.txt, Sz = UDim2.new(1, -20, 0, 18), Pos = UDim2.new(0, 16, 0, 6), Z = 2001})
    newTxt({Parent = f, Text = desc, Size = 10, Color = C.dim, Sz = UDim2.new(1, -20, 0, 20), Pos = UDim2.new(0, 16, 0, 24), Z = 2001, Wrap = true})

    local nd = {f = f}
    table.insert(activeNotifs, nd)
    updNotifPos()

    task.delay(dur, function()
        for i, v in ipairs(activeNotifs) do
            if v == nd then table.remove(activeNotifs, i); break end
        end
        updNotifPos()
        tw(f, {Position = UDim2.new(1, 20, f.Position.Y.Scale, f.Position.Y.Offset)}, .3)
        task.wait(.3)
        f:Destroy()
    end)
end

-- Исправленный ColorPicker Modal
local function openColorPicker(currentColor, callback)
    local bd = Instance.new("Frame")
    bd.Size = UDim2.new(1, 0, 1, 0)
    bd.BackgroundColor3 = Color3.new(0, 0, 0)
    bd.BackgroundTransparency = 0.5
    bd.ZIndex = 3000
    bd.Parent = MainGui

    local h, s, v = Color3.toHSV(currentColor)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 220, 0, 220)
    card.Position = UDim2.new(0.5, -110, 0.5, -110)
    card.BackgroundColor3 = C.panel
    card.BorderSizePixel = 0
    card.ZIndex = 3001
    card.Parent = bd
    corner(10, card)
    stroke(C.border, 1, card)

    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 32)
    hdr.BackgroundColor3 = C.pHdr
    hdr.BorderSizePixel = 0
    hdr.ZIndex = 3002
    hdr.Parent = card
    corner(10, hdr)

    newTxt({Parent = hdr, Text = "Color Picker", Font = Enum.Font.GothamBold, Size = 12, Color = C.txt, Sz = UDim2.new(1, -40, 1, 0), Pos = UDim2.new(0, 10, 0, 0), Z = 3003})

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -26, 0.5, -10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(215, 70, 70)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.ZIndex = 3003
    closeBtn.Parent = hdr
    corner(5, closeBtn)

    closeBtn.MouseButton1Click:Connect(function() bd:Destroy() end)
    draggable(hdr, card)

    -- Фикс сплошного уголка (ровный превью)
    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 24, 0, 16)
    preview.Position = UDim2.new(1, -56, 0.5, -8)
    preview.BackgroundColor3 = currentColor
    preview.BorderSizePixel = 0
    preview.ZIndex = 3003
    preview.Parent = hdr
    corner(4, preview)

    local svBg = Instance.new("Frame")
    svBg.Size = UDim2.new(1, -20, 0, 120)
    svBg.Position = UDim2.new(0, 10, 0, 40)
    svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    svBg.BorderSizePixel = 0
    svBg.ZIndex = 3002
    svBg.Parent = card
    corner(6, svBg)

    local svSat = Instance.new("Frame")
    svSat.Size = UDim2.new(1, 0, 1, 0)
    svSat.BackgroundColor3 = Color3.new(1, 1, 1)
    svSat.BorderSizePixel = 0
    svSat.ZIndex = 3003
    svSat.Parent = svBg
    corner(6, svSat)

    local svSatG = Instance.new("UIGradient")
    svSatG.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    svSatG.Parent = svSat

    local svVal = Instance.new("Frame")
    svVal.Size = UDim2.new(1, 0, 1, 0)
    svVal.BackgroundColor3 = Color3.new(0, 0, 0)
    svVal.BorderSizePixel = 0
    svVal.ZIndex = 3004
    svVal.Parent = svBg
    corner(6, svVal)

    local svValG = Instance.new("UIGradient")
    svValG.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
    svValG.Rotation = 90
    svValG.Parent = svVal

    local svCursor = Instance.new("Frame")
    svCursor.Size = UDim2.new(0, 8, 0, 8)
    svCursor.BackgroundColor3 = Color3.new(1, 1, 1)
    svCursor.BorderSizePixel = 0
    svCursor.ZIndex = 3005
    svCursor.Parent = svBg
    corner(4, svCursor)

    local function updateCursor()
        svCursor.Position = UDim2.new(s, -4, 1 - v, -4)
        local c = Color3.fromHSV(h, s, v)
        preview.BackgroundColor3 = c
        if callback then callback(c) end
    end
    updateCursor()

    local svDragging = false
    local function updateSV(inp)
        local ap = svBg.AbsolutePosition
        local as = svBg.AbsoluteSize
        s = math.clamp((inp.Position.X - ap.X) / as.X, 0, 1)
        v = math.clamp(1 - (inp.Position.Y - ap.Y) / as.Y, 0, 1)
        updateCursor()
    end

    svBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            svDragging = true; updateSV(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if svDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            updateSV(i)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            svDragging = false
        end
    end)

    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.new(1, -20, 0, 12)
    hueBar.Position = UDim2.new(0, 10, 0, 170)
    hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
    hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 3002
    hueBar.Parent = card
    corner(4, hueBar)

    local hueG = Instance.new("UIGradient")
    hueG.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255,255,0)),
        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0,0,255)),
        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255,0,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
    })
    hueG.Parent = hueBar

    local hueDragging = false
    local function updateHue(inp)
        local ap = hueBar.AbsolutePosition
        local as = hueBar.AbsoluteSize
        h = math.clamp((inp.Position.X - ap.X) / as.X, 0, 1)
        svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        updateCursor()
    end

    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            hueDragging = true; updateHue(i)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if hueDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            updateHue(i)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            hueDragging = false
        end
    end)
end

-- Главная функция создания Окна / Hub
function JL:CreateWindow(titleText)
    local hubTitle = titleText or "JustLib"

    -- Основной фрейм приложения
    local app = Instance.new("Frame")
    app.Size = UDim2.new(0, 680, 0, 420)
    app.Position = UDim2.new(0.5, -340, 0.5, -210)
    app.BackgroundColor3 = C.panel
    app.BorderSizePixel = 0
    app.ZIndex = 100
    app.Parent = MainGui
    corner(10, app)
    stroke(C.border, 1, app)

    -- Шапка окна
    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 36)
    hdr.BackgroundColor3 = C.pHdr
    hdr.BorderSizePixel = 0
    hdr.ZIndex = 101
    hdr.Parent = app
    corner(10, hdr)
    draggable(hdr, app)

    newTxt({Parent = hdr, Text = hubTitle, Font = Enum.Font.GothamBold, Size = 13, Color = C.txt, Sz = UDim2.new(0, 200, 1, 0), Pos = UDim2.new(0, 14, 0, 0), Z = 102})

    -- FPS Индикатор
    local fpsL = newTxt({Parent = hdr, Text = "FPS: --", Font = Enum.Font.GothamBold, Size = 10, Color = C.fpsGrn, XAlign = Enum.TextXAlignment.Right, Sz = UDim2.new(0, 80, 1, 0), Pos = UDim2.new(1, -120, 0, 0), Z = 102})
    local lastT, frames = tick(), 0
    RunSvc.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastT >= 1 then
            fpsL.Text = "FPS: " .. frames
            frames = 0; lastT = now
        end
    end)

    -- Кнопка закрытия
    local closeB = Instance.new("TextButton")
    closeB.Size = UDim2.new(0, 22, 0, 22)
    closeB.Position = UDim2.new(1, -30, 0.5, -11)
    closeB.BackgroundColor3 = C.btnBg
    closeB.Text = "✕"
    closeB.Font = Enum.Font.GothamBold
    closeB.TextSize = 10
    closeB.TextColor3 = C.dim
    closeB.ZIndex = 102
    closeB.Parent = hdr
    corner(5, closeB)

    -- БЕЙДЖ (Для скрыть/показать UI)
    local BPOS = { top = UDim2.new(0.5, -60, 0, 10), center = UDim2.new(0.5, -60, 0.5, -16) }
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 120, 0, 32)
    badge.Position = BPOS.top
    badge.BackgroundColor3 = C.pHdr
    badge.BorderSizePixel = 0
    badge.ZIndex = 1000
    badge.Visible = false
    badge.Parent = MainGui
    corner(8, badge)
    stroke(C.border, 1, badge)
    draggable(badge, badge)

    local bTxt = newTxt({Parent = badge, Text = hubTitle, Font = Enum.Font.GothamBold, Size = 11, Color = C.txt, XAlign = Enum.TextXAlignment.Center, Z = 1001})

    local uiVisible = true
    local function toggleUI()
        uiVisible = not uiVisible
        app.Visible = uiVisible
        badge.Visible = not uiVisible
    end

    closeB.MouseButton1Click:Connect(toggleUI)
    badge.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            toggleUI()
        end
    end)

    -- Сайдбар слева (Список табов)
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 140, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 101
    sidebar.Parent = app
    corner(10, sidebar)

    local tabList = Instance.new("UIListLayout")
    tabList.FillDirection = Enum.FillDirection.Vertical
    tabList.Padding = UDim.new(0, 4)
    tabList.SortOrder = Enum.SortOrder.LayoutOrder
    tabList.Parent = sidebar
    pad(6, 6, 8, 8, sidebar)

    -- Контейнер для отображения контента табов
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, -140, 1, -36)
    tabContainer.Position = UDim2.new(0, 140, 0, 36)
    tabContainer.BackgroundTransparency = 1
    tabContainer.ZIndex = 101
    tabContainer.Parent = app

    local tabs = {}
    local activeTab = nil

    local HubObj = {}

    -- Создание Таба (Вкладки)
    function HubObj:CreateTab(tabName)
        local tabBtn = Instance.new("TextButton")
        tabBtn.Size = UDim2.new(1, 0, 0, 28)
        tabBtn.BackgroundColor3 = C.btnBg
        tabBtn.BackgroundTransparency = 1
        tabBtn.Text = tabName or "Tab"
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 11
        tabBtn.TextColor3 = C.dim
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        tabBtn.ZIndex = 102
        tabBtn.Parent = sidebar
        corner(6, tabBtn)
        pad(10, 0, 0, 0, tabBtn)

        -- 3-КОЛОНОЧНЫЙ ГРИД (Левая, Центральная, Правая)
        local gridFrame = Instance.new("Frame")
        gridFrame.Size = UDim2.new(1, 0, 1, 0)
        gridFrame.BackgroundTransparency = 1
        gridFrame.Visible = false
        gridFrame.ZIndex = 102
        gridFrame.Parent = tabContainer

        local cols = {}
        for i = 1, 3 do
            local colScroll = Instance.new("ScrollingFrame")
            colScroll.Size = UDim2.new(0.33, -8, 1, -12)
            colScroll.Position = UDim2.new((i - 1) * 0.33, 4, 0, 6)
            colScroll.BackgroundTransparency = 1
            colScroll.BorderSizePixel = 0
            colScroll.ScrollBarThickness = 2
            colScroll.ScrollBarImageColor3 = C.dim
            colScroll.ZIndex = 103
            colScroll.Parent = gridFrame

            local colList = Instance.new("UIListLayout")
            colList.FillDirection = Enum.FillDirection.Vertical
            colList.Padding = UDim.new(0, 8)
            colList.SortOrder = Enum.SortOrder.LayoutOrder
            colList.Parent = colScroll

            colList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                colScroll.CanvasSize = UDim2.new(0, 0, 0, colList.AbsoluteContentSize.Y + 12)
            end)

            cols[i] = colScroll
        end

        local TabObj = {}

        -- Создание Секции в одной из 3 колонок (1 = Left, 2 = Center, 3 = Right)
        function TabObj:CreateSection(secTitle, colIndex, colorAccent)
            colIndex = math.clamp(colIndex or 1, 1, 3)
            colorAccent = colorAccent or nxAc()
            local targetCol = cols[colIndex]

            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(1, -4, 0, 34)
            panel.BackgroundColor3 = C.panel
            panel.BorderSizePixel = 0
            panel.ZIndex = 104
            panel.ClipsDescendants = true
            panel.Parent = targetCol
            corner(8, panel)
            stroke(C.border, 1, panel)

            local sHdr = Instance.new("Frame")
            sHdr.Size = UDim2.new(1, 0, 0, 32)
            sHdr.BackgroundColor3 = C.pHdr
            sHdr.BorderSizePixel = 0
            sHdr.ZIndex = 105
            sHdr.Parent = panel
            corner(8, sHdr)

            local ast = Instance.new("Frame")
            ast.Size = UDim2.new(0, 3, 0, 14)
            ast.Position = UDim2.new(0, 8, 0.5, -7)
            ast.BackgroundColor3 = colorAccent
            ast.BorderSizePixel = 0
            ast.ZIndex = 106
            ast.Parent = sHdr
            corner(2, ast)

            newTxt({Parent = sHdr, Text = secTitle, Font = Enum.Font.GothamBold, Size = 11, Color = C.txt, Sz = UDim2.new(1, -30, 1, 0), Pos = UDim2.new(0, 18, 0, 0), Z = 106})

            local content = Instance.new("Frame")
            content.Size = UDim2.new(1, -12, 0, 0)
            content.Position = UDim2.new(0, 6, 0, 36)
            content.BackgroundTransparency = 1
            content.ZIndex = 105
            content.Parent = panel

            local cList = Instance.new("UIListLayout")
            cList.FillDirection = Enum.FillDirection.Vertical
            cList.Padding = UDim.new(0, 6)
            cList.SortOrder = Enum.SortOrder.LayoutOrder
            cList.Parent = content
            pad(0, 0, 0, 6, content)

            local function resize()
                local h = cList.AbsoluteContentSize.Y + 12
                content.Size = UDim2.new(1, -12, 0, h - 6)
                panel.Size = UDim2.new(1, -4, 0, 34 + h)
            end

            cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

            local Sec = {}
            local order = 0

            local function newRow(h)
                order = order + 1
                local r = Instance.new("Frame")
                r.Size = UDim2.new(1, 0, 0, h)
                r.BackgroundTransparency = 1
                r.ZIndex = 106
                r.LayoutOrder = order
                r.Parent = content
                return r
            end

            function Sec:Button(text, callback)
                local row = newRow(26)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = C.btnBg
                btn.Text = text or "Button"
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 10
                btn.TextColor3 = C.txt
                btn.ZIndex = 107
                btn.Parent = row
                corner(6, btn)
                stroke(C.border, 1, btn)

                btn.MouseButton1Click:Connect(function()
                    tw(btn, {BackgroundColor3 = colorAccent}, .08)
                    task.delay(.12, function() tw(btn, {BackgroundColor3 = C.btnBg}, .1) end)
                    if callback then pcall(callback) end
                end)
            end

            function Sec:Toggle(text, default, callback)
                local row = newRow(24)
                newTxt({Parent = row, Text = text or "Toggle", Size = 10, Color = C.dim, Sz = UDim2.new(1, -36, 1, 0), Z = 107})

                local tog = Instance.new("TextButton")
                tog.Size = UDim2.new(0, 30, 0, 16)
                tog.Position = UDim2.new(1, -30, 0.5, -8)
                tog.BackgroundColor3 = default and C.togOn or C.togOff
                tog.Text = ""
                tog.ZIndex = 107
                tog.Parent = row
                corner(8, tog)

                local kn = Instance.new("Frame")
                kn.Size = UDim2.new(0, 12, 0, 12)
                kn.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
                kn.BackgroundColor3 = Color3.new(1, 1, 1)
                kn.BorderSizePixel = 0
                kn.ZIndex = 108
                kn.Parent = tog
                corner(6, kn)

                local state = default or false
                tog.MouseButton1Click:Connect(function()
                    state = not state
                    tw(tog, {BackgroundColor3 = state and C.togOn or C.togOff}, .15)
                    tw(kn, {Position = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}, .15)
                    if callback then pcall(callback, state) end
                end)
            end

            function Sec:Slider(text, min, max, default, callback)
                local row = newRow(36)
                newTxt({Parent = row, Text = text or "Slider", Size = 10, Color = C.dim, Sz = UDim2.new(1, -40, 0, 14), Z = 107})
                local valLbl = newTxt({Parent = row, Text = tostring(default or min), Font = Enum.Font.GothamBold, Size = 10, Color = C.txt, XAlign = Enum.TextXAlignment.Right, Sz = UDim2.new(0, 40, 0, 14), Pos = UDim2.new(1, -40, 0, 0), Z = 107})

                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, 0, 0, 6)
                track.Position = UDim2.new(0, 0, 0, 22)
                track.BackgroundColor3 = C.slTrack
                track.BorderSizePixel = 0
                track.ZIndex = 107
                track.Parent = row
                corner(3, track)

                local pct = math.clamp(((default or min) - min) / (max - min), 0, 1)
                local fill = Instance.new("Frame")
                fill.Size = UDim2.new(pct, 0, 1, 0)
                fill.BackgroundColor3 = colorAccent
                fill.BorderSizePixel = 0
                fill.ZIndex = 108
                fill.Parent = track
                corner(3, fill)

                local sliding = false
                local function update(inp)
                    local p = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(p, 0, 1, 0)
                    local v = math.round(min + (max - min) * p)
                    valLbl.Text = tostring(v)
                    if callback then pcall(callback, v) end
                end

                track.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = true; update(i)
                    end
                end)
                UIS.InputChanged:Connect(function(i)
                    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        update(i)
                    end
                end)
                UIS.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
            end

            -- Исправленный Dropdown (выравнивание по центру, не теряется текст)
            function Sec:Dropdown(text, items, default, callback)
                local row = newRow(26)
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 1, 0)
                btn.BackgroundColor3 = C.btnBg
                btn.Text = (text or "Dropdown") .. ": " .. tostring(default or items[1] or "")
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 10
                btn.TextColor3 = C.txt
                btn.ZIndex = 107
                btn.Parent = row
                corner(6, btn)
                stroke(C.border, 1, btn)

                local curr = default or items[1]
                btn.MouseButton1Click:Connect(function()
                    local idx = table.find(items, curr) or 1
                    idx = (idx % #items) + 1
                    curr = items[idx]
                    btn.Text = (text or "Dropdown") .. ": " .. tostring(curr)
                    if callback then pcall(callback, curr) end
                end)
            end

            function Sec:Input(text, placeholder, callback)
                local row = newRow(42)
                newTxt({Parent = row, Text = text or "Input", Size = 10, Color = C.dim, Sz = UDim2.new(1, 0, 0, 14), Z = 107})

                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 0, 22)
                box.Position = UDim2.new(0, 0, 0, 18)
                box.BackgroundColor3 = C.input
                box.PlaceholderText = placeholder or "Type..."
                box.Text = ""
                box.Font = Enum.Font.Gotham
                box.TextSize = 10
                box.TextColor3 = C.txt
                box.ZIndex = 107
                box.Parent = row
                corner(6, box)
                stroke(C.border, 1, box)

                box.FocusLost:Connect(function(enter)
                    if enter and callback then pcall(callback, box.Text) end
                end)
            end

            function Sec:ColorPicker(text, defaultColor, callback)
                local row = newRow(24)
                newTxt({Parent = row, Text = text or "Color", Size = 10, Color = C.dim, Sz = UDim2.new(1, -30, 1, 0), Z = 107})

                local p = Instance.new("TextButton")
                p.Size = UDim2.new(0, 24, 0, 16)
                p.Position = UDim2.new(1, -24, 0.5, -8)
                p.BackgroundColor3 = defaultColor or Color3.new(1, 1, 1)
                p.Text = ""
                p.ZIndex = 107
                p.Parent = row
                corner(4, p)
                stroke(C.border, 1, p)

                p.MouseButton1Click:Connect(function()
                    openColorPicker(p.BackgroundColor3, function(c)
                        p.BackgroundColor3 = c
                        if callback then pcall(callback, c) end
                    end)
                end)
            end

            return Sec
        end

        -- Переключение табов
        local function selectTab()
            if activeTab then
                activeTab.btn.BackgroundTransparency = 1
                activeTab.btn.TextColor3 = C.dim
                activeTab.grid.Visible = false
            end
            tabBtn.BackgroundTransparency = 0
            tabBtn.TextColor3 = C.txt
            gridFrame.Visible = true
            activeTab = {btn = tabBtn, grid = gridFrame}
        end

        tabBtn.MouseButton1Click:Connect(selectTab)
        if #tabs == 0 then selectTab() end

        table.insert(tabs, TabObj)
        return TabObj
    end

    return HubObj
end

return JL
