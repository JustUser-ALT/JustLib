local JL = {}; JL.Flags = {}
local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HTTP = game:GetService("HttpService")
local LP = game:GetService("Players").LocalPlayer
local CoreGui = game:GetService("CoreGui")

local function getContainer()
    local ok, res = pcall(function()
        return (gethui and gethui()) or CoreGui
    end)
    return (ok and res) or LP:WaitForChild("PlayerGui")
end

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
    TS:Create(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
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

-- ScreenGui с максимальным приоритетом
local MainGui = Instance.new("ScreenGui")
MainGui.Name = "JustXHub_UI"
MainGui.DisplayOrder = 999999999
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.Parent = getContainer()

-- Notifications
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
    local title = cfg.Title or "JustX Hub"
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
    f.ZIndex = 1000
    f.Parent = MainGui
    corner(8, f)
    stroke(C.border, 1, f)

    local bar = Instance.new("Frame")
    bar.BorderSizePixel = 0
    bar.BackgroundColor3 = col
    bar.Size = UDim2.new(0, 4, 1, -12)
    bar.Position = UDim2.new(0, 6, 0, 6)
    bar.ZIndex = 1001
    bar.Parent = f
    corner(2, bar)

    newTxt({Parent = f, Text = title, Font = Enum.Font.GothamBold, Size = 12, Color = C.txt, Sz = UDim2.new(1, -20, 0, 18), Pos = UDim2.new(0, 16, 0, 6), Z = 1001})
    newTxt({Parent = f, Text = desc, Size = 10, Color = C.dim, Sz = UDim2.new(1, -20, 0, 20), Pos = UDim2.new(0, 16, 0, 24), Z = 1001, Wrap = true})

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

-- ColorPicker Modal
local function openColorPicker(currentColor, callback)
    local bd = Instance.new("Frame")
    bd.Size = UDim2.new(1, 0, 1, 0)
    bd.BackgroundColor3 = Color3.new(0, 0, 0)
    bd.BackgroundTransparency = 0.5
    bd.ZIndex = 2000
    bd.Parent = MainGui

    local h, s, v = Color3.toHSV(currentColor)

    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 220, 0, 220)
    card.Position = UDim2.new(0.5, -110, 0.5, -110)
    card.BackgroundColor3 = C.panel
    card.BorderSizePixel = 0
    card.ZIndex = 2001
    card.Parent = bd
    corner(10, card)
    stroke(C.border, 1, card)

    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 32)
    hdr.BackgroundColor3 = C.pHdr
    hdr.BorderSizePixel = 0
    hdr.ZIndex = 2002
    hdr.Parent = card
    corner(10, hdr)

    newTxt({Parent = hdr, Text = "Color Picker", Font = Enum.Font.GothamBold, Size = 12, Color = C.txt, Sz = UDim2.new(1, -40, 1, 0), Pos = UDim2.new(0, 10, 0, 0), Z = 2003})
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -26, 0.5, -10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(215, 70, 70)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.ZIndex = 2003
    closeBtn.Parent = hdr
    corner(5, closeBtn)

    closeBtn.MouseButton1Click:Connect(function() bd:Destroy() end)
    draggable(hdr, card)

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 24, 0, 16)
    preview.Position = UDim2.new(1, -56, 0.5, -8)
    preview.BackgroundColor3 = currentColor
    preview.BorderSizePixel = 0
    preview.ZIndex = 2003
    preview.Parent = hdr
    corner(4, preview)

    local svBg = Instance.new("Frame")
    svBg.Size = UDim2.new(1, -20, 0, 120)
    svBg.Position = UDim2.new(0, 10, 0, 40)
    svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    svBg.BorderSizePixel = 0
    svBg.ZIndex = 2002
    svBg.Parent = card
    corner(6, svBg)

    local svSat = Instance.new("Frame")
    svSat.Size = UDim2.new(1, 0, 1, 0)
    svSat.BackgroundColor3 = Color3.new(1, 1, 1)
    svSat.BorderSizePixel = 0
    svSat.ZIndex = 2003
    svSat.Parent = svBg
    corner(6, svSat)
    
    local svSatG = Instance.new("UIGradient")
    svSatG.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    svSatG.Parent = svSat

    local svVal = Instance.new("Frame")
    svVal.Size = UDim2.new(1, 0, 1, 0)
    svVal.BackgroundColor3 = Color3.new(0, 0, 0)
    svVal.BorderSizePixel = 0
    svVal.ZIndex = 2004
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
    svCursor.ZIndex = 2005
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
    hueBar.ZIndex = 2002
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

-- Window Generator
local windowOffset = 20
function JL:CreateWindow(titleText)
    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, 200, 0, 40)
    win.Position = UDim2.new(0, windowOffset, 0, 50)
    win.BackgroundTransparency = 1
    win.ZIndex = 10
    win.Parent = MainGui

    windowOffset = windowOffset + 210

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.ZIndex = 10
    container.Parent = win

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = container

    local WinObj = {}

    function WinObj:CreateSection(secTitle, colorAccent)
        colorAccent = colorAccent or nxAc()

        local panel = Instance.new("Frame")
        panel.Size = UDim2.new(1, 0, 0, 34)
        panel.BackgroundColor3 = C.panel
        panel.BorderSizePixel = 0
        panel.ZIndex = 12
        panel.ClipsDescendants = true
        panel.Parent = container
        corner(8, panel)
        stroke(C.border, 1, panel)

        local hdr = Instance.new("Frame")
        hdr.Size = UDim2.new(1, 0, 0, 34)
        hdr.BackgroundColor3 = C.pHdr
        hdr.BorderSizePixel = 0
        hdr.ZIndex = 13
        hdr.Parent = panel
        corner(8, hdr)

        local ast = Instance.new("Frame")
        ast.Size = UDim2.new(0, 3, 0, 16)
        ast.Position = UDim2.new(0, 8, 0.5, -8)
        ast.BackgroundColor3 = colorAccent
        ast.BorderSizePixel = 0
        ast.ZIndex = 14
        ast.Parent = hdr
        corner(2, ast)

        newTxt({Parent = hdr, Text = secTitle, Font = Enum.Font.GothamBold, Size = 11, Color = C.txt, Sz = UDim2.new(1, -45, 1, 0), Pos = UDim2.new(0, 18, 0, 0), Z = 14})

        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0, 20, 0, 20)
        cb.Position = UDim2.new(1, -26, 0.5, -10)
        cb.BackgroundColor3 = C.btnBg
        cb.Text = "↓"
        cb.Font = Enum.Font.GothamBold
        cb.TextSize = 10
        cb.TextColor3 = C.dim
        cb.ZIndex = 14
        cb.Parent = hdr
        corner(5, cb)

        draggable(hdr, win)

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -12, 0, 0)
        content.Position = UDim2.new(0, 6, 0, 38)
        content.BackgroundTransparency = 1
        content.ZIndex = 13
        content.Parent = panel

        local cList = Instance.new("UIListLayout")
        cList.FillDirection = Enum.FillDirection.Vertical
        cList.Padding = UDim.new(0, 6)
        cList.SortOrder = Enum.SortOrder.LayoutOrder
        cList.Parent = content
        pad(0, 0, 0, 6, content)

        local collapsed = false
        local function resize()
            if not collapsed then
                local h = cList.AbsoluteContentSize.Y + 12
                content.Size = UDim2.new(1, -12, 0, h - 6)
                panel.Size = UDim2.new(1, 0, 0, 34 + h)
            end
        end

        cList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

        cb.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            cb.Text = collapsed and "↑" or "↓"
            if collapsed then
                tw(panel, {Size = UDim2.new(1, 0, 0, 34)}, .18)
                content.Visible = false
            else
                content.Visible = true
                resize()
            end
        end)

        local Sec = {}
        local order = 0

        local function newRow(h)
            order = order + 1
            local r = Instance.new("Frame")
            r.Size = UDim2.new(1, 0, 0, h)
            r.BackgroundTransparency = 1
            r.ZIndex = 15
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
            btn.ZIndex = 16
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
            newTxt({Parent = row, Text = text or "Toggle", Size = 10, Color = C.dim, Sz = UDim2.new(1, -36, 1, 0), Z = 16})

            local tog = Instance.new("TextButton")
            tog.Size = UDim2.new(0, 30, 0, 16)
            tog.Position = UDim2.new(1, -30, 0.5, -8)
            tog.BackgroundColor3 = default and C.togOn or C.togOff
            tog.Text = ""
            tog.ZIndex = 16
            tog.Parent = row
            corner(8, tog)

            local kn = Instance.new("Frame")
            kn.Size = UDim2.new(0, 12, 0, 12)
            kn.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
            kn.BackgroundColor3 = Color3.new(1, 1, 1)
            kn.BorderSizePixel = 0
            kn.ZIndex = 17
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
            newTxt({Parent = row, Text = text or "Slider", Size = 10, Color = C.dim, Sz = UDim2.new(1, -40, 0, 14), Z = 16})
            
            local valLbl = newTxt({Parent = row, Text = tostring(default or min), Font = Enum.Font.GothamBold, Size = 10, Color = C.txt, XAlign = Enum.TextXAlignment.Right, Sz = UDim2.new(0, 40, 0, 14), Pos = UDim2.new(1, -40, 0, 0), Z = 16})

            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, 0, 0, 6)
            track.Position = UDim2.new(0, 0, 0, 22)
            track.BackgroundColor3 = C.slTrack
            track.BorderSizePixel = 0
            track.ZIndex = 16
            track.Parent = row
            corner(3, track)

            local pct = math.clamp(((default or min) - min) / (max - min), 0, 1)
            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(pct, 0, 1, 0)
            fill.BackgroundColor3 = colorAccent
            fill.BorderSizePixel = 0
            fill.ZIndex = 17
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

        function Sec:Dropdown(text, items, default, callback)
            local row = newRow(26)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 1, 0)
            btn.BackgroundColor3 = C.btnBg
            btn.Text = (text or "Dropdown") .. ": " .. tostring(default or items[1] or "")
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 10
            btn.TextColor3 = C.txt
            btn.ZIndex = 16
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
            newTxt({Parent = row, Text = text or "Input", Size = 10, Color = C.dim, Sz = UDim2.new(1, 0, 0, 14), Z = 16})

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(1, 0, 0, 22)
            box.Position = UDim2.new(0, 0, 0, 18)
            box.BackgroundColor3 = C.input
            box.PlaceholderText = placeholder or "Type..."
            box.Text = ""
            box.Font = Enum.Font.Gotham
            box.TextSize = 10
            box.TextColor3 = C.txt
            box.ZIndex = 16
            box.Parent = row
            corner(6, box)
            stroke(C.border, 1, box)

            box.FocusLost:Connect(function(enter)
                if enter and callback then pcall(callback, box.Text) end
            end)
        end

        function Sec:ColorPicker(text, defaultColor, callback)
            local row = newRow(24)
            newTxt({Parent = row, Text = text or "Color", Size = 10, Color = C.dim, Sz = UDim2.new(1, -30, 1, 0), Z = 16})

            local p = Instance.new("TextButton")
            p.Size = UDim2.new(0, 24, 0, 16)
            p.Position = UDim2.new(1, -24, 0.5, -8)
            p.BackgroundColor3 = defaultColor or Color3.new(1, 1, 1)
            p.Text = ""
            p.ZIndex = 16
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

    return WinObj
end

return JL
