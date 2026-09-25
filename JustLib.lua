
local JL = {}; JL.Flags = {}; JL._winOpen = false; JL._listening = false; JL.Version = "2.2"
JL._registry = {}; JL._noSave = {}

local TS          = game:GetService("TweenService")
local UIS         = game:GetService("UserInputService")
local HTTP        = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunSvc      = game:GetService("RunService")
local LP          = game:GetService("Players").LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

local GB = Enum.Font.GothamBold
local GM = Enum.Font.GothamMedium
local G  = Enum.Font.Gotham

local C = {
    panel   = Color3.fromRGB(40,40,44),   pHdr    = Color3.fromRGB(31,31,35),
    border  = Color3.fromRGB(66,66,72),   txt     = Color3.fromRGB(240,240,242),
    dim     = Color3.fromRGB(150,150,158),togOn   = Color3.fromRGB(46,204,113),
    togOff  = Color3.fromRGB(28,28,32),   slTrack = Color3.fromRGB(58,58,64),
    btnBg   = Color3.fromRGB(50,50,55),   btnHov  = Color3.fromRGB(66,66,73),
    sidebar = Color3.fromRGB(28,28,31),   fpsGrn  = Color3.fromRGB(72,214,92),
    badge   = Color3.fromRGB(33,33,37),   badgeHi = Color3.fromRGB(50,60,90),
    divLine = Color3.fromRGB(70,70,76),   input   = Color3.fromRGB(50,50,55),
    danger  = Color3.fromRGB(200,68,68),  backdrop= Color3.fromRGB(16,16,18),
}
local ACCENTS = {
    Color3.fromRGB(82,152,255), Color3.fromRGB(148,92,255),
    Color3.fromRGB(72,198,138), Color3.fromRGB(255,132,72),
    Color3.fromRGB(255,72,108), Color3.fromRGB(72,208,208),
}
local _ai = 0
local function nxAc() _ai = _ai + 1; return ACCENTS[((_ai - 1) % #ACCENTS) + 1] end

-- ============================== helpers ==============================
local _conns = {}
local function keep(c) _conns[#_conns + 1] = c; return c end

local function tw(o,p,t,s,d)
    TS:Create(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
end
local function corner(r,p) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r); c.Parent = p; return c end
local function stroke(col,t,p) local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t; s.Parent = p; return s end
local function pad(l,r,t,b,p)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0,l); u.PaddingRight = UDim.new(0,r); u.PaddingTop = UDim.new(0,t); u.PaddingBottom = UDim.new(0,b)
    u.Parent = p; return u
end
local function newTxt(props)
    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.BorderSizePixel = 0
    l.Font = props.Font or G; l.TextSize = props.Size or 11
    l.TextColor3 = props.Color or C.txt; l.Text = props.Text or ""
    l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd; l.ZIndex = props.Z or 17
    if props.Wrap then l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.None end
    l.Size = props.Sz or UDim2.new(1,0,1,0); l.Position = props.Pos or UDim2.new(0,0,0,0)
    l.Parent = props.Parent; return l
end
-- height needed for wrapped text (used to auto-size every row)
local function fitH(text,size,font,w,minH,padV)
    local ok,b = pcall(function()
        return TextService:GetTextSize(tostring(text), size, font, Vector2.new(math.max(w,20), 10000))
    end)
    local th = ok and b.Y or (size + 2)
    return math.max(minH, th + padV)
end
local function isPtr(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
-- connects move/end listeners ONLY while dragging (no permanent global listeners)
local function beginDrag(onMove,onEnd)
    local c1,c2
    c1 = UIS.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then onMove(i) end
    end)
    c2 = UIS.InputEnded:Connect(function(i)
        if isPtr(i) then c1:Disconnect(); c2:Disconnect(); if onEnd then onEnd() end end
    end)
end
local function draggable(handle,frame,onTap)
    handle.InputBegan:Connect(function(i)
        if not isPtr(i) then return end
        local ds = Vector2.new(i.Position.X, i.Position.Y); local sp = frame.Position; local moved = false
        beginDrag(function(m)
            local d = Vector2.new(m.Position.X, m.Position.Y) - ds
            if d.Magnitude > 8 then moved = true end
            if moved then frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end
        end, function() if not moved and onTap then onTap() end end)
    end)
end
-- ============================== custom icon packs ==============================
-- Real integration with https://github.com/Footagesus/Icons, which itself aggregates Lucide,
-- Craft, Geist, Solar, SF Symbols and Gravity UI. That module exposes GetIcon(name) -> rbxassetid
-- and SetIconsType(type); names outside the current default set use "type:name" (e.g. "geist:window").
JL._iconOverrides = {}
function JL:LoadIconPack(url)
    url = url or "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if not ok or not body or body == "" then return false end
    local ok2,fn = pcall(loadstring, body)
    if not ok2 or not fn then return false end
    local ok3,mod = pcall(fn)
    if not ok3 or type(mod) ~= "table" then return false end
    JL._iconPack = mod
    return true
end
-- switch the default icon set for un-prefixed names, e.g. JL:SetIconType("geist")
function JL:SetIconType(iconType)
    if JL._iconPack and JL._iconPack.SetIconsType then pcall(JL._iconPack.SetIconsType, iconType) end
end
-- manual name -> rbxassetid overrides, checked before the loaded pack, e.g. JL:SetIcons({heart = 123456})
function JL:SetIcons(tbl)
    for k,v in pairs(tbl or {}) do JL._iconOverrides[k] = v end
end
local function resolveIcon(s)
    if JL._iconOverrides[s] then return tostring(JL._iconOverrides[s]) end
    if JL._iconPack then
        if JL._iconPack.GetIcon then
            local ok,id = pcall(JL._iconPack.GetIcon, s)
            if ok and id and id ~= "" then return tostring(id) end
        elseif JL._iconPack[s] then
            return tostring(JL._iconPack[s])
        end
    end
    return s
end
local function mkIcon(parent,icon,sz,z)
    sz = sz or 20; z = z or 13; local s = resolveIcon(tostring(icon))
    if s:match("^rbxassetid://") or s:match("^%d+$") then
        local img = Instance.new("ImageLabel"); img.Size = UDim2.new(0,sz,0,sz); img.BackgroundTransparency = 1
        img.Image = s:match("^%d+$") and ("rbxassetid://" .. s) or s; img.ZIndex = z; img.Parent = parent; return img
    else
        local l = Instance.new("TextLabel"); l.Size = UDim2.new(0,sz,0,sz); l.BackgroundTransparency = 1
        l.Text = s; l.TextScaled = true; l.Font = GB; l.TextColor3 = C.txt; l.ZIndex = z; l.Parent = parent; return l
    end
end
local function decimalsOf(step) local d = tostring(step):match("%.(%d+)$"); return d and #d or 0 end
local function fmtNum(v,dec)
    if dec <= 0 then return tostring(math.floor(v + 0.5)) end
    local s = string.format("%." .. dec .. "f", v)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end
local function snap(v,vmin,vmax,step)
    v = math.clamp(v, vmin, vmax)
    v = vmin + math.floor((v - vmin) / step + 0.5) * step
    local m = 10 ^ decimalsOf(step)
    v = math.floor(v * m + 0.5) / m
    return math.clamp(v, vmin, vmax)
end

-- ============================== config ==============================
local _cfgFile = nil; local _cfgData = {}; local _saveQueued = false
local function cfgLoad(name)
    _cfgFile = name .. ".json"
    if readfile then
        local ok,r = pcall(readfile, _cfgFile)
        if ok and r and r ~= "" then
            local ok2,d = pcall(HTTP.JSONDecode, HTTP, r)
            if ok2 and type(d) == "table" then _cfgData = d end
        end
    end
end
-- debounced: slider drags no longer hammer writefile
local function cfgSave()
    if not (_cfgFile and writefile) or _saveQueued then return end
    _saveQueued = true
    task.delay(.4, function()
        _saveQueued = false
        pcall(writefile, _cfgFile, HTTP:JSONEncode(_cfgData))
    end)
end
local function cfgHas(flag) return flag ~= nil and _cfgData[flag] ~= nil end
local function cfgSet(flag,val,store)
    if not flag then return end
    if store == nil then store = val end
    _cfgData[flag] = store; JL.Flags[flag] = val; cfgSave()
end
local function cfgGet(flag,default)
    if flag and _cfgData[flag] ~= nil then JL.Flags[flag] = _cfgData[flag]; return _cfgData[flag] end
    if flag then JL.Flags[flag] = default end
    return default
end

-- ============================== notifications ==============================
-- Configurable via Settings > Notifications (show filters, duration, corner, Stack).
do
    local CoreGui = game:GetService("CoreGui")
    shared._JLNotifs = shared._JLNotifs or {}
    local active = shared._JLNotifs
    local W,H = 200,55
    local MARGIN = 14
    local GAP = 72.5

    local function notifySide() return tostring(cfgGet("_notify_side","TopRight")) end
    local function edgeXY(side)
        local camObj = workspace.CurrentCamera
        local vp = camObj and camObj.ViewportSize or Vector2.new(1280,720)
        local top = (side == "TopLeft" or side == "TopRight")
        local left = (side == "TopLeft" or side == "BottomLeft")
        local x = left and MARGIN or (vp.X - W - MARGIN)
        local yBase = top and MARGIN or (vp.Y - H - MARGIN)
        return x, yBase, top, left
    end
    local function updPos()
        local x, yBase, top = edgeXY(notifySide())
        local n = #active
        for k,nd in ipairs(active) do
            if nd and nd.f then
                local slot = n - k -- 0 = newest, closest to the corner
                local y = top and (yBase + slot * GAP) or (yBase - slot * GAP)
                tw(nd.f,{Position = UDim2.new(0,x,0,y)},.35,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
            end
        end
    end
    JL._notifyReposition = updPos -- Settings calls this when the side picker changes, to reflow live notifs

    local function typeAllowed(typ)
        if typ == "Warn" then return cfgGet("_notify_show_warning", true) end
        if typ == "Error" then return cfgGet("_notify_show_error", true) end
        return cfgGet("_notify_show_regular", true) -- Info / Success
    end

    function JL:Notify(cfg2)
        cfg2 = cfg2 or {}
        local typ = cfg2.Type or "Info"
        if not typeAllowed(typ) then return end
        local title = cfg2.Title or "JustLib"; local desc = cfg2.Desc or ""
        local dur = cfg2.Duration or tonumber(cfgGet("_notify_duration",5)) or 5
        local col=Color3.fromRGB(158,198,255); local ico="rbxassetid://70718918423383"
        if typ=="Error" then col=Color3.fromRGB(255,82,82); ico="rbxassetid://113114601887005"
        elseif typ=="Success" then col=Color3.fromRGB(145,255,128); ico="rbxassetid://18567015051"
        elseif typ=="Warn" then col=Color3.fromRGB(255,225,117); ico="rbxassetid://14863060512" end

        -- Notify Stack: fold a repeat of the same title/desc/type into an "x2, x3..." counter
        if cfgGet("_notify_stack", false) then
            for _,nd in ipairs(active) do
                if nd and not nd.closing and nd.title == title and nd.desc == desc and nd.typ == typ then
                    nd.count = nd.count + 1
                    if nd.countLbl then nd.countLbl.Text = "x" .. nd.count; nd.countLbl.Visible = true end
                    if nd.barTw and nd.barTw.PlaybackState == Enum.PlaybackState.Playing then nd.barTw:Cancel() end
                    if nd.db then nd.db.Size = UDim2.new(0,180,0,3) end
                    nd.barTw = TS:Create(nd.db, TweenInfo.new(dur,Enum.EasingStyle.Linear), {Size = UDim2.new(0,0,0,3)})
                    nd.barTw:Play()
                    return
                end
            end
        end

        local side = notifySide()
        local x, yBase, top, left = edgeXY(side)
        local startX = left and (x - 260) or (x + 260)

        local sg2=Instance.new("ScreenGui"); sg2.Name="JLNotif"; sg2.Parent=CoreGui; sg2.ClipToDeviceSafeArea=false; sg2.ResetOnSpawn=false
        local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(0,0,0); f.Size=UDim2.new(0,W,0,H); f.Position=UDim2.new(0,startX,0,yBase); f.Parent=sg2; corner(8,f)
        local te=Instance.new("Frame"); te.ZIndex=0; te.BorderSizePixel=0; te.BackgroundColor3=col; te.Size=UDim2.new(0,20,0,H); te.Position=UDim2.new(0,-3,0,0); te.Parent=f; corner(8,te)
        local ti=Instance.new("ImageLabel"); ti.BorderSizePixel=0; ti.BackgroundTransparency=1; ti.ImageColor3=col; ti.Image=ico; ti.Size=UDim2.new(0,15,0,15); ti.Position=UDim2.new(0,3,0,3); ti.Parent=f
        newTxt({Parent=f,Text=title,Font=GB,Size=14,Color=Color3.new(1,1,1),Sz=UDim2.new(0,116,0,20),Pos=UDim2.new(0,22,0,2),Z=5})
        local countLbl = newTxt({Parent=f,Text="",Font=GB,Size=12,Color=col,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,24,0,20),Pos=UDim2.new(1,-52,0,2),Z=5})
        countLbl.Visible = false
        local td=newTxt({Parent=f,Text=desc,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(0,180,0,28),Pos=UDim2.new(0,10,0,22),Z=5,Wrap=true}); td.TextTransparency=0.25
        local db=Instance.new("Frame"); db.BorderSizePixel=0; db.BackgroundColor3=col; db.Size=UDim2.new(0,180,0,3); db.Position=UDim2.new(0,10,0,50); db.BackgroundTransparency=0.2; db.Parent=f; corner(2,db)
        local cb=Instance.new("TextButton"); cb.BorderSizePixel=0; cb.BackgroundTransparency=1; cb.TextSize=14; cb.Font=GB; cb.TextColor3=Color3.new(1,1,1); cb.ZIndex=6; cb.Size=UDim2.new(0,20,0,20); cb.Position=UDim2.new(1,-22,0,2); cb.Text="x"; cb.Parent=f

        local nd = {f=f, g=sg2, title=title, desc=desc, typ=typ, count=1, countLbl=countLbl, db=db, closing=false}
        table.insert(active,nd)
        nd.barTw = TS:Create(db,TweenInfo.new(dur,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,0,3)})
        local function close()
            if nd.closing then return end; nd.closing=true
            if nd.barTw and nd.barTw.PlaybackState==Enum.PlaybackState.Playing then nd.barTw:Cancel() end
            for i,v in ipairs(active) do if v==nd then table.remove(active,i); break end end
            updPos()
            if f and f.Parent then
                local exitX = left and (x - 260) or (x + 260)
                local t2=TS:Create(f,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position=UDim2.new(0,exitX,0,f.Position.Y.Offset)}); t2:Play(); t2.Completed:Connect(function() sg2:Destroy() end)
            end
        end
        nd.close = close
        cb.MouseButton1Click:Connect(close)
        updPos() -- slides this one (and shifts existing ones) into place
        task.delay(.35, function() if not nd.closing then nd.barTw:Play() end end)
        nd.barTw.Completed:Connect(function() if not nd.closing then close() end end)
    end
end

-- ============================== confirm dialog ==============================
-- Public: JL:Confirm({Title=, Desc=, ConfirmText=, CancelText=, Danger=true/false}) -> true/false
-- Can be called from anywhere, including your own Button/Toggle/Dropdown callbacks.
local function confirmDialog(promptTitle,promptDesc,opts)
    opts = opts or {}
    local CoreGui = game:GetService("CoreGui")
    local sg3 = Instance.new("ScreenGui"); sg3.Name = "JLConfirm"; sg3.ResetOnSpawn = false; sg3.IgnoreGuiInset = true; sg3.DisplayOrder = 1000
    local okp = pcall(function() sg3.Parent = CoreGui end); if not okp or not sg3.Parent then sg3.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sg3
    local card = Instance.new("Frame"); card.Size = UDim2.new(0,280,0,150); card.Position = UDim2.new(0.5,-140,0.5,-70); card.BackgroundColor3 = C.panel; card.BorderSizePixel = 0; card.BackgroundTransparency = 1; card.Parent = bd; corner(12,card); stroke(C.border,1,card)
    local accentCol = opts.Danger and C.danger or ACCENTS[1]
    local topBar = Instance.new("Frame"); topBar.Size = UDim2.new(1,0,0,3); topBar.BackgroundColor3 = accentCol; topBar.BorderSizePixel = 0; topBar.Parent = card; corner(2,topBar)
    newTxt({Parent=card,Text=promptTitle,Font=GB,Size=15,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-20,0,20),Pos=UDim2.new(0,10,0,16)})
    newTxt({Parent=card,Text=promptDesc,Size=11,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-28,0,52),Pos=UDim2.new(0,14,0,42)})
    local function mkB(txt,col,bordered,pos)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0.5,-22,0,32); b.Position = pos; b.BackgroundColor3 = col; b.Text = txt; b.Font = GB; b.TextSize = 13
        b.TextColor3 = Color3.new(1,1,1); b.AutoButtonColor = true; b.Parent = card; corner(8,b); if bordered then stroke(C.border,1,b) end; return b
    end
    local confirmBtn = mkB(opts.ConfirmText or "Yes", opts.Danger and C.danger or Color3.fromRGB(72,198,138), false, UDim2.new(0,14,1,-46))
    local cancelBtn  = mkB(opts.CancelText or "No",  C.btnBg, true, UDim2.new(0.5,8,1,-46))
    local result = nil
    confirmBtn.MouseButton1Click:Connect(function() if result == nil then result = true end end)
    cancelBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    tw(bd,{BackgroundTransparency = 0.45},.18)
    card.Position = UDim2.new(0.5,-140,0.5,-64)
    tw(card,{BackgroundTransparency = 0, Position = UDim2.new(0.5,-140,0.5,-75)},.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    while result == nil do task.wait() end
    sg3:Destroy()
    return result
end
function JL:Confirm(opts)
    opts = opts or {}
    return confirmDialog(opts.Title or "Are you sure?", opts.Desc or "", opts)
end

-- ============================== widgets ==============================
local function mkSwitch(parent,pos,state,ac)
    local track = Instance.new("Frame"); track.Size = UDim2.new(0,34,0,18); track.Position = pos
    track.BackgroundColor3 = state and ac or C.togOff; track.BorderSizePixel = 0; track.Parent = parent; corner(9,track)
    local st = stroke(state and ac or C.border, 1, track)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,12,0,12)
    knob.Position = state and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
    knob.BackgroundColor3 = state and Color3.new(1,1,1) or C.dim; knob.BorderSizePixel = 0; knob.Parent = track; corner(6,knob)
    local obj = {Frame = track}
    function obj.Set(v)
        tw(track,{BackgroundColor3 = v and ac or C.togOff},.15)
        tw(knob,{Position = v and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6), BackgroundColor3 = v and Color3.new(1,1,1) or C.dim},.15)
        tw(st,{Color = v and ac or C.border},.15)
    end
    return obj
end

local function mkSliderBar(parent,pos,size,ac,vmin,vmax,step,init,onChange)
    local track = Instance.new("Frame"); track.Size = size; track.Position = pos; track.BackgroundColor3 = C.slTrack; track.BorderSizePixel = 0; track.Parent = parent; corner(3,track)
    local fill = Instance.new("Frame"); fill.BackgroundColor3 = ac; fill.BorderSizePixel = 0; fill.Parent = track; corner(3,fill)
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,14,0,14); knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0; knob.ZIndex = 2; knob.Parent = track; corner(7,knob)
    stroke(Color3.fromRGB(20,20,24),1,knob)
    local hit = Instance.new("TextButton"); hit.Size = UDim2.new(1,14,0,26); hit.Position = UDim2.new(0,-7,0.5,-13); hit.BackgroundTransparency = 1; hit.Text = ""; hit.AutoButtonColor = false; hit.ZIndex = 3; hit.Parent = track
    local val = snap(tonumber(init) or vmin, vmin, vmax, step)
    local function paint()
        local p = (vmax > vmin) and (val - vmin) / (vmax - vmin) or 0
        fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,-7,0.5,-7)
    end
    paint()
    local obj = {}
    function obj.Set(v,silent)
        v = snap(tonumber(v) or vmin, vmin, vmax, step)
        local changed = (v ~= val); val = v; paint()
        if changed and not silent and onChange then onChange(v) end
    end
    function obj.Get() return val end
    local function fromX(x)
        local w = track.AbsoluteSize.X; if w <= 0 then return end
        local p = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        obj.Set(vmin + p * (vmax - vmin), false)
    end
    hit.InputBegan:Connect(function(i)
        if not isPtr(i) then return end
        fromX(i.Position.X); beginDrag(function(m) fromX(m.Position.X) end)
    end)
    return obj
end

local function mkSegmented(parent,pos,size,options,init,ac,onChange)
    local f = Instance.new("Frame"); f.Size = size; f.Position = pos; f.BackgroundColor3 = C.pHdr; f.BorderSizePixel = 0; f.Parent = parent; corner(8,f); stroke(C.border,1,f)
    local cur = init; local btns = {}; local n = math.max(#options,1)
    local function paint()
        for name,b in pairs(btns) do
            local on = (name == cur)
            tw(b,{BackgroundColor3 = on and ac or C.pHdr, TextColor3 = on and Color3.new(1,1,1) or C.dim},.15)
        end
    end
    local obj = {}
    for i,name in ipairs(options) do
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1/n,-4,1,-6); b.Position = UDim2.new((i-1)/n,2,0,3)
        b.BackgroundColor3 = C.pHdr; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Text = tostring(name); b.Font = GB
        b.TextSize = 11; b.TextScaled = true; b.TextColor3 = C.dim; b.Parent = f; corner(6,b)
        local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 11; tc.MinTextSize = 6; tc.Parent = b
        btns[name] = b
        b.MouseButton1Click:Connect(function()
            if cur == name then return end
            cur = name; paint(); if onChange then onChange(name) end
        end)
    end
    paint()
    function obj.Set(v,silent) if btns[v] then cur = v; paint(); if not silent and onChange then onChange(v) end end end
    function obj.Get() return cur end
    return obj
end

local function keyFromName(n)
    if not n or n == "None" then return nil end
    local ok,k = pcall(function() return Enum.KeyCode[n] end)
    if ok then return k end
    return nil
end
local function shortKey(k)
    if not k then return "None" end
    local n = k.Name
    n = n:gsub("Left","L"):gsub("Right","R"):gsub("Control","Ctrl"):gsub("Return","Enter")
    return n
end
local function mkKeyChip(parent,pos,initName,onSet)
    local key = keyFromName(initName); local capturing = false
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0,84,0,22); btn.Position = pos; btn.BackgroundColor3 = C.pHdr; btn.BorderSizePixel = 0
    btn.AutoButtonColor = false; btn.Font = GB; btn.TextSize = 11; btn.TextColor3 = C.txt; btn.Text = shortKey(key); btn.Parent = parent; corner(6,btn)
    local st = stroke(C.border,1,btn)
    btn.MouseButton1Click:Connect(function()
        capturing = true; JL._listening = true; btn.Text = "press a key..."; st.Color = ACCENTS[1]
    end)
    keep(UIS.InputBegan:Connect(function(i)
        if not capturing or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
        capturing = false; st.Color = C.border
        task.defer(function() JL._listening = false end)
        if i.KeyCode == Enum.KeyCode.Escape then btn.Text = shortKey(key); return end
        if i.KeyCode == Enum.KeyCode.Backspace then key = nil else key = i.KeyCode end
        btn.Text = shortKey(key); if onSet then onSet(key) end
    end))
    local obj = {Btn = btn}
    function obj.Get() return key end
    function obj.Set(k) key = k; btn.Text = shortKey(k) end
    return obj
end

-- ============================== color picker ==============================
local _cpSg = nil
local function ensureCpSg(sg)
    if not _cpSg or not _cpSg.Parent then
        _cpSg = Instance.new("Frame"); _cpSg.Size = UDim2.new(1,0,1,0); _cpSg.BackgroundColor3 = Color3.new(0,0,0)
        _cpSg.BackgroundTransparency = 0.5; _cpSg.BorderSizePixel = 0; _cpSg.ZIndex = 200; _cpSg.Active = true; _cpSg.Visible = false; _cpSg.Parent = sg
        local bd = _cpSg
        bd.InputBegan:Connect(function(i)
            if not isPtr(i) then return end
            local card = bd:FindFirstChild("Card"); if not card then bd.Visible = false; return end
            local pos = Vector2.new(i.Position.X, i.Position.Y); local cp = card.AbsolutePosition; local cs = card.AbsoluteSize
            if pos.X < cp.X or pos.X > cp.X + cs.X or pos.Y < cp.Y or pos.Y > cp.Y + cs.Y then bd.Visible = false end
        end)
    end
    return _cpSg
end

local function openColorPicker(sg,currentColor,callback)
    local bd = ensureCpSg(sg); bd.Visible = true
    local old = bd:FindFirstChild("Card"); if old then old:Destroy() end
    local h,s,v = Color3.toHSV(currentColor)

    local card = Instance.new("Frame"); card.Name = "Card"; card.Size = UDim2.new(0,260,0,332); card.Position = UDim2.new(0.5,-130,0.5,-166)
    card.BackgroundColor3 = C.panel; card.BorderSizePixel = 0; card.Active = true; card.Parent = bd; corner(12,card); stroke(C.border,1,card)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,34); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = card; corner(12,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    newTxt({Parent=hdr,Text="Color Picker",Font=GB,Size=13,Sz=UDim2.new(1,-90,1,0),Pos=UDim2.new(0,12,0,0)})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,24,0,24); closeBtn.Position = UDim2.new(1,-30,0.5,-12); closeBtn.BackgroundColor3 = C.danger
    closeBtn.Text = "✕"; closeBtn.Font = GB; closeBtn.TextSize = 12; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.ZIndex = 5; closeBtn.Parent = hdr; corner(7,closeBtn)
    closeBtn.MouseButton1Click:Connect(function() bd.Visible = false end)
    draggable(hdr,card)
    local preview = Instance.new("Frame"); preview.Size = UDim2.new(0,28,0,20); preview.Position = UDim2.new(1,-66,0.5,-10); preview.BackgroundColor3 = currentColor; preview.BorderSizePixel = 0; preview.ZIndex = 5; preview.Parent = hdr; corner(5,preview); stroke(C.border,1,preview)

    -- saturation / value
    local svBg = Instance.new("Frame"); svBg.Size = UDim2.new(1,-20,0,130); svBg.Position = UDim2.new(0,10,0,44); svBg.BackgroundColor3 = Color3.fromHSV(h,1,1); svBg.BorderSizePixel = 0; svBg.Parent = card; corner(6,svBg)
    local svSat = Instance.new("Frame"); svSat.Size = UDim2.new(1,0,1,0); svSat.BackgroundColor3 = Color3.new(1,1,1); svSat.BorderSizePixel = 0; svSat.ZIndex = 2; svSat.Parent = svBg; corner(6,svSat)
    local g1 = Instance.new("UIGradient"); g1.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); g1.Parent = svSat
    local svVal = Instance.new("Frame"); svVal.Size = UDim2.new(1,0,1,0); svVal.BackgroundColor3 = Color3.new(0,0,0); svVal.BorderSizePixel = 0; svVal.ZIndex = 3; svVal.Parent = svBg; corner(6,svVal)
    local g2 = Instance.new("UIGradient"); g2.Rotation = 90; g2.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); g2.Parent = svVal
    local svCursor = Instance.new("Frame"); svCursor.Size = UDim2.new(0,12,0,12); svCursor.BackgroundTransparency = 1; svCursor.ZIndex = 4; svCursor.Parent = svBg; corner(6,svCursor); stroke(Color3.new(1,1,1),2,svCursor)
    local svHit = Instance.new("TextButton"); svHit.Size = UDim2.new(1,0,1,0); svHit.BackgroundTransparency = 1; svHit.Text = ""; svHit.ZIndex = 5; svHit.Parent = svBg

    -- hue
    local hueBar = Instance.new("Frame"); hueBar.Size = UDim2.new(1,-20,0,12); hueBar.Position = UDim2.new(0,10,0,184); hueBar.BackgroundColor3 = Color3.new(1,1,1); hueBar.BorderSizePixel = 0; hueBar.Parent = card; corner(5,hueBar)
    local hueG = Instance.new("UIGradient"); hueG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}); hueG.Parent = hueBar
    local hueCursor = Instance.new("Frame"); hueCursor.Size = UDim2.new(0,8,1,6); hueCursor.BackgroundColor3 = Color3.new(1,1,1); hueCursor.BorderSizePixel = 0; hueCursor.ZIndex = 2; hueCursor.Parent = hueBar; corner(3,hueCursor); stroke(Color3.new(0,0,0),1,hueCursor)
    local hueHit = Instance.new("TextButton"); hueHit.Size = UDim2.new(1,0,1,8); hueHit.Position = UDim2.new(0,0,0,-4); hueHit.BackgroundTransparency = 1; hueHit.Text = ""; hueHit.ZIndex = 3; hueHit.Parent = hueBar

    -- RGB sliders + hex
    local rgbBars = {}; local rgbVals = {}
    local hexBox
    local commit
    local chanCols = {Color3.fromRGB(255,90,90), Color3.fromRGB(90,220,120), Color3.fromRGB(90,150,255)}
    local function rgbChanged()
        local col = Color3.fromRGB(rgbBars[1].Get(), rgbBars[2].Get(), rgbBars[3].Get())
        h,s,v = Color3.toHSV(col)
    end
    for idx,lab in ipairs({"R","G","B"}) do
        local row = Instance.new("Frame"); row.Size = UDim2.new(1,-20,0,22); row.Position = UDim2.new(0,10,0,206 + (idx-1)*26); row.BackgroundTransparency = 1; row.Parent = card
        newTxt({Parent=row,Text=lab,Font=GB,Size=11,Color=C.dim,Sz=UDim2.new(0,14,1,0)})
        rgbVals[idx] = newTxt({Parent=row,Text="0",Font=GB,Size=11,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,34,1,0),Pos=UDim2.new(1,-34,0,0)})
        local col0 = Color3.fromHSV(h,s,v); local ch0 = (idx == 1 and col0.R) or (idx == 2 and col0.G) or col0.B
        rgbBars[idx] = mkSliderBar(row, UDim2.new(0,26,0.5,-3), UDim2.new(1,-72,0,6), chanCols[idx], 0, 255, 1, math.round(ch0 * 255), function()
            rgbChanged(); commit(idx)
        end)
    end
    local hexRow = Instance.new("Frame"); hexRow.Size = UDim2.new(1,-20,0,26); hexRow.Position = UDim2.new(0,10,0,292); hexRow.BackgroundTransparency = 1; hexRow.Parent = card
    newTxt({Parent=hexRow,Text="HEX",Font=GB,Size=11,Color=C.dim,Sz=UDim2.new(0,34,1,0)})
    hexBox = Instance.new("TextBox"); hexBox.Size = UDim2.new(1,-40,1,0); hexBox.Position = UDim2.new(0,40,0,0); hexBox.BackgroundColor3 = C.pHdr; hexBox.BorderSizePixel = 0
    hexBox.Font = GB; hexBox.TextSize = 12; hexBox.TextColor3 = C.txt; hexBox.ClearTextOnFocus = false; hexBox.Text = ""; hexBox.Parent = hexRow; corner(6,hexBox); stroke(C.border,1,hexBox)

    commit = function(srcIdx)
        local col = Color3.fromHSV(h,s,v)
        preview.BackgroundColor3 = col; svBg.BackgroundColor3 = Color3.fromHSV(h,1,1)
        svCursor.Position = UDim2.new(s,-6,1-v,-6); hueCursor.Position = UDim2.new(h,-4,0,-3)
        local chs = {col.R, col.G, col.B}
        for i = 1,3 do
            local n = math.round(chs[i] * 255)
            if i ~= srcIdx then rgbBars[i].Set(n, true) end
            rgbVals[i].Text = tostring(n)
        end
        local okh,hx = pcall(function() return col:ToHex() end)
        if okh and hexBox and not hexBox:IsFocused() then hexBox.Text = "#" .. hx:upper() end
        if callback then callback(col) end
    end
    hexBox.FocusLost:Connect(function()
        local t = hexBox.Text:gsub("#",""):gsub("%s","")
        if #t == 6 then
            local ok,c3 = pcall(function() return Color3.fromHex(t) end)
            if ok and c3 then h,s,v = Color3.toHSV(c3) end
        end
        commit(0)
    end)
    local function svFrom(i)
        local ap,as = svBg.AbsolutePosition, svBg.AbsoluteSize
        s = math.clamp((i.Position.X - ap.X) / as.X, 0, 1); v = math.clamp(1 - (i.Position.Y - ap.Y) / as.Y, 0, 1); commit(0)
    end
    svHit.InputBegan:Connect(function(i) if isPtr(i) then svFrom(i); beginDrag(svFrom) end end)
    local function hueFrom(i)
        local ap,as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
        h = math.clamp((i.Position.X - ap.X) / as.X, 0, 1); commit(0)
    end
    hueHit.InputBegan:Connect(function(i) if isPtr(i) then hueFrom(i); beginDrag(hueFrom) end end)
    -- initial paint without firing the user callback
    local cb0 = callback; callback = nil; commit(0); callback = cb0
end

-- ============================== section widgets (shared by Section & MultiSection pages) ==============================
local function attachWidgets(content,INNER,ac,uiScale,parentSg,attachTip)
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local iOrd = 0
    local Sec = {}
    local ICONW = 22
    -- optional leading icon; returns the width it consumes
    local function iconSlot(holder,icon)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 15, 5); ic.Position = UDim2.new(0,10,0.5,-7); ic.Size = UDim2.new(0,15,0,15)
        if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
        return ICONW
    end
    local function tip(guiObject,text) if attachTip then attachTip(guiObject, text) end end
    local function newRow(h2)
        iOrd = iOrd + 1
        local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,h2); r.BackgroundTransparency = 1; r.BorderSizePixel = 0; r.LayoutOrder = iOrd; r.Parent = content
        return r
    end
    local function hover(b,base,hov)
        b.MouseEnter:Connect(function() tw(b,{BackgroundColor3 = hov},.1) end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = base},.1) end)
    end
    local function regFlag(flag,ctrl,noSave)
        if not flag then return end
        JL._registry[flag] = ctrl
        if noSave then JL._noSave[flag] = true else JL._noSave[flag] = nil end
    end

    -- ---------- Toggle ----------
    function Sec:Toggle(o)
        o = o or {}
        local had = cfgHas(o.Flag); local state = cfgGet(o.Flag, o.Default or false)
        local name = o.Name or "Toggle"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 48 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local sw = mkSwitch(bg, UDim2.new(1,-44,0.5,-9), state, ac)
        bg.MouseButton1Click:Connect(function()
            state = not state; sw.Set(state); cfgSet(o.Flag, state)
            if o.Callback then pcall(o.Callback, state) end
        end)
        if o.Callback and had then pcall(o.Callback, state) end
        local ret = {Set = function(_,v) state = v; sw.Set(v); cfgSet(o.Flag, v) end, Get = function() return state end}
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Slider (Step, Suffix, click the value to type it) ----------
    function Sec:Slider(o)
        o = o or {}
        local vmin = o.Min or 0; local vmax = o.Max or 100; local step = o.Step or o.Increment or 1
        local dec = decimalsOf(step); local suffix = o.Suffix or ""
        local had = cfgHas(o.Flag)
        local val = snap(tonumber(cfgGet(o.Flag, o.Default or vmin)) or vmin, vmin, vmax, step)
        local name = o.Name or "Slider"; local iconW = o.Icon and ICONW or 0
        local topH = fitH(name, 12, GB, INNER - 4 - 66 - iconW, 18, 2)
        local row = newRow(topH + 24)
        tip(row, o.Tooltip)
        iconSlot(row, o.Icon)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-66 - iconW,0,topH),Pos=UDim2.new(0,4 + iconW,0,0)})
        local box = Instance.new("TextBox"); box.Size = UDim2.new(0,58,0,18); box.Position = UDim2.new(1,-58,0,math.floor((topH - 18) / 2))
        box.BackgroundColor3 = C.pHdr; box.BorderSizePixel = 0; box.Font = GB; box.TextSize = 11; box.TextColor3 = C.dim; box.ClearTextOnFocus = false
        box.Text = fmtNum(val, dec) .. suffix; box.Parent = row; corner(5,box)
        local bar
        bar = mkSliderBar(row, UDim2.new(0,6,0,topH + 9), UDim2.new(1,-12,0,6), ac, vmin, vmax, step, val, function(v)
            val = v; box.Text = fmtNum(v, dec) .. suffix; cfgSet(o.Flag, v)
            if o.Callback then pcall(o.Callback, v) end
        end)
        box.Focused:Connect(function() box.Text = fmtNum(val, dec); box.TextColor3 = C.txt end)
        box.FocusLost:Connect(function()
            box.TextColor3 = C.dim
            local n = tonumber(box.Text); if n then bar.Set(n, false) end
            box.Text = fmtNum(val, dec) .. suffix
        end)
        if o.Callback and had then pcall(o.Callback, val) end
        local ret = {
            Set = function(_,v) bar.Set(v, true); val = bar.Get(); box.Text = fmtNum(val, dec) .. suffix; cfgSet(o.Flag, val) end,
            Get = function() return val end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Button ----------
    function Sec:Button(o)
        o = o or {}
        local iconW = o.Icon and ICONW or 0
        local row = newRow(fitH(o.Name or "Button", 12, GB, INNER - 20 - iconW, 32, 14))
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundColor3 = C.btnBg; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        btn.Text = ""; btn.Font = GB; btn.TextSize = 12; btn.TextColor3 = C.txt; btn.Parent = row
        corner(7,btn); stroke(C.border,1,btn); hover(btn, C.btnBg, C.btnHov); tip(btn, o.Tooltip)
        iconSlot(btn, o.Icon)
        newTxt({Parent=btn,Text=o.Name or "Button",Font=GB,Size=12,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-10 - iconW,1,0),Pos=UDim2.new(0,iconW,0,0)})
        btn.MouseButton1Click:Connect(function()
            tw(btn,{BackgroundColor3 = ac},.06); task.delay(.14, function() tw(btn,{BackgroundColor3 = C.btnBg},.12) end)
            if o.Callback then pcall(o.Callback) end
        end)
        return btn
    end

    -- ---------- Input ----------
    function Sec:Input(o)
        o = o or {}
        local iconW = o.Icon and ICONW or 0
        local row = newRow(o.MultiLine and 64 or 32)
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.input; bg.BorderSizePixel = 0; bg.Parent = row; corner(7,bg); stroke(C.border,1,bg)
        tip(bg, o.Tooltip); iconSlot(bg, o.Icon)
        local box = Instance.new("TextBox"); box.Size = UDim2.new(1,-16 - iconW,1,0); box.Position = UDim2.new(0,8 + iconW,0,0); box.BackgroundTransparency = 1
        box.PlaceholderText = o.Placeholder or (o.Name or "Input"); box.PlaceholderColor3 = C.dim; box.Text = cfgGet(o.Flag, "") or ""
        box.Font = GB; box.TextSize = 12; box.TextColor3 = C.txt; box.ClearTextOnFocus = false; box.MultiLine = o.MultiLine or false; box.TextWrapped = o.MultiLine or false
        box.TextXAlignment = Enum.TextXAlignment.Left; box.Parent = bg
        box.FocusLost:Connect(function(enter)
            if enter or o.OnChange then cfgSet(o.Flag, box.Text); if o.Callback then pcall(o.Callback, box.Text) end end
        end)
        if o.OnChange then box:GetPropertyChangedSignal("Text"):Connect(function() cfgSet(o.Flag, box.Text); if o.Callback then pcall(o.Callback, box.Text) end end) end
        local ret = {Get = function() return box.Text end, Set = function(_,v) box.Text = v end}
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Dropdown (wrapped options, shows selected values, optional Search) ----------
    function Sec:Dropdown(o)
        o = o or {}
        local options = o.Options or {}; local multi = o.MultiSelect; local maxSel = o.MaxSelect or 1
        local selected = {}
        local had = cfgHas(o.Flag)
        local saved = cfgGet(o.Flag, o.Default)
        if saved then
            if type(saved) == "table" then for _,v in ipairs(saved) do selected[v] = true end
            elseif saved ~= "" then selected[saved] = true end
        end
        local baseName = o.Name or "Dropdown"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 30 - iconW
        local function labelText()
            local picked = {}
            for _,opt in ipairs(options) do if selected[opt] then picked[#picked + 1] = tostring(opt) end end
            if #picked == 0 then return baseName end
            return baseName .. ": " .. table.concat(picked, ", ")
        end
        local bgH = fitH(labelText(), 12, GB, labW, 32, 14)
        local row = newRow(bgH)
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,0,bgH); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        local lbl = newTxt({Parent=bg,Text=labelText(),Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local darr = newTxt({Parent=bg,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,28,1,0),Pos=UDim2.new(1,-28,0,0)})

        local optW = INNER - 8 - 16; local heights = {}; local total = 8
        for i,optName in ipairs(options) do heights[i] = fitH(tostring(optName), 11, GB, optW, 26, 10); total = total + heights[i] + 2 end
        if o.Search then total = total + 28 end
        local TOTAL = math.min(total, 180); local dropOpen = false
        local container = Instance.new("ScrollingFrame"); container.Size = UDim2.new(1,0,0,0); container.Position = UDim2.new(0,0,0,bgH + 4); container.BackgroundColor3 = C.pHdr
        container.BorderSizePixel = 0; container.Visible = false; container.ClipsDescendants = true; container.ScrollBarThickness = 3; container.ScrollBarImageColor3 = C.border
        container.CanvasSize = UDim2.new(0,0,0,0); container.Parent = row; corner(7,container); stroke(C.border,1,container)
        local cStack = Instance.new("UIListLayout"); cStack.SortOrder = Enum.SortOrder.LayoutOrder; cStack.Padding = UDim.new(0,2); cStack.Parent = container; pad(4,4,4,4,container)
        cStack:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.CanvasSize = UDim2.new(0,0,0,unscale(cStack.AbsoluteContentSize.Y) + 8) end)

        local optRefs = {}
        if o.Search then
            local sHold = Instance.new("Frame"); sHold.Size = UDim2.new(1,0,0,24); sHold.BackgroundTransparency = 1; sHold.LayoutOrder = 0; sHold.Parent = container
            local sBox = Instance.new("TextBox"); sBox.Size = UDim2.new(1,0,1,0); sBox.BackgroundColor3 = C.input; sBox.BorderSizePixel = 0
            sBox.PlaceholderText = "Search..."; sBox.PlaceholderColor3 = C.dim; sBox.Font = GB; sBox.TextSize = 11; sBox.TextColor3 = C.txt
            sBox.ClearTextOnFocus = false; sBox.Text = ""; sBox.Parent = sHold; corner(5,sBox); stroke(C.border,1,sBox)
            sBox:GetPropertyChangedSignal("Text"):Connect(function()
                local q = sBox.Text:lower()
                for nm,ref in pairs(optRefs) do
                    ref.opt.Visible = (q == "") or tostring(nm):lower():find(q,1,true) ~= nil
                end
            end)
        end

        local function refreshLabel()
            local t = labelText(); lbl.Text = t
            bgH = fitH(t, 12, GB, labW, 32, 14)
            bg.Size = UDim2.new(1,0,0,bgH); container.Position = UDim2.new(0,0,0,bgH + 4)
            row.Size = UDim2.new(1,0,0,dropOpen and (bgH + 4 + TOTAL) or bgH)
        end
        local function mark(ref,on) ref.mark.Visible = on; ref.label.TextColor3 = on and ac or C.txt end
        for i,optName in ipairs(options) do
            local optIcon = o.OptionIcons and o.OptionIcons[optName]
            local optIconW = optIcon and 20 or 0
            local opt = Instance.new("TextButton"); opt.Size = UDim2.new(1,0,0,heights[i]); opt.BackgroundColor3 = C.btnBg; opt.BorderSizePixel = 0; opt.AutoButtonColor = false
            opt.Text = ""; opt.Font = GB; opt.TextSize = 11; opt.TextColor3 = C.txt; opt.LayoutOrder = i; opt.Parent = container; corner(5,opt)
            if optIcon then local ic = mkIcon(opt, optIcon, 13, 5); ic.Position = UDim2.new(0,8,0,math.floor((heights[i]-13)/2)); ic.Size = UDim2.new(0,13,0,13); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
            local optLbl = newTxt({Parent=opt,Text=tostring(optName),Font=GB,Size=11,Wrap=true,Sz=UDim2.new(1,-16-optIconW,1,0),Pos=UDim2.new(0,10+optIconW,0,0)})
            local mk = Instance.new("Frame"); mk.Size = UDim2.new(0,3,0.6,0); mk.Position = UDim2.new(0,2,0.2,0); mk.BackgroundColor3 = ac; mk.BorderSizePixel = 0; mk.Parent = opt; corner(2,mk)
            optRefs[optName] = {opt = opt, mark = mk, label = optLbl}; mark(optRefs[optName], selected[optName] or false)
            hover(opt, C.btnBg, C.btnHov)
            if o.OptionTooltips then tip(opt, o.OptionTooltips[optName]) end
            opt.MouseButton1Click:Connect(function()
                if multi then
                    local cnt = 0; for _ in pairs(selected) do cnt = cnt + 1 end
                    if selected[optName] then selected[optName] = nil; mark(optRefs[optName], false)
                    elseif cnt < maxSel then selected[optName] = true; mark(optRefs[optName], true)
                    else return end
                    local sel = {}; for _,nm in ipairs(options) do if selected[nm] then sel[#sel + 1] = nm end end
                    cfgSet(o.Flag, sel); refreshLabel(); if o.Callback then pcall(o.Callback, sel) end
                else
                    for _,ref in pairs(optRefs) do mark(ref, false) end
                    selected = {}; selected[optName] = true; mark(optRefs[optName], true)
                    cfgSet(o.Flag, optName); refreshLabel(); if o.Callback then pcall(o.Callback, optName) end
                end
            end)
        end
        bg.MouseButton1Click:Connect(function()
            dropOpen = not dropOpen; container.Visible = true
            tw(container,{Size = UDim2.new(1,0,0,dropOpen and TOTAL or 0)},.2)
            tw(row,{Size = UDim2.new(1,0,0,dropOpen and (bgH + 4 + TOTAL) or bgH)},.2)
            darr.Text = dropOpen and "▲" or "▼"
            if not dropOpen then task.delay(.21, function() if not dropOpen then container.Visible = false end end) end
        end)
        if o.Callback and had then
            if multi then local sel = {}; for _,nm in ipairs(options) do if selected[nm] then sel[#sel + 1] = nm end end; pcall(o.Callback, sel)
            else for k in pairs(selected) do pcall(o.Callback, k) end end
        end
        local ret = {
            Get = function() return selected end,
            Set = function(_,v)
                selected = {}
                if type(v) == "table" then for _,x in ipairs(v) do selected[x] = true end elseif v then selected[v] = true end
                for nm,ref in pairs(optRefs) do mark(ref, selected[nm] or false) end
                refreshLabel()
            end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- ColorPicker ----------
    function Sec:ColorPicker(o)
        o = o or {}
        local had = cfgHas(o.Flag)
        local cur = cfgGet(o.Flag, o.Default or Color3.fromRGB(255,255,255))
        if type(cur) == "table" then cur = Color3.fromRGB(cur[1] or 255, cur[2] or 255, cur[3] or 255) end
        if o.Flag then JL.Flags[o.Flag] = cur end
        local name = o.Name or "Color"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 52 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(7,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local sw = Instance.new("Frame"); sw.Size = UDim2.new(0,34,0,18); sw.Position = UDim2.new(1,-44,0.5,-9); sw.BackgroundColor3 = cur; sw.BorderSizePixel = 0; sw.Parent = bg; corner(5,sw); stroke(C.border,1,sw)
        bg.MouseButton1Click:Connect(function()
            openColorPicker(parentSg, cur, function(col)
                cur = col; sw.BackgroundColor3 = col
                cfgSet(o.Flag, col, {math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255)})
                if o.Callback then pcall(o.Callback, col) end
            end)
        end)
        if o.Callback and had then pcall(o.Callback, cur) end
        local ret = {Get = function() return cur end, Set = function(_,v) cur = v; sw.BackgroundColor3 = v end}
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Keybind ----------
    function Sec:Keybind(o)
        o = o or {}
        local defName = (typeof(o.Default) == "EnumItem" and o.Default.Name) or (o.Default and tostring(o.Default)) or "None"
        local nm = cfgGet(o.Flag, defName)
        local name = o.Name or "Keybind"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 96 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.BorderSizePixel = 0; bg.Parent = row; corner(7,bg); stroke(C.border,1,bg)
        tip(bg, o.Tooltip); iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local chip = mkKeyChip(bg, UDim2.new(1,-94,0.5,-11), nm, function(k)
            cfgSet(o.Flag, k and k.Name or "None"); if o.Callback then pcall(o.Callback, k) end
        end)
        keep(UIS.InputBegan:Connect(function(i,gp)
            if gp or JL._listening then return end
            local k = chip.Get()
            if k and i.KeyCode == k and o.OnPress then pcall(o.OnPress) end
        end))
        local ret = {Get = function() return chip.Get() end, Set = function(_,k) chip.Set(k); cfgSet(o.Flag, k and k.Name or "None") end}
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Segmented ----------
    function Sec:Segmented(o)
        o = o or {}
        local opts2 = o.Options or {}; local had = cfgHas(o.Flag)
        local cur = cfgGet(o.Flag, o.Default or opts2[1])
        local nameH = o.Name and fitH(o.Name, 12, GB, INNER - 8, 16, 2) or 0
        local yOff = (nameH > 0) and (nameH + 4) or 0
        local row = newRow(yOff + 28)
        tip(row, o.Tooltip)
        if o.Name then newTxt({Parent=row,Text=o.Name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-8,0,nameH),Pos=UDim2.new(0,4,0,0)}) end
        local seg = mkSegmented(row, UDim2.new(0,0,0,yOff), UDim2.new(1,0,0,28), opts2, cur, ac, function(v)
            cfgSet(o.Flag, v); if o.Callback then pcall(o.Callback, v) end
        end)
        if o.Callback and had then pcall(o.Callback, cur) end
        local ret = {Get = seg.Get, Set = function(_,v) seg.Set(v, true); cfgSet(o.Flag, v) end}
        regFlag(o.Flag, ret, o.NoSave)
        return ret
    end

    -- ---------- Text (plain text block, no controls) ----------
    function Sec:Text(o)
        o = o or {}
        local sz = o.Size or 15
        local fnt = (o.Bold == false) and GM or GB
        local iconW = o.Icon and (ICONW + 4) or 0
        local h0 = fitH(o.Text or "", sz, fnt, INNER - 8 - iconW, 16, 6)
        local row = newRow(math.max(h0, iconW > 0 and 20 or 0))
        tip(row, o.Tooltip)
        if o.Icon then local ic = mkIcon(row,o.Icon,16,5); ic.Position = UDim2.new(0,4,0,1); ic.Size = UDim2.new(0,16,0,16); if ic:IsA("TextLabel") then ic.TextColor3 = o.Color or ac else ic.ImageColor3 = o.Color or ac end end
        local l = newTxt({Parent=row,Text=o.Text or "",Size=sz,Color=o.Color or C.txt,Wrap=true,XAlign=o.Align or Enum.TextXAlignment.Left,Sz=UDim2.new(1,-8 - iconW,1,0),Pos=UDim2.new(0,4 + iconW,0,0)})
        l.Font = fnt
        if o.RichText then l.RichText = true end
        return {Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, sz, fnt, INNER - 8 - iconW, 16, 6)) end}
    end

    -- ---------- Screen (image / decal / asset preview / player headshot) ----------
    function Sec:Screen(o)
        o = o or {}
        local h = o.Height or 120
        local yOff = 0
        local row
        if o.Name then
            row = newRow(h + 22)
            newTxt({Parent=row,Text=o.Name,Font=GB,Size=12,Sz=UDim2.new(1,-8,0,18),Pos=UDim2.new(0,4,0,0)})
            yOff = 22
        else
            row = newRow(h)
        end
        local box = Instance.new("Frame"); box.Size = UDim2.new(1,0,0,h); box.Position = UDim2.new(0,0,0,yOff); box.BackgroundColor3 = C.pHdr; box.BorderSizePixel = 0; box.ClipsDescendants = true; box.Parent = row
        corner(8,box); stroke(C.border,1,box); tip(box, o.Tooltip)
        local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,-12,1,-12); img.Position = UDim2.new(0,6,0,6); img.BackgroundTransparency = 1
        img.ScaleType = o.ScaleType or Enum.ScaleType.Fit; img.Parent = box
        local status = newTxt({Parent=box,Text="",Font=GM,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
        local function setId(id)
            local s = tostring(id)
            img.Image = s:match("^%d+$") and ("rbxassetid://" .. s) or s
        end
        local function setPlayer(plr)
            status.Text = "loading..."
            task.spawn(function()
                local userId = (typeof(plr) == "Instance") and plr.UserId or tonumber(plr)
                if not userId then status.Text = "invalid player"; return end
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, o.ThumbSize or Enum.ThumbnailSize.Size180x180)
                end)
                if ok then img.Image = content; status.Text = "" else status.Text = "failed to load" end
            end)
        end
        if o.Player then setPlayer(o.Player) elseif o.Image then setId(o.Image) end
        return {SetImage = function(_,id) setId(id) end, SetPlayer = function(_,plr) setPlayer(plr) end}
    end

    -- ---------- Label / Divider / Custom ----------
    function Sec:Label(o)
        o = o or {}
        local iconW = o.Icon and (ICONW + 2) or 0
        local h0 = fitH(o.Text or "", 11, G, INNER - 8 - iconW, 18, 4)
        local row = newRow(h0)
        tip(row, o.Tooltip)
        if o.Icon then local ic = mkIcon(row,o.Icon,13,5); ic.Position = UDim2.new(0,4,0,2); ic.Size = UDim2.new(0,13,0,13); if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end end
        local l = newTxt({Parent=row,Text=o.Text or "",Size=11,Color=o.Color or C.dim,Wrap=true,Sz=UDim2.new(1,-8 - iconW,1,0),Pos=UDim2.new(0,4 + iconW,0,0)})
        if o.RichText then l.RichText = true end
        return {Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, 11, G, INNER - 8 - iconW, 18, 4)) end}
    end
    function Sec:Divider(o)
        local row = newRow(16)
        local line = Instance.new("Frame"); line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,0.5,0); line.BackgroundColor3 = C.divLine; line.BorderSizePixel = 0; line.Parent = row
        if o and o.Label then
            local LW = math.min(#o.Label * 7 + 14, INNER)
            local bg = Instance.new("Frame"); bg.Size = UDim2.new(0,LW,0,14); bg.Position = UDim2.new(0.5,-LW/2,0.5,-7); bg.BackgroundColor3 = C.panel; bg.BorderSizePixel = 0; bg.Parent = row
            newTxt({Parent=bg,Text=o.Label,Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
        end
    end
    function Sec:Custom(height,setupFn)
        iOrd = iOrd + 1
        local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,height); f.BackgroundTransparency = 1; f.LayoutOrder = iOrd; f.ClipsDescendants = true; f.Parent = content
        if setupFn then setupFn(f) end
        return f
    end

    return Sec
end

-- ============================== section (single card) ==============================
local function makeSection(parentFrame,title,parentSg,layoutOrder,colW,so,uiScale,attachTip)
    so = so or {}
    local ac = nxAc()
    local iconW = so.Icon and 22 or 0
    local INNER = colW - 16                                   -- usable row width
    local HH = math.max(34, fitH(title, 13, GB, colW - 54 - iconW, 0, 0) + 16)   -- header grows if the title is long

    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end

    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    local pill = Instance.new("Frame"); pill.Size = UDim2.new(0,3,0,14); pill.Position = UDim2.new(0,10,0.5,-7); pill.BackgroundColor3 = ac; pill.BorderSizePixel = 0; pill.ZIndex = 3; pill.Parent = hdr; corner(2,pill)
    if so.Icon then local ic = mkIcon(hdr, so.Icon, 15, 3); ic.Position = UDim2.new(0,22,0.5,-7); ic.Size = UDim2.new(0,15,0,15); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    newTxt({Parent=hdr,Text=title,Font=GB,Size=13,Wrap=true,Sz=UDim2.new(1,-54 - iconW,1,0),Pos=UDim2.new(0,22 + iconW,0,0),Z=3})
    local arrow = newTxt({Parent=hdr,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,30,1,0),Pos=UDim2.new(1,-30,0,0),Z=3})
    local secBtn = Instance.new("TextButton"); secBtn.Size = UDim2.new(1,0,1,0); secBtn.BackgroundTransparency = 1; secBtn.Text = ""; secBtn.ZIndex = 4; secBtn.Parent = hdr
    if attachTip and so.Tooltip then attachTip(hdr, so.Tooltip) end
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel

    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,HH + 1); content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = panel
    local list = Instance.new("UIListLayout"); list.FillDirection = Enum.FillDirection.Vertical; list.Padding = UDim.new(0,6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
    pad(8,8,8,8,content)

    local collapsed = so.Collapsed or false; local storedH = 0; local animating = false
    local function fullH() return HH + 1 + storedH end
    local function updatePanel()
        local ch = list.AbsoluteContentSize.Y
        storedH = (ch > 0) and (unscale(ch) + 16) or 0
        content.Size = UDim2.new(1,0,0,storedH)
        if not collapsed and not animating then panel.Size = UDim2.new(1,0,0,fullH()) end
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanel)
    local function setCollapsed(c)
        collapsed = c; animating = true
        tw(arrow,{Rotation = c and 180 or 0},.2)
        if c then
            tw(panel,{Size = UDim2.new(1,0,0,HH)},.18)
            task.delay(.2, function() animating = false; if collapsed then content.Visible = false end end)
        else
            content.Visible = true; tw(panel,{Size = UDim2.new(1,0,0,fullH())},.18)
            task.delay(.2, function() animating = false; updatePanel() end)
        end
    end
    secBtn.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
    if collapsed then content.Visible = false; arrow.Rotation = 180 end

    local Sec = attachWidgets(content, INNER, ac, uiScale, parentSg, attachTip)
    Sec.Panel = panel
    function Sec:SetCollapsed(c) if c ~= collapsed then setCollapsed(c) end end
    return Sec
end

-- ============================== multi-section: several named pages, one card, switcher in the header ----------
-- Tab:MultiSection({Title=nil, Pages={"Camera","Effects"}, Column=...}) -> MS
-- MS:Page("Camera"):Toggle{...} / MS:SetPage("Effects") / MS:GetPage()
local function makeMultiSection(parentFrame,sopts,parentSg,layoutOrder,colW,uiScale,attachTip)
    sopts = sopts or {}
    local ac = nxAc()
    local INNER = colW - 16
    local pages = sopts.Pages or {"Page 1","Page 2"}
    local iconW = sopts.Icon and 22 or 0
    local HH = 40

    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end

    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    if sopts.Icon then local ic = mkIcon(hdr, sopts.Icon, 16, 3); ic.Position = UDim2.new(0,8,0.5,-8); ic.Size = UDim2.new(0,16,0,16); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    if attachTip and sopts.Tooltip then attachTip(hdr, sopts.Tooltip) end
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel

    local activePage = pages[1]
    local contents = {}; local storedH = {}
    local function repaint()
        panel.Size = UDim2.new(1,0,0, HH + 1 + (storedH[activePage] or 0))
        for nm,c in pairs(contents) do c.Visible = (nm == activePage) end
    end
    local switcher = mkSegmented(hdr, UDim2.new(0,8 + iconW,0,6), UDim2.new(1,-16 - iconW,0,28), pages, activePage, ac, function(v)
        activePage = v; repaint()
    end)

    local pageSecs = {}
    for _,name in ipairs(pages) do
        local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,HH + 1)
        content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Visible = (name == activePage); content.Parent = panel
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0,6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
        pad(8,8,8,8,content)
        storedH[name] = 0
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local ch = list.AbsoluteContentSize.Y
            storedH[name] = (ch > 0) and (unscale(ch) + 16) or 0
            content.Size = UDim2.new(1,0,0,storedH[name])
            if name == activePage then repaint() end
        end)
        contents[name] = content
        pageSecs[name] = attachWidgets(content, INNER, ac, uiScale, parentSg, attachTip)
    end

    local MS = {Panel = panel}
    function MS:Page(name) return pageSecs[name] end
    function MS:SetPage(name) if contents[name] and name ~= activePage then activePage = name; switcher.Set(name, true); repaint() end end
    function MS:GetPage() return activePage end
    return MS
end

-- ============================== window ==============================
function JL:Window(opts)
    opts = opts or {}
    if shared._JLActive and shared._JLActive.alive then
        local restart = confirmDialog("Hub Already Running", "A JustLib hub is already open. Restart it?")
        if not restart then return nil end
        pcall(shared._JLActive.destroy)
    end
    if opts.Config then cfgLoad(opts.Config) end

    -- ---------- config profiles (named flag snapshots) ----------
    local profFolder = opts.ConfigFolder or ((opts.Config or "JustLib") .. "_Presets")
    local function fsReady() return writefile and readfile and listfiles and isfile and delfile end
    local function ensureProfFolder()
        if isfolder and makefolder and not isfolder(profFolder) then pcall(makefolder, profFolder) end
    end
    local function listProfiles()
        local out = {}
        if not (fsReady() and isfolder and isfolder(profFolder)) then return out end
        local ok,files = pcall(listfiles, profFolder)
        if not ok then return out end
        for _,p in ipairs(files) do
            local nm = tostring(p):match("([^\\/]+)%.json$")
            if nm then out[#out + 1] = nm end
        end
        table.sort(out)
        return out
    end
    local function snapshotFlags()
        local out = {}
        for flag,val in pairs(_cfgData) do
            if not tostring(flag):match("^_") and not JL._noSave[flag] then out[flag] = val end
        end
        return out
    end
    local function saveProfile(name)
        if not fsReady() then return false end
        ensureProfFolder()
        local ok = pcall(writefile, profFolder .. "/" .. name .. ".json", HTTP:JSONEncode(snapshotFlags()))
        return ok
    end
    local function loadProfile(name)
        if not fsReady() then return false end
        local ok,raw = pcall(readfile, profFolder .. "/" .. name .. ".json")
        if not ok or not raw or raw == "" then return false end
        local ok2,data = pcall(HTTP.JSONDecode, HTTP, raw)
        if not ok2 or type(data) ~= "table" then return false end
        for flag,val in pairs(data) do
            local ctrl = JL._registry[flag]
            if ctrl and ctrl.Set then pcall(function() ctrl:Set(val) end) end
        end
        return true
    end
    local function deleteProfile(name)
        if not fsReady() then return false end
        local path = profFolder .. "/" .. name .. ".json"
        if isfile(path) then return (pcall(delfile, path)) end
        return false
    end

    local sg = Instance.new("ScreenGui"); sg.Name = "JustLib"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; sg.DisplayOrder = 999
    local ok = pcall(function() sg.Parent = game:GetService("CoreGui") end); if not ok then sg.Parent = PG end
    local _dead = false

    -- ---------- sizing (Width / Height / Columns are options) ----------
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local SBW, GAP, PADIN, COLGAP = 42, 10, 8, 8
    local CWW = math.clamp(opts.Width or 640, 340, math.max(340, vp.X - SBW - GAP - 30))
    local WH  = math.clamp(opts.Height or 420, 240, math.max(240, vp.Y - 30))
    local WW  = SBW + GAP + CWW
    local IW  = CWW - 2 * PADIN                                   -- tab inner width
    local VIS = math.clamp(opts.Columns or 3, 1, 6)                -- columns visible at once
    local usable = IW - 8
    while VIS > 1 and (usable - (VIS - 1) * COLGAP) / VIS < 150 do VIS = VIS - 1 end
    local colW = math.floor((usable - (VIS - 1) * COLGAP) / VIS)
    local listW = usable

    -- ---------- saved interface settings ----------
    local animOn    = cfgGet("_anim", true)
    local userScale = (tonumber(cfgGet("_uiscale", 100)) or 100) / 100
    local blurPct   = tonumber(cfgGet("_blur", 0)) or 0
    local backdropV = tonumber(cfgGet("_backdrop", 65)) or 65
    local hotkey    = keyFromName(cfgGet("_hotkey", opts.Hotkey and opts.Hotkey.Name or "RightShift"))
    local showFps   = cfgGet("_showfps", true)

    -- ---------- badge (sized to fit the title so nothing gets clipped) ----------
    local function measureTextW(text,size,font,maxW)
        local ok,b = pcall(function() return TextService:GetTextSize(tostring(text), size, font, Vector2.new(maxW, 30)) end)
        return ok and b.X or (#tostring(text) * (size * 0.6))
    end
    local badgeTitle = opts.Title or "JustLib"
    local badgeOffX = opts.Icon and 32 or 10
    local badgeTitleW = math.clamp(measureTextW(badgeTitle, 12, GB, 220), 30, 170)
    local badgeFpsW = 46
    local badgeW = badgeOffX + badgeTitleW + 10 + 1 + 10 + badgeFpsW + 12
    local BPOS = {
        top    = UDim2.new(0.5,-badgeW / 2,0,14),
        center = UDim2.new(0.5,-badgeW / 2,0.5,-15),
        bottom = UDim2.new(0.5,-badgeW / 2,1,-44),
    }
    local badge2 = Instance.new("Frame"); badge2.Size = UDim2.new(0,badgeW,0,30); badge2.Position = BPOS[tostring(cfgGet("_badgepos","Top")):lower()] or BPOS.top
    badge2.BackgroundColor3 = C.badge; badge2.BorderSizePixel = 0; badge2.ZIndex = 60; badge2.Parent = sg; corner(8,badge2); stroke(C.border,1,badge2)
    if opts.Icon then local ic = mkIcon(badge2,opts.Icon,18,61); ic.Position = UDim2.new(0,8,0.5,-9) end
    newTxt({Parent=badge2,Text=badgeTitle,Font=GB,Size=12,Sz=UDim2.new(0,badgeTitleW,1,0),Pos=UDim2.new(0,badgeOffX,0,0),Z=61})
    local divF = Instance.new("Frame"); divF.Size = UDim2.new(0,1,0,16); divF.Position = UDim2.new(0,badgeOffX + badgeTitleW + 10,0.5,-8); divF.BackgroundColor3 = C.border; divF.BorderSizePixel = 0; divF.ZIndex = 61; divF.Parent = badge2
    local fpsL = newTxt({Parent=badge2,Text="60 FPS",Font=GB,Size=12,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,badgeFpsW,1,0),Pos=UDim2.new(0,badgeOffX + badgeTitleW + 20,0,0),Z=61})
    fpsL.Visible = showFps
    local fpsConn
    do
        local _lt = tick(); local _fr = 0
        fpsConn = RunSvc.Heartbeat:Connect(function()
            _fr = _fr + 1; local n = tick()
            if n - _lt >= 0.5 then
                local fps = math.round(_fr / (n - _lt)); fpsL.Text = fps .. " FPS"
                fpsL.TextColor3 = fps >= 50 and C.fpsGrn or (fps >= 30 and Color3.fromRGB(255,200,72) or Color3.fromRGB(255,82,82))
                _fr = 0; _lt = n
            end
        end)
    end
    local badgeTap = Instance.new("TextButton"); badgeTap.Size = UDim2.new(1,0,1,0); badgeTap.BackgroundTransparency = 1; badgeTap.Text = ""; badgeTap.ZIndex = 62; badgeTap.Parent = badge2

    -- ---------- main frame ----------
    local win = Instance.new("Frame"); win.Size = UDim2.new(0,WW,0,WH); win.AnchorPoint = Vector2.new(0.5,0.5); win.Position = UDim2.new(0.5,0,0.5,0)
    win.BackgroundTransparency = 1; win.BorderSizePixel = 0; win.Visible = false; win.ClipsDescendants = false; win.Parent = sg
    local uiScale = Instance.new("UIScale"); uiScale.Scale = userScale; uiScale.Parent = win
    -- AbsoluteContentSize is already post-scale, so divide by uiScale before reusing it as an Offset
    local function unscaleWin(px)
        local s = uiScale.Scale; if not s or s <= 0 then s = 1 end
        return px / s
    end

    local backdrop = Instance.new("Frame"); backdrop.Size = UDim2.new(0,CWW,0,WH); backdrop.Position = UDim2.new(0,SBW + GAP,0,0)
    backdrop.BackgroundColor3 = C.backdrop; backdrop.BackgroundTransparency = (opts.Backdrop == false) and 1 or (1 - backdropV / 100); backdrop.BorderSizePixel = 0; backdrop.Parent = win
    corner(12,backdrop); local bdStroke = stroke(C.border,1,backdrop); bdStroke.Transparency = 0.35

    local sidebar = Instance.new("Frame"); sidebar.Size = UDim2.new(0,SBW,0,0); sidebar.Position = UDim2.new(0,0,0.5,0); sidebar.BackgroundColor3 = C.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = win
    corner(12,sidebar); stroke(C.border,1,sidebar)
    local sbList = Instance.new("UIListLayout"); sbList.FillDirection = Enum.FillDirection.Vertical; sbList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sbList.VerticalAlignment = Enum.VerticalAlignment.Center; sbList.Padding = UDim.new(0,8); sbList.SortOrder = Enum.SortOrder.LayoutOrder; sbList.Parent = sidebar; pad(0,0,10,10,sidebar)
    sbList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = unscaleWin(sbList.AbsoluteContentSize.Y) + 20; sidebar.Size = UDim2.new(0,SBW,0,h); sidebar.Position = UDim2.new(0,0,0.5,-h / 2)
    end)
    local content = Instance.new("Frame"); content.Size = UDim2.new(0,CWW,0,WH); content.Position = UDim2.new(0,SBW + GAP,0,0)
    content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = win

    -- generic tooltip (sidebar tab icons + Tooltip= on any widget)
    local tip = Instance.new("Frame"); tip.BackgroundColor3 = Color3.fromRGB(18,18,20); tip.BorderSizePixel = 0; tip.Visible = false; tip.ZIndex = 200; tip.Parent = win
    corner(6,tip); stroke(C.border,1,tip); pad(9,9,5,5,tip)
    local tipL = newTxt({Parent=tip,Text="",Font=GB,Size=11,Wrap=true,XAlign=Enum.TextXAlignment.Center,Z=201})
    local function showTip(guiObject,text)
        local maxW = 240
        local sz = TextService:GetTextSize(text, 11, GB, Vector2.new(maxW,200))
        local w = math.min(sz.X + 18, maxW + 18); local h = math.min(sz.Y + 10, 90)
        local rel = (guiObject.AbsolutePosition - win.AbsolutePosition) / uiScale.Scale
        local osz = guiObject.AbsoluteSize / uiScale.Scale
        local side = tostring(cfgGet("_tooltip_side","Right"))
        local x,y
        if side == "Left" then x = rel.X - w - 8; y = rel.Y + osz.Y / 2 - h / 2
        elseif side == "Top" then x = rel.X + osz.X / 2 - w / 2; y = rel.Y - h - 8
        elseif side == "Bottom" then x = rel.X + osz.X / 2 - w / 2; y = rel.Y + osz.Y + 8
        else x = rel.X + osz.X + 8; y = rel.Y + osz.Y / 2 - h / 2 end -- Right (default)
        tip.Size = UDim2.new(0,w,0,h); tip.Position = UDim2.new(0, x, 0, y); tipL.Text = text; tip.Visible = true
    end
    local function hideTip() tip.Visible = false end
    -- attach a hover tooltip to any GuiObject; safe to call with text == nil (no-op)
    local function attachTip(guiObject,text)
        if not text or text == "" then return end
        guiObject.MouseEnter:Connect(function() showTip(guiObject, text) end)
        guiObject.MouseLeave:Connect(hideTip)
    end

    -- ---------- tabs ----------
    local TABPOS = UDim2.new(0,PADIN,0,PADIN)
    local function offPos(dir) return UDim2.new(dir,PADIN,0,PADIN) end
    local tabFrames = {}; local tabUI = {}; local tabScrollers = {}; local activeTabId = nil; local _tabCount = 0
    local function styleTab(id,active)
        local u = tabUI[id]; if not u then return end
        tw(u.btn,{BackgroundColor3 = active and Color3.fromRGB(24,44,74) or Color3.fromRGB(34,34,40)},.15)
        local col = active and ACCENTS[1] or C.dim
        if u.icon:IsA("TextLabel") then u.icon.TextColor3 = col else u.icon.ImageColor3 = col end
        u.ind.Visible = active
    end
    local function switchToTab(id)
        local prev = activeTabId
        if prev == id then return end
        local dir = (prev and id > prev) and 1 or -1
        for tid,fr in pairs(tabFrames) do
            if tid == id then
                fr.Visible = true
                if prev and animOn then fr.Position = offPos(dir); tw(fr,{Position = TABPOS},.22) else fr.Position = TABPOS end
            elseif tid == prev and animOn then
                tw(fr,{Position = offPos(-dir)},.22)
                task.delay(.23, function() if activeTabId ~= tid then fr.Visible = false end end)
            else
                fr.Visible = false
            end
        end
        for tid in pairs(tabUI) do styleTab(tid, tid == id) end
        activeTabId = id
    end

    -- ---------- open / close ----------
    local blurObj
    local function applyBlur()
        if blurPct > 0 and JL._winOpen then
            if not blurObj or not blurObj.Parent then blurObj = Instance.new("BlurEffect"); blurObj.Name = "JLBlur"; blurObj.Parent = game:GetService("Lighting") end
            blurObj.Size = math.round(blurPct * 56 / 100); blurObj.Enabled = true
        elseif blurObj then blurObj.Enabled = false end
    end
    local isOpen = false
    local function openW()
        isOpen = true; JL._winOpen = true; win.Visible = true
        if animOn then uiScale.Scale = userScale * 0.88; tw(uiScale,{Scale = userScale},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out) else uiScale.Scale = userScale end
        tw(badge2,{BackgroundColor3 = C.badgeHi},.15); applyBlur()
    end
    local function closeW()
        isOpen = false; JL._winOpen = false
        if animOn then
            tw(uiScale,{Scale = userScale * 0.88},.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In)
            task.delay(.19, function() if not isOpen then win.Visible = false end end)
        else win.Visible = false end
        tw(badge2,{BackgroundColor3 = C.badge},.15); applyBlur()
    end
    draggable(badgeTap, badge2, function() if isOpen then closeW() else openW() end end)
    keep(UIS.InputBegan:Connect(function(i,gp)
        if gp or JL._listening then return end
        if hotkey and i.KeyCode == hotkey then if isOpen then closeW() else openW() end end
    end))
    -- Left Shift + mouse wheel = scroll columns sideways
    keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseWheel or not JL._winOpen or not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then return end
        local t = tabScrollers[activeTabId]; if not t then return end
        local m = UIS:GetMouseLocation(); local ap,as = content.AbsolutePosition, content.AbsoluteSize
        if m.X < ap.X or m.X > ap.X + as.X or m.Y < ap.Y or m.Y > ap.Y + as.Y then return end
        t.go(t.cur() + (i.Position.Z > 0 and -1 or 1))
    end))

    local function destroyHub()
        if _dead then return end
        _dead = true; JL._winOpen = false
        if shared._JLActive then shared._JLActive.alive = false end
        pcall(function() fpsConn:Disconnect() end)
        for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        _conns = {}
        pcall(function() if blurObj then blurObj:Destroy() end end)
        if sg and sg.Parent then sg:Destroy() end
        _cpSg = nil
    end

    local Win = {}
    function Win:Open() if not isOpen then openW() end end
    function Win:Close() if isOpen then closeW() end end
    function Win:Toggle() if isOpen then closeW() else openW() end end
    function Win:Destroy() destroyHub() end
    function Win:Notify(c) return JL:Notify(c) end

    function Win:Tab(topts)
        topts = topts or {}; local typ = topts.Type or "Grid"; _tabCount = _tabCount + 1; local id = _tabCount
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0,30,0,30); btn.BackgroundColor3 = Color3.fromRGB(34,34,40); btn.Text = ""; btn.AutoButtonColor = false
        btn.BorderSizePixel = 0; btn.LayoutOrder = id; btn.Parent = sidebar; corner(8,btn)
        local ic = mkIcon(btn, topts.Icon or "◼", 16, 14); ic.Position = UDim2.new(0.5,-8,0.5,-8); ic.Size = UDim2.new(0,16,0,16)
        if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end
        local ind = Instance.new("Frame"); ind.Size = UDim2.new(0,3,0,14); ind.Position = UDim2.new(0,-5,0.5,-7); ind.BackgroundColor3 = ACCENTS[1]; ind.BorderSizePixel = 0; ind.Visible = false; ind.Parent = btn; corner(2,ind)
        tabUI[id] = {btn = btn, icon = ic, ind = ind}
        attachTip(btn, topts.Tooltip or topts.Name)
        local tabFrame = Instance.new("Frame"); tabFrame.Size = UDim2.new(1,-2 * PADIN,1,-2 * PADIN); tabFrame.Position = TABPOS
        tabFrame.BackgroundTransparency = 1; tabFrame.Visible = false; tabFrame.Parent = content
        tabFrames[id] = tabFrame
        btn.MouseButton1Click:Connect(function() switchToTab(id) end)
        if not activeTabId then activeTabId = id; tabFrame.Visible = true; styleTab(id,true) end

        local Tab = {Frame = tabFrame, Id = id}
        local function mkScroll(dir)
            local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
            sc.ScrollBarThickness = 4; sc.ScrollBarImageColor3 = ACCENTS[1]; sc.CanvasSize = UDim2.new(0,0,0,0); sc.ScrollingDirection = dir; sc.Parent = tabFrame
            return sc
        end

        if typ == "Grid" then
            local scroll = mkScroll(Enum.ScrollingDirection.XY)
            local colCon = Instance.new("Frame"); colCon.Size = UDim2.new(0,0,0,0); colCon.BackgroundTransparency = 1; colCon.Parent = scroll
            local cols = {}; local ncols = 0; local secCount = {}
            -- pager: PAGES of VIS columns each (page 1 = columns 1..VIS, page 2 = VIS+1..2*VIS, ...)
            -- not shown unless there's more than one page
            local pager = Instance.new("Frame"); pager.Size = UDim2.new(1,0,0,24); pager.Position = UDim2.new(0,0,1,-24); pager.BackgroundTransparency = 1; pager.Visible = false; pager.Parent = tabFrame
            local pl = Instance.new("UIListLayout"); pl.FillDirection = Enum.FillDirection.Horizontal; pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
            pl.VerticalAlignment = Enum.VerticalAlignment.Center; pl.Padding = UDim.new(0,4); pl.SortOrder = Enum.SortOrder.LayoutOrder; pl.Parent = pager
            local chips = {}
            local function curCol() return math.floor(scroll.CanvasPosition.X / (colW + COLGAP) + 0.5) + 1 end
            local function curPage() return math.floor((curCol() - 1) / VIS) + 1 end
            local function numPages() return math.max(1, math.ceil(ncols / VIS)) end
            local function goCol(i)
                i = math.clamp(i, 1, math.max(1, ncols - VIS + 1))
                TS:Create(scroll, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new((i - 1) * (colW + COLGAP), scroll.CanvasPosition.Y)}):Play()
            end
            local function goPage(p)
                p = math.clamp(p, 1, numPages())
                goCol((p - 1) * VIS + 1)
            end
            local function paintChips()
                local p = curPage()
                for i,ch in ipairs(chips) do
                    local on = (i == p)
                    ch.BackgroundColor3 = on and ACCENTS[1] or C.btnBg; ch.TextColor3 = on and Color3.new(1,1,1) or C.dim
                end
            end
            local function mkChip(txt,order,fn)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(0,24,0,18); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = txt; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.dim; b.LayoutOrder = order; b.Parent = pager; corner(5,b)
                b.MouseButton1Click:Connect(fn); return b
            end
            local function rebuildPager()
                for _,c in ipairs(pager:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                chips = {}
                local np = numPages()
                local need = ncols > VIS
                pager.Visible = need
                scroll.Size = need and UDim2.new(1,0,1,-28) or UDim2.new(1,0,1,0)
                if not need then return end
                mkChip("‹", 0, function() goPage(curPage() - 1) end)
                for i = 1,np do chips[i] = mkChip(tostring(i), i, function() goPage(i) end) end
                mkChip("›", np + 1, function() goPage(curPage() + 1) end)
                paintChips()
            end
            scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(paintChips)
            tabScrollers[id] = {cur = curCol, go = goCol}

            local function relayout()
                local mH = 0
                for i = 1,ncols do
                    local hh = unscaleWin(cols[i].L.AbsoluteContentSize.Y)
                    cols[i].F.Size = UDim2.new(0,colW,0,hh); if hh > mH then mH = hh end
                end
                local total = ncols * colW + math.max(ncols - 1, 0) * COLGAP
                colCon.Size = UDim2.new(0,total,0,mH)
                scroll.CanvasSize = UDim2.new(0, (ncols > VIS) and (total + 8) or 0, 0, mH + 10)
            end
            local function getCol(i)
                while ncols < i do
                    ncols = ncols + 1; local k = ncols
                    local f = Instance.new("Frame"); f.Size = UDim2.new(0,colW,0,0); f.Position = UDim2.new(0,(k - 1) * (colW + COLGAP),0,0); f.BackgroundTransparency = 1; f.Parent = colCon
                    local L = Instance.new("UIListLayout"); L.FillDirection = Enum.FillDirection.Vertical; L.Padding = UDim.new(0,8); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Parent = f
                    L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(relayout)
                    cols[k] = {F = f, L = L}
                    rebuildPager()
                end
                relayout()
                return cols[i]
            end
            local NAMES = {left = 1, mid = 2, middle = 2, center = 2, right = 3}
            local function resolveCol(c)
                if type(c) == "number" then return math.max(1, math.floor(c)) end
                if type(c) == "string" then return NAMES[c:lower()] or tonumber(c) or 1 end
                local best,bc = 1,math.huge          -- no Column given: put it in the emptiest visible column
                for i = 1,VIS do local n = secCount[i] or 0; if n < bc then best = i; bc = n end end
                return best
            end
            function Tab:Section(sopts)
                sopts = sopts or {}
                local ci = resolveCol(sopts.Column)
                secCount[ci] = (secCount[ci] or 0) + 1
                return makeSection(getCol(ci).F, sopts.Title or "Section", sg, secCount[ci], colW, sopts, uiScale, attachTip)
            end
            function Tab:MultiSection(sopts)
                sopts = sopts or {}
                local ci = resolveCol(sopts.Column)
                secCount[ci] = (secCount[ci] or 0) + 1
                return makeMultiSection(getCol(ci).F, sopts, sg, secCount[ci], colW, uiScale, attachTip)
            end
            for i = 1,VIS do getCol(i) end
        elseif typ == "Custom" then
            -- empty canvas (tabFrame): used by the Settings page
        else
            local scroll = mkScroll(Enum.ScrollingDirection.Y)
            local listCon = Instance.new("Frame"); listCon.Size = UDim2.new(0,listW,0,0); listCon.BackgroundTransparency = 1; listCon.Parent = scroll
            local listL = Instance.new("UIListLayout"); listL.FillDirection = Enum.FillDirection.Vertical; listL.Padding = UDim.new(0,8); listL.SortOrder = Enum.SortOrder.LayoutOrder; listL.Parent = listCon
            listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                local h = listL.AbsoluteContentSize.Y
                listCon.Size = UDim2.new(0,listW,0,h); scroll.CanvasSize = UDim2.new(0,0,0,h + 10)
            end)
            local _sOrd = 0
            function Tab:Section(sopts)
                sopts = sopts or {}; _sOrd = _sOrd + 1
                return makeSection(listCon, sopts.Title or "Section", sg, _sOrd, listW, sopts, uiScale, attachTip)
            end
            function Tab:MultiSection(sopts)
                sopts = sopts or {}; _sOrd = _sOrd + 1
                return makeMultiSection(listCon, sopts, sg, _sOrd, listW, uiScale, attachTip)
            end
        end
        return Tab
    end

    -- ============================== SETTINGS (two-pane) ==============================
    function Win:Settings()
        if opts.Settings == false then return nil end
        local sTab = self:Tab({Icon = "⚙", Type = "Custom", Name = "Settings"})
        local root = sTab.Frame
        local ACC = ACCENTS[1]
        local navW = 146
        local PW = IW - navW - 8

        -- left navigation card
        local nav = Instance.new("Frame"); nav.Size = UDim2.new(0,navW,1,0); nav.BackgroundColor3 = C.panel; nav.BorderSizePixel = 0; nav.Parent = root; corner(10,nav); stroke(C.border,1,nav)
        newTxt({Parent=nav,Text=opts.Title or "JustLib",Font=GB,Size=15,Sz=UDim2.new(1,-28,0,20),Pos=UDim2.new(0,14,0,14)})
        newTxt({Parent=nav,Text="Settings · v" .. JL.Version,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-28,0,14),Pos=UDim2.new(0,14,0,35)})
        local nl = Instance.new("Frame"); nl.Size = UDim2.new(1,-28,0,1); nl.Position = UDim2.new(0,14,0,58); nl.BackgroundColor3 = C.divLine; nl.BackgroundTransparency = 0.4; nl.BorderSizePixel = 0; nl.Parent = nav
        local navList = Instance.new("Frame"); navList.Size = UDim2.new(1,-16,1,-74); navList.Position = UDim2.new(0,8,0,68); navList.BackgroundTransparency = 1; navList.Parent = nav
        local nlay = Instance.new("UIListLayout"); nlay.Padding = UDim.new(0,4); nlay.SortOrder = Enum.SortOrder.LayoutOrder; nlay.Parent = navList

        -- right page card
        local card = Instance.new("Frame"); card.Size = UDim2.new(1,-(navW + 8),1,0); card.Position = UDim2.new(0,navW + 8,0,0); card.BackgroundColor3 = C.panel; card.BorderSizePixel = 0; card.Parent = root; corner(10,card); stroke(C.border,1,card)
        local pgTitle = newTxt({Parent=card,Text="",Font=GB,Size=16,Sz=UDim2.new(1,-32,0,20),Pos=UDim2.new(0,16,0,12)})
        local pgSub = newTxt({Parent=card,Text="",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-32,0,14),Pos=UDim2.new(0,16,0,34)})
        local cl = Instance.new("Frame"); cl.Size = UDim2.new(1,-32,0,1); cl.Position = UDim2.new(0,16,0,56); cl.BackgroundColor3 = C.divLine; cl.BackgroundTransparency = 0.4; cl.BorderSizePixel = 0; cl.Parent = card
        local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,1,-60); holder.Position = UDim2.new(0,0,0,60); holder.BackgroundTransparency = 1; holder.ClipsDescendants = true; holder.Parent = card

        local pages = {}; local pOrd = 0
        local function showPage(name)
            for n,p in pairs(pages) do
                local on = (n == name)
                p.sf.Visible = on; p.bar.Visible = on
                p.btn.BackgroundTransparency = on and 0.86 or 1; p.lbl.TextColor3 = on and ACC or C.dim
            end
            pgTitle.Text = name; pgSub.Text = pages[name].sub
        end
        local function newPage(name,sub)
            pOrd = pOrd + 1
            local sf = Instance.new("ScrollingFrame"); sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.ScrollBarThickness = 3
            sf.ScrollBarImageColor3 = ACC; sf.CanvasSize = UDim2.new(0,0,0,0); sf.Visible = false; sf.Parent = holder
            local L = Instance.new("UIListLayout"); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Parent = sf
            L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0,0,0,unscaleWin(L.AbsoluteContentSize.Y) + 8) end)
            local nb = Instance.new("TextButton"); nb.Size = UDim2.new(1,0,0,32); nb.BackgroundColor3 = ACC; nb.BackgroundTransparency = 1; nb.BorderSizePixel = 0; nb.AutoButtonColor = false
            nb.Text = ""; nb.LayoutOrder = pOrd; nb.Parent = navList; corner(7,nb)
            local lbl = newTxt({Parent=nb,Text=name,Font=GB,Size=12,Color=C.dim,Sz=UDim2.new(1,-20,1,0),Pos=UDim2.new(0,14,0,0)})
            local bar = Instance.new("Frame"); bar.Size = UDim2.new(0,3,0,16); bar.Position = UDim2.new(0,0,0.5,-8); bar.BackgroundColor3 = ACC; bar.BorderSizePixel = 0; bar.Visible = false; bar.Parent = nb; corner(2,bar)
            pages[name] = {sf = sf, btn = nb, lbl = lbl, bar = bar, sub = sub}
            nb.MouseButton1Click:Connect(function() showPage(name) end)
            return sf
        end

        -- one setting = label/description on the left, control on the right
        local rowOrd = 0
        local function mkRow(sf,title,desc,ctrlW)
            rowOrd = rowOrd + 1
            local labW = PW - 32 - ctrlW - 14
            local th = fitH(title, 13, GB, labW, 0, 0); local dh = desc and fitH(desc, 10, GM, labW, 0, 0) or 0
            local h = math.max(48, th + dh + (desc and 24 or 22))
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,h); row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.LayoutOrder = rowOrd; row.Parent = sf
            newTxt({Parent=row,Text=title,Font=GB,Size=13,Wrap=true,Sz=UDim2.new(0,labW,0,th),Pos=UDim2.new(0,16,0,desc and 10 or math.floor((h - th) / 2))})
            if desc then newTxt({Parent=row,Text=desc,Font=GM,Size=10,Color=C.dim,Wrap=true,Sz=UDim2.new(0,labW,0,dh),Pos=UDim2.new(0,16,0,10 + th + 3)}) end
            local sep = Instance.new("Frame"); sep.Size = UDim2.new(1,-32,0,1); sep.Position = UDim2.new(0,16,1,-1); sep.BackgroundColor3 = C.divLine; sep.BackgroundTransparency = 0.6; sep.BorderSizePixel = 0; sep.Parent = row
            local ctrl = Instance.new("Frame"); ctrl.Size = UDim2.new(0,ctrlW,0,28); ctrl.AnchorPoint = Vector2.new(1,0.5); ctrl.Position = UDim2.new(1,-16,0.5,0); ctrl.BackgroundTransparency = 1; ctrl.Parent = row
            return row, ctrl
        end
        local resetters = {}
        local function addSwitch(sf,title,desc,flag,default,onChange)
            local _,ctrl = mkRow(sf, title, desc, 34)
            local state = cfgGet(flag, default)
            local sw = mkSwitch(ctrl, UDim2.new(0,0,0.5,-9), state, ACC)
            local hit = Instance.new("TextButton"); hit.Size = UDim2.new(1,0,1,0); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Parent = ctrl
            hit.MouseButton1Click:Connect(function() state = not state; sw.Set(state); cfgSet(flag, state); onChange(state) end)
            resetters[#resetters + 1] = function() state = default; sw.Set(state); cfgSet(flag, state); onChange(state) end
        end
        local function addSlider(sf,title,desc,flag,default,vmin,vmax,step,suffix,onChange)
            local _,ctrl = mkRow(sf, title, desc, 210)
            local cur = tonumber(cfgGet(flag, default)) or default
            local vl = newTxt({Parent=ctrl,Text=fmtNum(cur,0) .. suffix,Font=GB,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,46,1,0),Pos=UDim2.new(1,-46,0,0)})
            local bar = mkSliderBar(ctrl, UDim2.new(0,7,0.5,-3), UDim2.new(1,-68,0,6), ACC, vmin, vmax, step, cur, function(v)
                vl.Text = fmtNum(v,0) .. suffix; cfgSet(flag, v); onChange(v)
            end)
            resetters[#resetters + 1] = function() bar.Set(default, true); vl.Text = fmtNum(default,0) .. suffix; cfgSet(flag, default); onChange(default) end
        end
        local function addButton(sf,title,desc,text,danger,fn)
            local _,ctrl = mkRow(sf, title, desc, 100)
            local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,1,0); b.BackgroundColor3 = danger and C.danger or C.btnBg; b.BorderSizePixel = 0; b.Text = text
            b.Font = GB; b.TextSize = 12; b.TextColor3 = Color3.new(1,1,1); b.Parent = ctrl; corner(7,b)
            if not danger then stroke(C.border,1,b) end
            b.MouseButton1Click:Connect(fn)
        end
        local function addValue(sf,title,desc,text)
            local _,ctrl = mkRow(sf, title, desc, 170)
            newTxt({Parent=ctrl,Text=text,Font=GB,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Right})
        end

        -- ---- Appearance ----
        local pA = newPage("Appearance", "Look and feel of the hub")
        addSlider(pA, "UI Scale", "Enlarges or shrinks the whole window", "_uiscale", 100, 70, 130, 5, "%", function(v)
            userScale = v / 100; uiScale.Scale = userScale
        end)
        addSlider(pA, "Background Blur", "Blurs the game behind the hub while it is open", "_blur", 0, 0, 100, 1, "%", function(v)
            blurPct = v; applyBlur()
        end)
        addSlider(pA, "Window Backdrop", "Opacity of the dark panel behind the sections", "_backdrop", 65, 0, 100, 1, "%", function(v)
            backdropV = v; if opts.Backdrop ~= false then backdrop.BackgroundTransparency = 1 - v / 100 end
        end)
        addSwitch(pA, "Show FPS", "FPS counter on the badge", "_showfps", true, function(v) fpsL.Visible = v end)
        addSwitch(pA, "Animations", "Tab slide and open/close animations", "_anim", true, function(v) animOn = v end)

        -- ---- Interface ----
        local pI = newPage("Interface", "Controls and badge")
        do
            local _,ctrl = mkRow(pI, "Menu Key", "Click, then press a key. Esc cancels, Backspace clears", 84)
            local chip = mkKeyChip(ctrl, UDim2.new(0,0,0.5,-11), hotkey and hotkey.Name or "None", function(k)
                hotkey = k; cfgSet("_hotkey", k and k.Name or "None")
            end)
            resetters[#resetters + 1] = function() local k = keyFromName(opts.Hotkey and opts.Hotkey.Name or "RightShift"); hotkey = k; chip.Set(k); cfgSet("_hotkey", k and k.Name or "None") end
        end
        do
            local _,ctrl = mkRow(pI, "Badge Position", "Where the small FPS badge sits on screen", 190)
            local function apply(name) local p = BPOS[name:lower()]; if p then tw(badge2,{Position = p},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end; cfgSet("_badgepos", name) end
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"Top","Center","Bottom"}, tostring(cfgGet("_badgepos","Top")), ACC, apply)
            resetters[#resetters + 1] = function() seg.Set("Top", true); apply("Top") end
        end
        do
            local _,ctrl = mkRow(pI, "Tooltip Position", "Which side of a control its hover tooltip appears on", 260)
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"Top","Bottom","Left","Right"}, tostring(cfgGet("_tooltip_side","Right")), ACC, function(v)
                cfgSet("_tooltip_side", v)
            end)
            resetters[#resetters + 1] = function() seg.Set("Right", true); cfgSet("_tooltip_side","Right") end
        end

        -- ---- Notifications ----
        local pN = newPage("Notifications", "What shows, where, and for how long")
        addSwitch(pN, "Show Regular", "Info / success notifications", "_notify_show_regular", true, function() end)
        addSwitch(pN, "Show Warnings", "Yellow warning notifications", "_notify_show_warning", true, function() end)
        addSwitch(pN, "Show Errors", "Red error notifications", "_notify_show_error", true, function() end)
        addSlider(pN, "Default Duration", "How long a notification stays, unless it sets its own Duration", "_notify_duration", 5, 2, 15, 1, "s", function() end)
        do
            local _,ctrl = mkRow(pN, "Notify Side", "Which corner of the screen notifications appear in", 260)
            local seg = mkSegmented(ctrl, UDim2.new(0,0,0,0), UDim2.new(1,0,1,0), {"TopLeft","TopRight","BottomLeft","BottomRight"}, tostring(cfgGet("_notify_side","TopRight")), ACC, function(v)
                cfgSet("_notify_side", v); if JL._notifyReposition then JL._notifyReposition() end
            end)
            resetters[#resetters + 1] = function() seg.Set("TopRight", true); cfgSet("_notify_side","TopRight"); if JL._notifyReposition then JL._notifyReposition() end end
        end
        addSwitch(pN, "Notify Stack", "Repeated notifications with the same text pile into one, shown as x1, x2...", "_notify_stack", false, function() end)
        addButton(pN, "Test Notification", "Sends a sample notification with your current settings", "Send", false, function()
            JL:Notify({Title = "Test Notification", Desc = "This is what your notifications look like.", Type = "Info"})
        end)

        -- ---- Presets ----
        local pP = newPage("Presets", "Save and load snapshots of your enabled features")
        local profileNameBox
        do
            local _,ctrl = mkRow(pP, "Preset Name", "Used by \"Save As New\" below", 180)
            profileNameBox = Instance.new("TextBox"); profileNameBox.Size = UDim2.new(1,0,0,26); profileNameBox.BackgroundColor3 = C.pHdr
            profileNameBox.BorderSizePixel = 0; profileNameBox.Font = GB; profileNameBox.TextSize = 12; profileNameBox.TextColor3 = C.txt
            profileNameBox.PlaceholderText = "my-preset"; profileNameBox.PlaceholderColor3 = C.dim; profileNameBox.ClearTextOnFocus = false
            profileNameBox.Text = ""; profileNameBox.Parent = ctrl; corner(6,profileNameBox); stroke(C.border,1,profileNameBox)
        end

        rowOrd = rowOrd + 1
        local selRow = Instance.new("Frame"); selRow.Size = UDim2.new(1,0,0,48); selRow.BackgroundTransparency = 1; selRow.LayoutOrder = rowOrd; selRow.Parent = pP
        newTxt({Parent=selRow,Text="Saved Presets",Font=GB,Size=13,Sz=UDim2.new(0,PW - 220,0,20),Pos=UDim2.new(0,16,0,14)})
        local selCtrl = Instance.new("Frame"); selCtrl.Size = UDim2.new(0,170,0,26); selCtrl.Position = UDim2.new(1,-186,0,11); selCtrl.BackgroundTransparency = 1; selCtrl.Parent = selRow
        local selBtn = Instance.new("TextButton"); selBtn.Size = UDim2.new(1,0,1,0); selBtn.BackgroundColor3 = C.btnBg; selBtn.AutoButtonColor = false; selBtn.BorderSizePixel = 0; selBtn.Text = ""; selBtn.Parent = selCtrl; corner(6,selBtn); stroke(C.border,1,selBtn)
        local selLbl = newTxt({Parent=selBtn,Text="— none —",Font=GB,Size=11,Sz=UDim2.new(1,-24,1,0),Pos=UDim2.new(0,8,0,0)})
        local selArr = newTxt({Parent=selBtn,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,20,1,0),Pos=UDim2.new(1,-20,0,0)})
        local sep2 = Instance.new("Frame"); sep2.Size = UDim2.new(1,-32,0,1); sep2.Position = UDim2.new(0,16,1,-1); sep2.BackgroundColor3 = C.divLine; sep2.BackgroundTransparency = 0.6; sep2.BorderSizePixel = 0; sep2.Parent = selRow

        local list2 = Instance.new("ScrollingFrame"); list2.Size = UDim2.new(1,-32,0,0); list2.Position = UDim2.new(0,16,0,44); list2.BackgroundColor3 = C.pHdr; list2.BorderSizePixel = 0
        list2.ClipsDescendants = true; list2.ScrollBarThickness = 3; list2.ScrollBarImageColor3 = C.border; list2.CanvasSize = UDim2.new(0,0,0,0); list2.Visible = false; list2.Parent = selRow; corner(6,list2); stroke(C.border,1,list2)
        local lay2 = Instance.new("UIListLayout"); lay2.SortOrder = Enum.SortOrder.LayoutOrder; lay2.Padding = UDim.new(0,2); lay2.Parent = list2; pad(4,4,4,4,list2)
        lay2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() list2.CanvasSize = UDim2.new(0,0,0,unscaleWin(lay2.AbsoluteContentSize.Y) + 8) end)

        local selectedProfile = (tostring(cfgGet("_autoload_name","")) ~= "") and cfgGet("_autoload_name","") or nil
        local open2 = false
        local function closeList2()
            open2 = false; selArr.Text = "▼"
            tw(list2,{Size = UDim2.new(1,-32,0,0)},.15); selRow.Size = UDim2.new(1,0,0,48)
            task.delay(.16, function() if not open2 then list2.Visible = false end end)
        end
        local function refreshProfiles()
            for _,c in ipairs(list2:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            local names = listProfiles()
            if selectedProfile and not table.find(names, selectedProfile) then selectedProfile = nil end
            selLbl.Text = selectedProfile or "— none —"
            for i,nm in ipairs(names) do
                local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,24); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = nm; b.Font = GB; b.TextSize = 11; b.TextColor3 = (nm == selectedProfile) and ACC or C.txt; b.LayoutOrder = i; b.Parent = list2; corner(5,b)
                b.MouseEnter:Connect(function() tw(b,{BackgroundColor3 = C.btnHov},.1) end)
                b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.1) end)
                b.MouseButton1Click:Connect(function() selectedProfile = nm; selLbl.Text = nm; closeList2() end)
            end
        end
        selBtn.MouseButton1Click:Connect(function()
            open2 = not open2
            if open2 then
                refreshProfiles(); list2.Visible = true
                local h = math.min(#listProfiles() * 26 + 8, 130)
                selArr.Text = "▲"; tw(list2,{Size = UDim2.new(1,-32,0,h)},.18); selRow.Size = UDim2.new(1,0,0,48 + 4 + h)
            else closeList2() end
        end)
        refreshProfiles()

        addButton(pP, "Save As New", "Saves your currently enabled features under the name typed above", "Save", false, function()
            local nm = profileNameBox.Text:gsub("^%s+",""):gsub("%s+$","")
            if nm == "" then JL:Notify({Title = "Presets", Desc = "Type a name first", Type = "Warn", Duration = 3}); return end
            if saveProfile(nm) then
                JL:Notify({Title = "Preset Saved", Desc = "Saved \"" .. nm .. "\"", Type = "Success", Duration = 3})
                selectedProfile = nm; refreshProfiles()
            else
                JL:Notify({Title = "Presets", Desc = "Could not save — unsupported executor", Type = "Error", Duration = 4})
            end
        end)
        addButton(pP, "Load Selected", "Applies the selected preset's toggles immediately", "Load", false, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            if loadProfile(selectedProfile) then
                JL:Notify({Title = "Preset Loaded", Desc = "Applied \"" .. selectedProfile .. "\"", Type = "Success", Duration = 3})
            else
                JL:Notify({Title = "Presets", Desc = "Could not load that preset", Type = "Error", Duration = 4})
            end
        end)
        addButton(pP, "Rewrite Selected", "Overwrites the selected preset with your current toggles", "Rewrite", false, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            if saveProfile(selectedProfile) then
                JL:Notify({Title = "Preset Rewritten", Desc = "\"" .. selectedProfile .. "\" updated", Type = "Success", Duration = 3})
            end
        end)
        addButton(pP, "Delete Selected", "Permanently deletes the selected preset", "Delete", true, function()
            if not selectedProfile then JL:Notify({Title = "Presets", Desc = "Pick a preset first", Type = "Warn", Duration = 3}); return end
            local nm = selectedProfile
            if confirmDialog("Delete Preset", "Permanently delete \"" .. nm .. "\"?", {Danger = true, ConfirmText = "Delete", CancelText = "Cancel"}) then
                deleteProfile(nm)
                if cfgGet("_autoload_name","") == nm then cfgSet("_autoload_name","") end
                selectedProfile = nil; refreshProfiles()
            end
        end)
        addSwitch(pP, "Auto Load On Start", "Loads the selected preset automatically every time the hub starts", "_autoload", false, function(v)
            if v then
                if not selectedProfile then
                    JL:Notify({Title = "Presets", Desc = "Pick a preset to auto-load first", Type = "Warn", Duration = 3})
                end
                cfgSet("_autoload_name", selectedProfile or "")
            end
        end)

        -- ---- Backup ----
        local pC = newPage("Backup", "The auto-saved interface & flag file")
        addValue(pC, "Config file", "Everything here auto-saves as you use the hub", _cfgFile or "not set (nothing is saved)")
        addButton(pC, "Copy config", "Copies the saved settings as JSON to the clipboard", "Copy", false, function()
            if setclipboard then
                setclipboard(HTTP:JSONEncode(_cfgData)); JL:Notify({Title = "Config", Desc = "Copied to clipboard", Type = "Success", Duration = 3})
            else JL:Notify({Title = "Config", Desc = "Clipboard is not supported by your executor", Type = "Error", Duration = 4}) end
        end)
        addButton(pC, "Reset interface", "Restores every setting on the Appearance and Interface pages", "Reset", true, function()
            if confirmDialog("Reset Settings", "Restore all interface settings to their defaults?", {Danger = true, ConfirmText = "Reset"}) then
                for _,fn in ipairs(resetters) do pcall(fn) end
            end
        end)

        -- ---- About ----
        local pB = newPage("About", "JustLib")
        addValue(pB, "Version", nil, "JustLib v" .. JL.Version)
        addValue(pB, "Tabs loaded", nil, tostring(_tabCount))
        addValue(pB, "Columns", "Visible at once. Left Shift + wheel scrolls sideways", tostring(VIS))
        addButton(pB, "Close Hub", "Fully unloads the hub", "Unload", true, function()
            if confirmDialog("Close Hub", "Are you sure you want to close the hub? This will fully unload it.", {Danger = true, ConfirmText = "Unload"}) then destroyHub() end
        end)

        showPage("Appearance")
        return sTab
    end

    -- fires after this script finishes building the UI, so Flags are registered
    task.defer(function()
        if _dead then return end
        if cfgGet("_autoload", false) then
            local nm = cfgGet("_autoload_name", "")
            if nm and nm ~= "" then pcall(loadProfile, nm) end
        end
    end)

    shared._JLActive = {alive = true, destroy = destroyHub}
    return Win
end
return JL
