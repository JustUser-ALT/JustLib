local JustLib = {}
JustLib.__index = JustLib
JustLib.Flags = {}

local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HTTP = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

local C = {
    panel    = Color3.fromRGB(45, 45, 48),
    pHdr     = Color3.fromRGB(35, 35, 38),
    border   = Color3.fromRGB(70, 70, 75),
    txt      = Color3.fromRGB(240, 240, 240),
    dim      = Color3.fromRGB(160, 160, 165),
    togOn    = Color3.fromRGB(46, 204, 113),
    togOff   = Color3.fromRGB(35, 35, 38),
    slTrack  = Color3.fromRGB(55, 55, 60),
    btnBg    = Color3.fromRGB(55, 55, 60),
    btnHov   = Color3.fromRGB(75, 75, 80),
    sidebar  = Color3.fromRGB(30, 30, 33),
    divLine  = Color3.fromRGB(70, 70, 75),
    input    = Color3.fromRGB(55, 55, 60),
}

local ACCENTS = {
    Color3.fromRGB(82, 152, 255),
    Color3.fromRGB(148, 92, 255),
    Color3.fromRGB(72, 198, 138),
    Color3.fromRGB(255, 132, 72),
    Color3.fromRGB(255, 72, 108),
}

local _ai = 0
local function nxAc()
    _ai = _ai + 1
    return ACCENTS[((_ai - 1) % #ACCENTS) + 1]
end

JustLib.NotificationSettings = {
    Enabled = true,
    ShowWarnings = true,
    ShowErrors = true,
    DefaultDuration = 3,
    EnableStacking = true
}

local activeNotifs = {}

local function tw(o, p, t, s, d)
    TS:Create(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
end

local function corner(r, p)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = p
    return c
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
    u.PaddingLeft = UDim.new(0, l)
    u.PaddingRight = UDim.new(0, r)
    u.PaddingTop = UDim.new(0, t)
    u.PaddingBottom = UDim.new(0, b)
    u.Parent = p
    return u
end

local function ensurePathExists(path)
    if not makefolder or not isfolder then return end
    local current = ""
    for folder in string.gmatch(path, "[^/\\]+") do
        current = (current == "" and "" or current .. "/") .. folder
        if not isfolder(current) then
            pcall(makefolder, current)
        end
    end
end

local function newTxt(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.Font or Enum.Font.Gotham
    l.TextSize = props.Size or 11
    l.TextColor3 = props.Color or C.txt
    l.Text = props.Text or ""
    l.TextWrapped = props.Wrap or false
    l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
    l.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
    l.Size = props.Sz or UDim2.new(1, 0, 1, 0)
    l.Position = props.Pos or UDim2.new(0, 0, 0, 0)
    l.ZIndex = props.Z or 1
    l.RichText = props.RichText or false
    l.Parent = props.Parent
    return l
end

local function attachTooltip(parent, tooltipText)
    if not tooltipText or tooltipText == "" then return end
    
    local tooltipGui = CoreGui:FindFirstChild("JustLib_Tooltip")
    if not tooltipGui then
        tooltipGui = Instance.new("ScreenGui")
        tooltipGui.Name = "JustLib_Tooltip"
        tooltipGui.DisplayOrder = 999
        tooltipGui.Parent = CoreGui
    end

    local ttFrame = Instance.new("Frame")
    ttFrame.Size = UDim2.new(0, 150, 0, 26)
    ttFrame.BackgroundColor3 = C.pHdr
    ttFrame.BorderSizePixel = 0
    ttFrame.Visible = false
    ttFrame.ZIndex = 1000
    ttFrame.Parent = tooltipGui
    corner(6, ttFrame)
    stroke(C.border, 1, ttFrame)

    local ttTxt = newTxt({
        Parent = ttFrame,
        Size = 10,
        Color = C.txt,
        Wrap = true,
        Sz = UDim2.new(1, -10, 1, -6),
        Pos = UDim2.new(0, 5, 0, 3),
        Z = 1001,
        RichText = true
    })

    local moveConn
    parent.MouseEnter:Connect(function()
        ttTxt.Text = tooltipText
        ttFrame.Size = UDim2.new(0, math.max(120, #tooltipText * 6), 0, 26)
        ttFrame.Visible = true
        moveConn = UIS.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                ttFrame.Position = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y + 15)
            end
        end)
    end)

    parent.MouseLeave:Connect(function()
        ttFrame.Visible = false
        if moveConn then moveConn:Disconnect() end
    end)
end

function JustLib:Notify(opts)
    opts = opts or {}
    if not JustLib.NotificationSettings.Enabled then return end

    local title = opts.Title or "Notification"
    local text = opts.Text or ""
    local nType = opts.Type or "Info"
    local duration = opts.Duration or JustLib.NotificationSettings.DefaultDuration

    if nType == "Warning" and not JustLib.NotificationSettings.ShowWarnings then return end
    if nType == "Error" and not JustLib.NotificationSettings.ShowErrors then return end

    if JustLib.NotificationSettings.EnableStacking then
        for _, notif in ipairs(activeNotifs) do
            if notif.Title == title and notif.Text == text and notif.Frame and notif.Frame.Parent then
                notif.Count = notif.Count + 1
                notif.CountLabel.Text = "x" .. tostring(notif.Count)
                notif.CountLabel.Visible = true
                notif.ResetTimer(duration)
                return
            end
        end
    end

    local sg2 = CoreGui:FindFirstChild("JustLib_Notifs")
    if not sg2 then
        sg2 = Instance.new("ScreenGui")
        sg2.Name = "JustLib_Notifs"
        sg2.Parent = CoreGui
        sg2.ResetOnSpawn = false
    end

    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = C.panel
    f.Size = UDim2.new(0, 220, 0, 50)
    f.Position = UDim2.new(1, -230, 1, -60 - (#activeNotifs * 55))
    f.Parent = sg2
    corner(8, f)
    stroke(C.border, 1, f)

    local accentColor = C.txt
    if nType == "Warning" then accentColor = Color3.fromRGB(255, 170, 0)
    elseif nType == "Error" then accentColor = Color3.fromRGB(255, 60, 60)
    else accentColor = nxAc() end

    local bar = Instance.new("Frame", f)
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.BackgroundColor3 = accentColor
    bar.BorderSizePixel = 0
    corner(4, bar)

    newTxt({Parent = f, Text = title, Font = Enum.Font.GothamBold, Size = 12, Color = C.txt, Sz = UDim2.new(1, -45, 0, 18), Pos = UDim2.new(0, 10, 0, 6), Z = 5})
    newTxt({Parent = f, Text = text, Size = 10, Color = C.dim, Sz = UDim2.new(1, -20, 0, 20), Pos = UDim2.new(0, 10, 0, 24), Z = 5, Wrap = true, RichText = true})

    local countLabel = newTxt({
        Parent = f,
        Text = "x1",
        Font = Enum.Font.GothamBold,
        Size = 11,
        Color = Color3.fromRGB(255, 215, 0),
        Sz = UDim2.new(0, 30, 0, 16),
        Pos = UDim2.new(1, -35, 0, 6),
        XAlign = Enum.TextXAlignment.Right,
        Z = 5
    })
    countLabel.Visible = false

    local notifData = {
        Title = title,
        Text = text,
        Count = 1,
        Frame = f,
        CountLabel = countLabel
    }

    local timerThread
    notifData.ResetTimer = function(newTime)
        if timerThread then task.cancel(timerThread) end
        timerThread = task.delay(newTime, function()
            local idx = table.find(activeNotifs, notifData)
            if idx then table.remove(activeNotifs, idx) end
            f:Destroy()
        end)
    end

    table.insert(activeNotifs, notifData)
    notifData.ResetTimer(duration)
end

function JustLib:AddNotificationSettings(section)
    section:Toggle({
        Name = "Enable Notifications",
        Default = JustLib.NotificationSettings.Enabled,
        Callback = function(val)
            JustLib.NotificationSettings.Enabled = val
        end,
        Tooltip = "Master toggle for <font color='#FF5555'>notifications</font>."
    })

    section:Toggle({
        Name = "Notification Stacking",
        Default = JustLib.NotificationSettings.EnableStacking,
        Callback = function(val)
            JustLib.NotificationSettings.EnableStacking = val
        end,
        Tooltip = "Combines <font color='#FFFF00'>identical</font> popups with a counter."
    })

    section:Toggle({
        Name = "Show Warnings",
        Default = JustLib.NotificationSettings.ShowWarnings,
        Callback = function(val)
            JustLib.NotificationSettings.ShowWarnings = val
        end
    })

    section:Toggle({
        Name = "Show Errors",
        Default = JustLib.NotificationSettings.ShowErrors,
        Callback = function(val)
            JustLib.NotificationSettings.ShowErrors = val
        end
    })

    section:Slider({
        Name = "Duration (Sec)",
        Min = 1,
        Max = 10,
        Default = JustLib.NotificationSettings.DefaultDuration,
        Callback = function(val)
            JustLib.NotificationSettings.DefaultDuration = val
        end
    })
end

function JustLib:Window(opts)
    opts = opts or {}
    local windowTitle = opts.Title or "JustLib Hub"
    
    local baseFolder = "JustLib_Configs"
    if opts.ConfigFolder and opts.ConfigFolder ~= "" then
        baseFolder = baseFolder .. "/" .. opts.ConfigFolder
    end
    ensurePathExists(baseFolder)

    local sg = CoreGui:FindFirstChild("JustLib_UI")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "JustLib_UI"
        sg.Parent = CoreGui
        sg.ResetOnSpawn = false
    end

    local WW, WH = 530, 370
    local win = Instance.new("Frame")
    win.Size = UDim2.new(0, WW, 0, WH)
    win.Position = UDim2.new(0.5, -WW/2, 0.5, -WH/2)
    win.BackgroundColor3 = C.panel
    win.BorderSizePixel = 0
    win.ZIndex = 10
    win.Parent = sg
    corner(10, win)
    stroke(C.border, 1, win)

    local SBW = 40
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SBW, 1, 0)
    sidebar.Position = UDim2.new(0, 0, 0, 0)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.ZIndex = 12
    sidebar.Parent = win
    corner(10, sidebar)

    local sideList = Instance.new("UIListLayout")
    sideList.FillDirection = Enum.FillDirection.Vertical
    sideList.Padding = UDim.new(0, 6)
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.Parent = sidebar
    pad(7, 7, 10, 10, sidebar)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -(SBW + 10), 1, 0)
    content.Position = UDim2.new(0, SBW + 10, 0, 0)
    content.BackgroundTransparency = 1
    content.ZIndex = 11
    content.ClipsDescendants = true
    content.Parent = win

    local tabFrames = {}
    local tabBtns = {}
    local activeTabId = nil
    local _tabCount = 0

    local function switchToTab(id)
        for tid, fr in pairs(tabFrames) do
            if tid == id then
                fr.Visible = true
                tw(tabBtns[tid], {BackgroundColor3 = C.btnHov}, 0.1)
            else
                fr.Visible = false
                tw(tabBtns[tid], {BackgroundColor3 = C.btnBg}, 0.1)
            end
        end
        activeTabId = id
    end

    local Win = {
        Folder = baseFolder,
        ScreenGui = sg,
        MainFrame = win
    }

    function Win:Tab(topts)
        topts = topts or {}
        _tabCount = _tabCount + 1
        local tabId = _tabCount

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 26, 0, 26)
        btn.BackgroundColor3 = C.btnBg
        btn.Text = topts.Icon or "◼"
        btn.TextColor3 = C.txt
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.ZIndex = 13
        btn.Parent = sidebar
        corner(6, btn)

        tabBtns[tabId] = btn

        local tabFrame = Instance.new("ScrollingFrame")
        tabFrame.Size = UDim2.new(1, 0, 1, 0)
        tabFrame.BackgroundTransparency = 1
        tabFrame.BorderSizePixel = 0
        tabFrame.ScrollBarThickness = 3
        tabFrame.ScrollBarImageColor3 = C.border
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabFrame.ZIndex = 12
        tabFrame.Visible = false
        tabFrame.Parent = content
        pad(4, 8, 8, 8, tabFrame)

        local tabList = Instance.new("UIListLayout")
        tabList.FillDirection = Enum.FillDirection.Vertical
        tabList.Padding = UDim.new(0, 8)
        tabList.SortOrder = Enum.SortOrder.LayoutOrder
        tabList.Parent = tabFrame

        tabList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabFrame.CanvasSize = UDim2.new(0, 0, 0, tabList.AbsoluteContentSize.Y + 16)
        end)

        tabFrames[tabId] = tabFrame

        btn.MouseButton1Click:Connect(function()
            switchToTab(tabId)
        end)

        if not activeTabId then
            switchToTab(tabId)
        end

        local Tab = {}

        function Tab:Section(sopts)
            sopts = sopts or {}
            local secTitle = sopts.Title or "Section"
            local ac = nxAc()

            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(1, 0, 0, 36)
            panel.BackgroundColor3 = C.panel
            panel.BorderSizePixel = 0
            panel.ZIndex = 14
            panel.Parent = tabFrame
            corner(8, panel)
            stroke(C.border, 1, panel)

            local hdr = Instance.new("Frame")
            hdr.Size = UDim2.new(1, 0, 0, 30)
            hdr.BackgroundColor3 = C.pHdr
            hdr.BorderSizePixel = 0
            hdr.ZIndex = 15
            hdr.Parent = panel
            corner(8, hdr)

            newTxt({
                Parent = hdr,
                Text = secTitle,
                Font = Enum.Font.GothamBold,
                Size = 12,
                Color = C.txt,
                Pos = UDim2.new(0, 10, 0, 0),
                Sz = UDim2.new(1, -20, 1, 0),
                Z = 16
            })

            local secContent = Instance.new("Frame")
            secContent.Size = UDim2.new(1, 0, 0, 0)
            secContent.Position = UDim2.new(0, 0, 0, 32)
            secContent.BackgroundTransparency = 1
            secContent.ZIndex = 15
            secContent.Parent = panel
            pad(8, 8, 4, 8, secContent)

            local secList = Instance.new("UIListLayout")
            secList.FillDirection = Enum.FillDirection.Vertical
            secList.Padding = UDim.new(0, 6)
            secList.SortOrder = Enum.SortOrder.LayoutOrder
            secList.Parent = secContent

            local function resizePanel()
                panel.Size = UDim2.new(1, 0, 0, secList.AbsoluteContentSize.Y + 40)
            end
            secList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)

            local Sec = {}

            function Sec:Toggle(opts)
                opts = opts or {}
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 28)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                local bg = Instance.new("TextButton")
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = C.btnBg
                bg.Text = ""
                bg.ZIndex = 17
                bg.Parent = row
                corner(6, bg)
                stroke(C.border, 1, bg)

                newTxt({
                    Parent = bg,
                    Text = opts.Name or "Toggle",
                    Font = Enum.Font.GothamBold,
                    Size = 11,
                    Pos = UDim2.new(0, 8, 0, 0),
                    Sz = UDim2.new(1, -40, 1, 0),
                    Z = 18
                })

                local state = opts.Default or false
                JustLib.Flags[opts.Flag or opts.Name] = state

                local ind = Instance.new("Frame")
                ind.Size = UDim2.new(0, 16, 0, 16)
                ind.Position = UDim2.new(1, -22, 0.5, -8)
                ind.BackgroundColor3 = state and C.togOn or C.togOff
                ind.ZIndex = 18
                ind.Parent = bg
                corner(4, ind)

                bg.MouseButton1Click:Connect(function()
                    state = not state
                    JustLib.Flags[opts.Flag or opts.Name] = state
                    tw(ind, {BackgroundColor3 = state and C.togOn or C.togOff}, 0.15)
                    if opts.Callback then opts.Callback(state) end
                end)

                attachTooltip(bg, opts.Tooltip)
                return row
            end

            function Sec:Button(opts)
                opts = opts or {}
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 28)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                local bg = Instance.new("TextButton")
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = C.btnBg
                bg.Text = opts.Name or "Button"
                bg.Font = Enum.Font.GothamBold
                bg.TextSize = 11
                bg.TextColor3 = C.txt
                bg.ZIndex = 17
                bg.Parent = row
                corner(6, bg)
                stroke(C.border, 1, bg)

                bg.MouseButton1Click:Connect(function()
                    if opts.Callback then opts.Callback() end
                end)

                attachTooltip(bg, opts.Tooltip)
                return row
            end

            function Sec:Input(opts)
                opts = opts or {}
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 28)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                local bg = Instance.new("Frame")
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = C.btnBg
                bg.ZIndex = 17
                bg.Parent = row
                corner(6, bg)
                stroke(C.border, 1, bg)

                newTxt({
                    Parent = bg,
                    Text = opts.Name or "Input",
                    Font = Enum.Font.GothamBold,
                    Size = 11,
                    Pos = UDim2.new(0, 8, 0, 0),
                    Sz = UDim2.new(0.4, 0, 1, 0),
                    Z = 18
                })

                local tb = Instance.new("TextBox")
                tb.Size = UDim2.new(0.55, -8, 0.7, 0)
                tb.Position = UDim2.new(0.45, 0, 0.15, 0)
                tb.BackgroundColor3 = C.input
                tb.Text = opts.Default or ""
                tb.PlaceholderText = opts.Placeholder or "Type..."
                tb.Font = Enum.Font.Gotham
                tb.TextSize = 10
                tb.TextColor3 = C.txt
                tb.ZIndex = 18
                tb.Parent = bg
                corner(4, tb)

                tb.FocusLost:Connect(function(enterPressed)
                    JustLib.Flags[opts.Flag or opts.Name] = tb.Text
                    if opts.Callback then opts.Callback(tb.Text, enterPressed) end
                end)

                attachTooltip(bg, opts.Tooltip)
                return row
            end

            function Sec:Slider(opts)
                opts = opts or {}
                local min = opts.Min or 0
                local max = opts.Max or 100
                local default = opts.Default or min

                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 36)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                newTxt({
                    Parent = row,
                    Text = opts.Name or "Slider",
                    Font = Enum.Font.GothamBold,
                    Size = 11,
                    Pos = UDim2.new(0, 4, 0, 2),
                    Sz = UDim2.new(0.7, 0, 0, 14),
                    Z = 17
                })

                local valLbl = newTxt({
                    Parent = row,
                    Text = tostring(default),
                    Font = Enum.Font.GothamBold,
                    Size = 10,
                    Color = C.dim,
                    Pos = UDim2.new(0.7, 0, 0, 2),
                    Sz = UDim2.new(0.3, -4, 0, 14),
                    XAlign = Enum.TextXAlignment.Right,
                    Z = 17
                })

                local track = Instance.new("Frame")
                track.Size = UDim2.new(1, -8, 0, 6)
                track.Position = UDim2.new(0, 4, 0, 22)
                track.BackgroundColor3 = C.slTrack
                track.ZIndex = 17
                track.Parent = row
                corner(3, track)

                local fill = Instance.new("Frame")
                fill.Size = UDim2.new((default - min)/(max - min), 0, 1, 0)
                fill.BackgroundColor3 = ac
                fill.ZIndex = 18
                fill.Parent = track
                corner(3, fill)

                local dragging = false
                local function update(input)
                    local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    local val = math.floor(min + ((max - min) * pos))
                    fill.Size = UDim2.new(pos, 0, 1, 0)
                    valLbl.Text = tostring(val)
                    JustLib.Flags[opts.Flag or opts.Name] = val
                    if opts.Callback then opts.Callback(val) end
                end

                track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        update(input)
                    end
                end)

                UIS.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                UIS.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        update(input)
                    end
                end)

                attachTooltip(row, opts.Tooltip)
                return row
            end

            function Sec:Label(opts)
                opts = opts or {}
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 18)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                newTxt({
                    Parent = row,
                    Text = opts.Text or "",
                    Size = 10,
                    Color = opts.Color or C.dim,
                    Sz = UDim2.new(1, 0, 1, 0),
                    Z = 17
                })
                return row
            end

            function Sec:Divider(opts)
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 12)
                row.BackgroundTransparency = 1
                row.ZIndex = 16
                row.Parent = secContent

                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, 0, 0, 1)
                line.Position = UDim2.new(0, 0, 0.5, 0)
                line.BackgroundColor3 = C.divLine
                line.BorderSizePixel = 0
                line.ZIndex = 17
                line.Parent = row
                return row
            end

            return Sec
        end

        return Tab
    end

    return Win
end

return JustLib
