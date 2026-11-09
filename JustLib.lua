local JL = {}; JL.Flags = {}; JL._winOpen = false; JL._listening = false; JL.Version = "4.4.10"
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

-- ===== Styles (Old / New / ...) =====
-- Тема = цвета. Стиль = геометрия, структура и эффекты.
-- Активный стиль лежит в ST (токены + хуки). Old = пустая таблица: все токены берутся из значений по умолчанию в коде.
-- Стиль применяется при создании окна (Restart Hub), как SidebarLabels.
JL._styles = { Old = {} }
JL._styleName = "Old"
local ST = {}
JL._st = ST
local function useStyle(name)
    local def = JL._styles[name]
    if type(def) ~= "table" then return false end
    for k in pairs(ST) do ST[k] = nil end
    for k,v in pairs(def) do ST[k] = v end
    JL._styleName = name
    return true
end
function JL:RegisterStyle(name, def)
    if type(name) ~= "string" or type(def) ~= "table" then return false end
    JL._styles[name] = def
    return true
end
function JL:GetStyle() return JL._styleName end
function JL:GetStyles()
    local out = {"Old"}
    for k in pairs(JL._styles) do if k ~= "Old" then out[#out + 1] = k end end
    table.sort(out, function(a,b)
        if a == "Old" then return true elseif b == "Old" then return false end
        return a < b
    end)
    return out
end
function JL:LoadStyle(name, url)
    local ok,res = pcall(function()
        local src = game:HttpGet(url)
        local chunk = assert(loadstring(src))
        local def = chunk()
        if type(def) == "function" then def = def(JL) end
        return def
    end)
    if ok and type(res) == "table" then JL._styles[name] = res; return true end
    warn("[JustLib] LoadStyle failed (" .. tostring(name) .. "): " .. tostring(res))
    return false
end
function JL:SetStyle(name)
    if not JL._styles[name] then return false end
    JL._userStyle = name
    pcall(function() if JL._activeCfgSet then JL._activeCfgSet("_style", name) end end)
    return true -- применится при следующем создании окна (Restart Hub)
end
local _conns = {}
local _resources = {}
local _threads = {}
local _disposed = false
local function cleanupResource(resource, cleanup)
    pcall(function()
        if cleanup then cleanup(resource); return end
        local kind = typeof(resource)
        if kind == "RBXScriptConnection" then resource:Disconnect()
        elseif kind == "Instance" then resource:Destroy()
        elseif kind == "thread" then task.cancel(resource)
        elseif type(resource) == "function" then resource()
        elseif type(resource) == "table" then
            if resource.Destroy then resource:Destroy()
            elseif resource.Disconnect then resource:Disconnect()
            elseif resource.Cancel then resource:Cancel() end
        end
    end)
end
local function trackedRunner(record, callback)
    return function(...)
        if _disposed then _threads[record] = nil; return end
        local result = table.pack(pcall(callback, ...))
        _threads[record] = nil
        if not result[1] then error(result[2], 0) end
        return table.unpack(result, 2, result.n)
    end
end
local function trackedSpawn(callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.spawn(trackedRunner(record, callback), ...)
    return record.thread
end
local function trackedDelay(seconds, callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.delay(seconds, trackedRunner(record, callback), ...)
    return record.thread
end
local function trackedDefer(callback, ...)
    if _disposed then return nil end
    local record = {}; _threads[record] = true
    record.thread = task.defer(trackedRunner(record, callback), ...)
    return record.thread
end
local function cleanupResources()
    for record in pairs(_tweens) do
        _tweens[record] = nil
        if record.connection then pcall(function() record.connection:Disconnect() end) end
        if record.tween then
            pcall(function() record.tween:Cancel() end)
            pcall(function() record.tween:Destroy() end)
        end
    end
    for record in pairs(_threads) do
        if record.thread then pcall(task.cancel, record.thread) end
        _threads[record] = nil
    end
    for i = #_resources, 1, -1 do
        local item = _resources[i]
        _resources[i] = nil
        if item then pcall(cleanupResource, item.resource, item.cleanup) end
    end
end
local function keep(c) if c then _conns[#_conns + 1] = c end; return c end
function JL:Track(resource, cleanup)
    if resource == nil then return nil end
    if _disposed then cleanupResource(resource, cleanup); return resource end
    _resources[#_resources + 1] = {resource = resource, cleanup = cleanup}
    return resource
end
function JL:Connect(signal, callback)
    if _disposed then return nil end
    return keep(signal:Connect(callback))
end
function JL:Spawn(callback, ...)
    return trackedSpawn(callback, ...)
end
function JL:Delay(seconds, callback, ...)
    return trackedDelay(seconds, callback, ...)
end
function JL:Defer(callback, ...)
    return trackedDefer(callback, ...)
end
function JL:OnUnload(callback)
    if type(callback) ~= "function" then return false end
    if _disposed then pcall(callback); return false end
    self._unloadHooks[#self._unloadHooks + 1] = callback
    return true
end
function JL:IsAlive() return not _disposed end
function JL:GetCleanupStats()
    local connections, threads = 0, 0
    for _,connection in ipairs(_conns) do
        if connection and connection.Connected then connections = connections + 1 end
    end
    for _ in pairs(_threads) do threads = threads + 1 end
    return {Connections = connections, Threads = threads, Resources = #_resources, Alive = not _disposed}
end
local function touchLast() return UIS:GetLastInputType() == Enum.UserInputType.Touch end
local _tweens = {}
local function createTween(...)
    local tween = TS:Create(...)
    local record = {tween = tween}
    _tweens[record] = true
    record.connection = tween.Completed:Connect(function()
        _tweens[record] = nil
        if record.connection then pcall(function() record.connection:Disconnect() end) end
    end)
    return tween
end
local function tw(o,p,t,s,d)
    createTween(o, TweenInfo.new(t or .2, s or Enum.EasingStyle.Quart, d or Enum.EasingDirection.Out), p):Play()
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
local function beginDrag(onMove,onEnd)
    local c1,c2
    c1 = keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then onMove(i) end
    end))
    c2 = keep(UIS.InputEnded:Connect(function(i)
        if isPtr(i) then c1:Disconnect(); c2:Disconnect(); if onEnd then onEnd() end end
    end))
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
JL._iconOverrides = {}
JL._iconTextNodes = {}
local ICON_PACK_URL = "https://molto.pages.dev/source.lua"
local function iconAsset(name)
    local pack = JL._iconPack
    if not pack then return nil end
    local asset
    if type(pack.GetAsset) == "function" then
        local ok,value = pcall(pack.GetAsset, name)
        if ok then asset = value end
    end
    if asset == nil and type(pack.GetIcon) == "function" then
        local ok,value = pcall(pack.GetIcon, name)
        if ok then asset = value end
    end
    if typeof(asset) == "Instance" then
        if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
            asset = {Url = asset.Image, ImageRectOffset = asset.ImageRectOffset, ImageRectSize = asset.ImageRectSize}
        elseif asset:IsA("TextLabel") or asset:IsA("TextButton") then
            asset = {Text = asset.Text, Font = asset.Font, FontFace = asset.FontFace}
        else
            return nil
        end
    end
    if type(asset) == "string" or type(asset) == "number" then
        local value = tostring(asset)
        if value ~= "" then return {Url = value} end
        return nil
    end
    if type(asset) ~= "table" then return nil end
    local url = asset.Url or asset.Image or asset.ImageUrl or asset.Texture
        or asset.Asset or asset.AssetId or asset.ImageId or asset.Id
    local text = asset.Text or asset.Glyph
    if url ~= nil and tostring(url) ~= "" then
        return {
            Url = tostring(url),
            ImageRectOffset = typeof(asset.ImageRectOffset) == "Vector2" and asset.ImageRectOffset or Vector2.zero,
            ImageRectSize = typeof(asset.ImageRectSize) == "Vector2" and asset.ImageRectSize or Vector2.zero,
            FontFace = asset.FontFace,
            Text = text,
        }
    end
    if text ~= nil and tostring(text) ~= "" then
        return {Text = tostring(text), Font = asset.Font, FontFace = asset.FontFace}
    end
    return nil
end
local function iconImageId(value)
    local value = tostring(value or "")
    if value:match("^%d+$") then return "rbxassetid://" .. value end
    if value:match("^rbxassetid://") or value:match("^https?://") then return value end
    return nil
end
local function applyIcon(entry)
    local label = entry and entry.label
    if not (label and label.Parent) then return false end
    local raw = JL._iconOverrides[entry.name]
    local asset
    if raw ~= nil then
        if type(raw) == "table" then
            asset = raw
        else
            asset = {Url = tostring(raw)}
        end
    else
        asset = iconAsset(entry.name)
        if not asset and JL._iconPack and JL._iconPack[entry.name] ~= nil then
            local fallback = JL._iconPack[entry.name]
            if type(fallback) == "string" or type(fallback) == "number" then
                asset = {Url = tostring(fallback)}
            end
        end
    end
    local imageUrl = asset and iconImageId(asset.Url or asset.Image or asset.Id)
    local image = label:FindFirstChild("JLIconAsset")
    if imageUrl then
        if not image then
            image = Instance.new("ImageLabel")
            image.Name = "JLIconAsset"
            image.BackgroundTransparency = 1
            image.BorderSizePixel = 0
            image.Size = UDim2.new(1,0,1,0)
            image.Position = UDim2.new(0,0,0,0)
            image.ScaleType = Enum.ScaleType.Fit
            image.ZIndex = label.ZIndex
            image.Parent = label
        end
        image.Image = imageUrl
        image.ImageRectOffset = typeof(asset.ImageRectOffset) == "Vector2" and asset.ImageRectOffset or Vector2.zero
        image.ImageRectSize = typeof(asset.ImageRectSize) == "Vector2" and asset.ImageRectSize or Vector2.zero
        image.ImageColor3 = label.TextColor3
        image.Visible = true
        label.Text = ""
        label.TextTransparency = 1
        return true
    end
    if image then image.Visible = false end
    if asset and asset.Text then
        label.Text = tostring(asset.Text)
        label.TextTransparency = 0
        if asset.FontFace then
            pcall(function() label.FontFace = asset.FontFace end)
        elseif asset.Font then
            pcall(function() label.Font = asset.Font end)
        end
        return true
    end
    label.Text = entry.name
    label.TextTransparency = 0
    label.Font = GB
    return false
end
local function refreshIconTextNodes()
    for i = #JL._iconTextNodes, 1, -1 do
        local entry = JL._iconTextNodes[i]
        if not (entry.label and entry.label.Parent) then
            table.remove(JL._iconTextNodes, i)
        else
            applyIcon(entry)
        end
    end
end
function JL:LoadIconPack(url)
    url = url or ICON_PACK_URL
    local ok,body = pcall(function() return game:HttpGet(url) end)
    if not ok or not body or body == "" then return false end
    local ok2,fn = pcall(loadstring, body)
    if not ok2 or type(fn) ~= "function" then return false end
    local ok3,mod = pcall(fn)
    if not ok3 or type(mod) ~= "table" then return false end
    if type(mod.SetProvider) == "function" then
        local providerOk = pcall(mod.SetProvider, "lucide")
        if not providerOk then return false end
    end
    JL._iconPack = mod
    refreshIconTextNodes()
    return true
end
function JL:SetIconType(iconType)
    if JL._iconPack then
        if JL._iconPack.SetProvider then pcall(JL._iconPack.SetProvider, iconType)
        elseif JL._iconPack.SetIconsType then pcall(JL._iconPack.SetIconsType, iconType) end
        refreshIconTextNodes()
    end
end
function JL:SetIcons(tbl)
    for k,v in pairs(tbl or {}) do JL._iconOverrides[k] = v end
    refreshIconTextNodes()
end
local function resolveIcon(s)
    local override = JL._iconOverrides[s]
    if override ~= nil then
        if type(override) == "table" then return override end
        return tostring(override)
    end
    local asset = iconAsset(s)
    if asset then return asset end
    if JL._iconPack and JL._iconPack[s] then return JL._iconPack[s] end
    return s
end
local function mkIcon(parent,icon,sz,z)
    sz = sz or 20; z = z or 13
    local name = tostring(icon)
    local resolved = resolveIcon(name)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0,sz,0,sz)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Text = name
    label.TextScaled = true
    label.Font = GB
    label.TextColor3 = C.txt
    label.ZIndex = z
    label.Parent = parent
    local entry = {label = label, name = name}
    JL._iconTextNodes[#JL._iconTextNodes + 1] = entry
    if type(resolved) == "table" then
        applyIcon(entry)
    elseif type(resolved) == "string" then
        local imageUrl = iconImageId(resolved)
        if imageUrl then
            applyIcon({label = label, name = name})
            local image = label:FindFirstChild("JLIconAsset")
            if not image then
                image = Instance.new("ImageLabel")
                image.Name = "JLIconAsset"
                image.BackgroundTransparency = 1
                image.BorderSizePixel = 0
                image.Size = UDim2.new(1,0,1,0)
                image.ScaleType = Enum.ScaleType.Fit
                image.ZIndex = z
                image.Parent = label
            end
            image.Image = imageUrl
            image.ImageColor3 = label.TextColor3
            label.Text = ""
            label.TextTransparency = 1
        else
            label.Text = resolved
        end
    end
    return label
end
local BG = {reg = {}}
JL._bgs = {}
JL._newRows = {}
local BG_SCALE = {Crop = Enum.ScaleType.Crop, Stretch = Enum.ScaleType.Stretch, Fit = Enum.ScaleType.Fit, Tile = Enum.ScaleType.Tile}
local bgAnims = {}
local bgRunning = false
local function UI()
    JL._themeHooks = JL._themeHooks or {}
    return {
        C = C, ACC = ACCENTS, GB = GB, GM = GM, G = G,
        tw = tw, corner = corner, stroke = stroke, pad = pad, newTxt = newTxt,
        mkIcon = mkIcon, draggable = draggable, fitH = fitH, isPtr = isPtr, touchLast = touchLast,
        RunService = RunSvc, TextService = TextService,
        connect = function(signal, cb) return JL:Connect(signal, cb) end,
        -- bind(fn): вызывает fn сейчас и после каждой смены темы (для градиентов и вычисляемых цветов)
        bind = function(fn) fn(); table.insert(JL._themeHooks, fn) end,
    }
end
local function bgImage(v)
    local str = tostring(v or "")
    if str:match("^%d+$") then return "rbxassetid://" .. str end
    return str
end
local function bgStartAnim()
    if bgRunning then return end
    bgRunning = true
    trackedSpawn(function()
        local last = os.clock()
        while #bgAnims > 0 do
            task.wait(1 / 30)
            local now = os.clock(); local dt = now - last; last = now
            for i = #bgAnims,1,-1 do
                local a = bgAnims[i]
                if not (a.img and a.img.Parent) then
                    table.remove(bgAnims,i)
                else
                    a.t = a.t + dt * a.fps
                    local f = math.floor(a.t) % a.count
                    if f ~= a.f then
                        a.f = f
                        a.img.ImageRectOffset = Vector2.new((f % a.cols) * a.fw, math.floor(f / a.cols) * a.fh)
                    end
                end
            end
        end
        bgRunning = false
    end)
end
function BG.clear(face)
    for _,c in ipairs(face:GetChildren()) do if c.Name == "JLBg" then c:Destroy() end end
end
function BG.attach(face,cfg,radius)
    BG.clear(face)
    if cfg == nil or cfg == false then return end
    if type(cfg) ~= "table" then cfg = {Image = cfg} end
    if not cfg.Image then return end
    local img = Instance.new("ImageLabel"); img.Name = "JLBg"; img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.BorderSizePixel = 0; img.ZIndex = 0
    img.Image = bgImage(cfg.Image); img.ImageTransparency = cfg.Transparency or 0.25; img.ImageColor3 = cfg.Color or Color3.new(1,1,1)
    img.ScaleType = BG_SCALE[cfg.ScaleType or "Crop"] or Enum.ScaleType.Crop
    if img.ScaleType == Enum.ScaleType.Tile then local t = cfg.TileSize or 64; img.TileSize = UDim2.new(0,t,0,t) end
    img:SetAttribute("JLNoRepaint", true)
    corner(radius or 8, img)
    if cfg.Frames then
        local cols = math.max(1, math.floor(cfg.Frames.X)); local rows = math.max(1, math.floor(cfg.Frames.Y))
        local sheet = cfg.SheetSize or Vector2.new(1024,1024)
        local fw, fh = sheet.X / cols, sheet.Y / rows
        img.ImageRectSize = Vector2.new(fw,fh); img.ImageRectOffset = Vector2.new(0,0)
        if cfg.ScaleType == nil then img.ScaleType = Enum.ScaleType.Crop end
        bgAnims[#bgAnims + 1] = {img = img, t = 0, f = -1, fps = cfg.FPS or 12, cols = cols, fw = fw, fh = fh, count = math.max(1, math.floor(cfg.FrameCount or (cols * rows)))}
        bgStartAnim()
    end
    if (cfg.Dim or 0) > 0 then
        local d = Instance.new("Frame"); d.Size = UDim2.new(1,0,1,0); d.BackgroundColor3 = Color3.new(0,0,0); d.BackgroundTransparency = 1 - math.clamp(cfg.Dim,0,1); d.BorderSizePixel = 0
        d:SetAttribute("JLNoRepaint", true); d.Parent = img; corner(radius or 8, d)
    end
    img.Parent = face
end
function BG.register(kind,face,radius,own,elem)
    BG.reg[#BG.reg + 1] = {kind = kind, face = face, radius = radius, own = own ~= nil, elem = elem}
    local cfg = own
    if cfg == nil then cfg = JL._bgs[kind] end
    if cfg == nil and elem then cfg = JL._bgs.Element end
    if cfg then BG.attach(face, cfg, radius) end
end
function BG.face(row)
    for _,c in ipairs(row:GetChildren()) do
        if c:IsA("GuiObject") and c.BackgroundTransparency < 1 and c.Size == UDim2.new(1,0,1,0) then return c end
    end
    return row
end
function JL:SetBackground(kind,cfg)
    JL._bgs[kind] = cfg
    local keep = {}
    for _,e in ipairs(BG.reg) do
        if e.face and e.face.Parent then
            keep[#keep + 1] = e
            if not e.own then
                if e.kind == kind then
                    BG.attach(e.face, cfg or (e.elem and JL._bgs.Element) or nil, e.radius)
                elseif kind == "Element" and e.elem and JL._bgs[e.kind] == nil then
                    BG.attach(e.face, cfg, e.radius)
                end
            end
        end
    end
    BG.reg = keep
end
function JL:GetBackground(kind) return JL._bgs[kind] end
function JL:ClearBackground(kind) JL:SetBackground(kind, nil) end
local GUIDE = {pulses = {}, active = nil}
JL._secPanels = setmetatable({}, {__mode = "k"})
JL._searchPageTargets = {}
function GUIDE.targetOf(n)
    if n.Target then return n.Target end
    if n.Flag then return JL._registry[n.Flag] end
end
function GUIDE.met(n,base)
    local target = GUIDE.targetOf(n)
    if not target or not target.Get then return true end
    local v = target:Get()
    if n.Press then
        if base == nil then return false end
        return (tonumber(v) or 0) > base
    end
    if n.Check then
        local ok,res = pcall(n.Check, v)
        return (ok and res) and true or false
    end
    if n.State ~= nil then return v == n.State end
    return true
end
function GUIDE.stopPulse()
    for _,f in ipairs(GUIDE.pulses) do if f and f.Parent then f:Destroy() end end
    GUIDE.pulses = {}
end
function GUIDE.cancel() GUIDE.active = nil; GUIDE.stopPulse() end
function GUIDE.pulse(row,duration)
    local hl = Instance.new("Frame"); hl.Name = "JLGuideHL"; hl.Size = UDim2.new(1,0,1,0); hl.BackgroundColor3 = ACCENTS[1]; hl.BackgroundTransparency = 0.88
    hl.BorderSizePixel = 0; hl.ZIndex = 40; hl.Parent = row; corner(7,hl)
    hl:SetAttribute("JLNoRepaint", true)
    local st = stroke(ACCENTS[1], 2, hl); st:SetAttribute("JLNoRepaint", true)
    local info = TweenInfo.new(.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    createTween(hl, info, {BackgroundTransparency = 0.7}):Play()
    createTween(st, info, {Transparency = 0.75}):Play()
    GUIDE.pulses[#GUIDE.pulses + 1] = hl
    if duration and duration > 0 then trackedDelay(duration, function() if hl and hl.Parent then hl:Destroy() end end) end
    return hl
end
local function groupRules(o)
    if not o.Masters then return nil end
    local ml = o.Masters
    if type(ml) == "string" then ml = {ml} end
    local set = {}
    for _,m in ipairs(ml) do set[m] = true end
    return {list = ml, set = set, move = (o.Mode == "Move"), clear = o.ClearOthers ~= false}
end
function GUIDE.first(list,skip)
    for _,m in ipairs(list) do if m ~= skip and not GUIDE.met(m, nil) then return m end end
end
function GUIDE.start(src,n)
    GUIDE.cancel()
    local token = {}
    GUIDE.active = token
    trackedSpawn(function()
        local target = GUIDE.targetOf(n)
        local trow = target and target.Row
        local msg = n.Message or src.cfg.NeedsMessage
        if msg then JL:Notify({Title = n.Title or "Action required", Desc = msg, Type = "Warn", Duration = 3}) end
        if not (trow and trow.Parent) then GUIDE.active = nil; return end
        local base = n.Press and (tonumber(target:Get()) or 0) or nil
        if GUIDE.nav then GUIDE.nav(trow) end
        if GUIDE.active ~= token then return end
        GUIDE.pulse(trow)
        local t0 = os.clock()
        while GUIDE.active == token and os.clock() - t0 < (src.cfg.NeedsTimeout or 180) do
            if GUIDE.met(n, base) then break end
            task.wait(.15)
        end
        if GUIDE.active ~= token then return end
        GUIDE.stopPulse()
        if not GUIDE.met(n, base) then GUIDE.active = nil; return end
        local nxt = GUIDE.first(src.list, n)
        if nxt then GUIDE.start(src, nxt); return end
        GUIDE.active = nil
        if src.cfg.AutoReturn ~= false and src.row and src.row.Parent then
            task.wait(.25)
            if GUIDE.nav then GUIDE.nav(src.row) end
            GUIDE.pulse(src.row, 2.4)
        end
        if src.cfg.AutoApply and src.apply then src.apply() end
    end)
end
function GUIDE.block(o,row,apply)
    local list = o.Needs
    if list.Flag or list.Target then list = {list} end
    local first = GUIDE.first(list, nil)
    if not first then return false end
    GUIDE.start({row = row, cfg = o, list = list, apply = apply}, first)
    return true
end
JL._themes = {
    Midnight = {
        panel=Color3.fromRGB(40,40,44),    pHdr=Color3.fromRGB(31,31,35),
        border=Color3.fromRGB(66,66,72),   txt=Color3.fromRGB(240,240,242),
        dim=Color3.fromRGB(150,150,158),   togOn=Color3.fromRGB(46,204,113),
        togOff=Color3.fromRGB(28,28,32),   slTrack=Color3.fromRGB(58,58,64),
        btnBg=Color3.fromRGB(50,50,55),    btnHov=Color3.fromRGB(66,66,73),
        sidebar=Color3.fromRGB(28,28,31),  fpsGrn=Color3.fromRGB(72,214,92),
        badge=Color3.fromRGB(33,33,37),    badgeHi=Color3.fromRGB(50,60,90),
        divLine=Color3.fromRGB(70,70,76),  input=Color3.fromRGB(50,50,55),
        danger=Color3.fromRGB(200,68,68),  backdrop=Color3.fromRGB(16,16,18),
        accents={Color3.fromRGB(82,152,255),Color3.fromRGB(148,92,255),Color3.fromRGB(72,198,138),
                 Color3.fromRGB(255,132,72),Color3.fromRGB(255,72,108),Color3.fromRGB(72,208,208)},
    },
    Nord = {
        panel=Color3.fromRGB(46,52,64),    pHdr=Color3.fromRGB(38,43,53),
        border=Color3.fromRGB(76,86,106),  txt=Color3.fromRGB(236,239,244),
        dim=Color3.fromRGB(148,161,178),   togOn=Color3.fromRGB(163,190,140),
        togOff=Color3.fromRGB(30,34,42),   slTrack=Color3.fromRGB(59,66,82),
        btnBg=Color3.fromRGB(59,66,82),    btnHov=Color3.fromRGB(76,86,106),
        sidebar=Color3.fromRGB(36,41,51),  fpsGrn=Color3.fromRGB(163,190,140),
        badge=Color3.fromRGB(41,46,57),    badgeHi=Color3.fromRGB(59,81,108),
        divLine=Color3.fromRGB(76,86,106), input=Color3.fromRGB(59,66,82),
        danger=Color3.fromRGB(191,97,106), backdrop=Color3.fromRGB(22,25,31),
        accents={Color3.fromRGB(136,192,208),Color3.fromRGB(129,161,193),Color3.fromRGB(94,129,172),
                 Color3.fromRGB(163,190,140),Color3.fromRGB(235,203,139),Color3.fromRGB(180,142,173)},
    },
    Dracula = {
        panel=Color3.fromRGB(47,50,69),    pHdr=Color3.fromRGB(33,34,44),
        border=Color3.fromRGB(68,71,90),   txt=Color3.fromRGB(248,248,242),
        dim=Color3.fromRGB(98,114,164),    togOn=Color3.fromRGB(80,250,123),
        togOff=Color3.fromRGB(26,27,35),   slTrack=Color3.fromRGB(60,63,82),
        btnBg=Color3.fromRGB(58,61,80),    btnHov=Color3.fromRGB(74,77,98),
        sidebar=Color3.fromRGB(30,31,41),  fpsGrn=Color3.fromRGB(80,250,123),
        badge=Color3.fromRGB(36,37,48),    badgeHi=Color3.fromRGB(68,55,92),
        divLine=Color3.fromRGB(68,71,90),  input=Color3.fromRGB(58,61,80),
        danger=Color3.fromRGB(255,85,85),  backdrop=Color3.fromRGB(19,20,26),
        accents={Color3.fromRGB(255,121,198),Color3.fromRGB(189,147,249),Color3.fromRGB(80,250,123),
                 Color3.fromRGB(255,184,108),Color3.fromRGB(139,233,253),Color3.fromRGB(255,85,85)},
    },
    Emerald = {
        panel=Color3.fromRGB(24,36,30),    pHdr=Color3.fromRGB(17,27,22),
        border=Color3.fromRGB(45,71,58),   txt=Color3.fromRGB(228,242,234),
        dim=Color3.fromRGB(126,161,143),   togOn=Color3.fromRGB(52,211,153),
        togOff=Color3.fromRGB(14,22,18),   slTrack=Color3.fromRGB(37,58,48),
        btnBg=Color3.fromRGB(33,51,42),    btnHov=Color3.fromRGB(45,71,58),
        sidebar=Color3.fromRGB(16,25,21),  fpsGrn=Color3.fromRGB(74,222,128),
        badge=Color3.fromRGB(19,29,24),    badgeHi=Color3.fromRGB(24,64,48),
        divLine=Color3.fromRGB(45,71,58),  input=Color3.fromRGB(33,51,42),
        danger=Color3.fromRGB(220,90,90),  backdrop=Color3.fromRGB(9,15,12),
        accents={Color3.fromRGB(52,211,153),Color3.fromRGB(16,185,129),Color3.fromRGB(110,231,183),
                 Color3.fromRGB(251,191,36),Color3.fromRGB(34,211,238),Color3.fromRGB(163,230,182)},
    },
    Crimson = {
        panel=Color3.fromRGB(36,20,23),    pHdr=Color3.fromRGB(26,14,16),
        border=Color3.fromRGB(74,32,40),   txt=Color3.fromRGB(245,230,232),
        dim=Color3.fromRGB(166,122,128),   togOn=Color3.fromRGB(239,68,68),
        togOff=Color3.fromRGB(20,11,12),   slTrack=Color3.fromRGB(58,32,37),
        btnBg=Color3.fromRGB(48,27,31),    btnHov=Color3.fromRGB(74,32,40),
        sidebar=Color3.fromRGB(24,13,15),  fpsGrn=Color3.fromRGB(129,222,105),
        badge=Color3.fromRGB(28,16,18),    badgeHi=Color3.fromRGB(74,24,30),
        divLine=Color3.fromRGB(74,32,40),  input=Color3.fromRGB(48,27,31),
        danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(12,7,8),
        accents={Color3.fromRGB(239,68,68),Color3.fromRGB(248,113,113),Color3.fromRGB(251,146,60),
                 Color3.fromRGB(251,191,36),Color3.fromRGB(255,107,129),Color3.fromRGB(190,60,60)},
    },
    Cyberpunk = {
        panel=Color3.fromRGB(20,18,28),    pHdr=Color3.fromRGB(12,10,18),
        border=Color3.fromRGB(58,42,82),   txt=Color3.fromRGB(240,233,255),
        dim=Color3.fromRGB(139,122,168),   togOn=Color3.fromRGB(5,255,161),
        togOff=Color3.fromRGB(10,9,16),    slTrack=Color3.fromRGB(42,34,58),
        btnBg=Color3.fromRGB(34,28,48),    btnHov=Color3.fromRGB(58,42,82),
        sidebar=Color3.fromRGB(14,12,20),  fpsGrn=Color3.fromRGB(5,255,161),
        badge=Color3.fromRGB(17,14,24),    badgeHi=Color3.fromRGB(58,20,72),
        divLine=Color3.fromRGB(58,42,82),  input=Color3.fromRGB(34,28,48),
        danger=Color3.fromRGB(255,46,146), backdrop=Color3.fromRGB(8,6,13),
        accents={Color3.fromRGB(255,46,146),Color3.fromRGB(0,245,255),Color3.fromRGB(176,38,255),
                 Color3.fromRGB(255,225,86),Color3.fromRGB(5,255,161),Color3.fromRGB(255,110,199)},
    },
    Amoled = {
        panel=Color3.fromRGB(8,8,8),       pHdr=Color3.fromRGB(3,3,3),
        border=Color3.fromRGB(32,32,32),   txt=Color3.fromRGB(245,245,245),
        dim=Color3.fromRGB(140,140,140),   togOn=Color3.fromRGB(59,130,246),
        togOff=Color3.fromRGB(2,2,2),      slTrack=Color3.fromRGB(28,28,28),
        btnBg=Color3.fromRGB(18,18,18),    btnHov=Color3.fromRGB(32,32,32),
        sidebar=Color3.fromRGB(4,4,4),     fpsGrn=Color3.fromRGB(74,222,128),
        badge=Color3.fromRGB(5,5,5),       badgeHi=Color3.fromRGB(20,28,44),
        divLine=Color3.fromRGB(34,34,34),  input=Color3.fromRGB(18,18,18),
        danger=Color3.fromRGB(239,68,68),  backdrop=Color3.fromRGB(2,2,2),
        accents={Color3.fromRGB(59,130,246),Color3.fromRGB(168,85,247),Color3.fromRGB(16,185,129),
                 Color3.fromRGB(245,158,11),Color3.fromRGB(236,72,153),Color3.fromRGB(6,182,212)},
    },
    Daylight = {
        panel=Color3.fromRGB(252,252,253), pHdr=Color3.fromRGB(243,244,247),
        border=Color3.fromRGB(222,225,231),txt=Color3.fromRGB(28,30,36),
        dim=Color3.fromRGB(120,126,138),   togOn=Color3.fromRGB(34,197,94),
        togOff=Color3.fromRGB(214,217,224),slTrack=Color3.fromRGB(224,227,233),
        btnBg=Color3.fromRGB(240,241,245), btnHov=Color3.fromRGB(226,229,236),
        sidebar=Color3.fromRGB(246,247,250),fpsGrn=Color3.fromRGB(22,163,74),
        badge=Color3.fromRGB(252,252,253), badgeHi=Color3.fromRGB(223,232,255),
        divLine=Color3.fromRGB(222,225,231),input=Color3.fromRGB(240,241,245),
        danger=Color3.fromRGB(220,38,38),  backdrop=Color3.fromRGB(252,252,253),
        accents={Color3.fromRGB(37,99,235),Color3.fromRGB(124,58,237),Color3.fromRGB(5,150,105),
                 Color3.fromRGB(217,119,6),Color3.fromRGB(219,39,119),Color3.fromRGB(8,145,178)},
    },
}
JL._themeOrder = {"Midnight","Nord","Dracula","Emerald","Crimson","Cyberpunk","Amoled","Daylight"}
JL._themes.Violet = {
    panel=Color3.fromRGB(21,16,48),    pHdr=Color3.fromRGB(27,20,60),
    border=Color3.fromRGB(70,52,140),  txt=Color3.fromRGB(240,237,255),
    dim=Color3.fromRGB(150,136,210),   togOn=Color3.fromRGB(139,92,255),
    togOff=Color3.fromRGB(26,19,58),   slTrack=Color3.fromRGB(46,35,96),
    btnBg=Color3.fromRGB(31,23,68),    btnHov=Color3.fromRGB(46,34,98),
    sidebar=Color3.fromRGB(15,11,36),  fpsGrn=Color3.fromRGB(72,214,92),
    badge=Color3.fromRGB(18,13,42),    badgeHi=Color3.fromRGB(62,42,134),
    divLine=Color3.fromRGB(62,46,126), input=Color3.fromRGB(29,22,63),
    danger=Color3.fromRGB(235,64,92),  backdrop=Color3.fromRGB(11,8,28),
    accents={Color3.fromRGB(139,66,255),Color3.fromRGB(176,110,255),Color3.fromRGB(96,84,255),
             Color3.fromRGB(214,96,255),Color3.fromRGB(82,152,255),Color3.fromRGB(72,208,168)},
}
JL._themeOrder[#JL._themeOrder + 1] = "Violet"
JL._currentTheme = "Midnight"
JL._userTheme = "Midnight"
JL._activeWin, JL._activeBadge = nil, nil
JL._noRepaintRoots = {}
local function walkRepaint(root,swap)
    local function excluded(obj)
        for _,r in ipairs(JL._noRepaintRoots) do
            if r and r.Parent and (obj == r or obj:IsDescendantOf(r)) then return true end
        end
        return false
    end
    local function paint(obj)
        if excluded(obj) then return end
        if obj:GetAttribute("JLNoRepaint") then return end
        pcall(function()
            if obj:IsA("UIStroke") then
                local nv = swap[obj.Color:ToHex()]; if nv then obj.Color = nv end
            elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                local nv = swap[obj.ImageColor3:ToHex()]; if nv then obj.ImageColor3 = nv end
                if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
            elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                local nv = swap[obj.TextColor3:ToHex()]; if nv then obj.TextColor3 = nv end
                if obj.BackgroundTransparency < 1 then local nv2 = swap[obj.BackgroundColor3:ToHex()]; if nv2 then obj.BackgroundColor3 = nv2 end end
            elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                if obj.BackgroundTransparency < 1 then local nv = swap[obj.BackgroundColor3:ToHex()]; if nv then obj.BackgroundColor3 = nv end end
            end
        end)
    end
    paint(root)
    for _,d in ipairs(root:GetDescendants()) do paint(d) end
end
local function applyTheme(name,persist)
    local theme = JL._themes[name]; if not theme then return false end
    local oldRoles = {}; for k,v in pairs(C) do oldRoles[k] = v end
    local oldAccents = {}; for i,v in ipairs(ACCENTS) do oldAccents[i] = v end
    for k,v in pairs(theme) do if k ~= "accents" then C[k] = v end end
    if theme.accents then for i,v in ipairs(theme.accents) do ACCENTS[i] = v end end
    JL._currentTheme = name
    local swap = {}
    for k,v in pairs(oldRoles) do if C[k] then swap[v:ToHex()] = C[k] end end
    for i,v in ipairs(oldAccents) do if ACCENTS[i] then swap[v:ToHex()] = ACCENTS[i] end end
    if JL._activeWin then walkRepaint(JL._activeWin, swap) end
    if JL._activeBadge then walkRepaint(JL._activeBadge, swap) end
    for _,nd in ipairs(shared._JLNotifs or {}) do if nd and nd.f then walkRepaint(nd.f, swap) end end
    for _,r in ipairs(JL._extraRoots or {}) do if r and r.Parent then walkRepaint(r, swap) end end
    for _,fn in ipairs(JL._themeHooks or {}) do pcall(fn, name) end
    if persist then pcall(function() if JL._activeCfgSet then JL._activeCfgSet("_theme", name) end end) end
    return true
end
function JL:SetTheme(name)
    if not JL._themes[name] then return false end
    JL._userTheme = name
    return applyTheme(name, true)
end
function JL:GetTheme() return JL._currentTheme end
-- Seasonal Themes удалены (были нестабильны). Старые вызовы оставлены пустышками, чтобы чужие скрипты не падали.
local function skinKnob(knob,knobStroke)
    knob.BackgroundTransparency = 0; knob.BackgroundColor3 = Color3.new(1,1,1)
    knobStroke.Color = Color3.fromRGB(20,20,24); knobStroke.Transparency = 0
end
function JL:SetSeason() end
function JL:GetSeason() return nil end
function JL:SetSeasonTheme() end
function JL:SetSeasonIcons() end
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
local _cfgFile = nil; local _cfgData = {}; local _saveQueued = false
local _memData = {} -- значения, которые не пишутся на диск (Auto Save выключен): живут только до конца сессии
JL._autoSave = true; JL._addonAutoSave = false
local function persistable(flag)
    if type(flag) ~= "string" then return true end
    if flag:sub(1,1) == "_" then return true end -- настройки интерфейса сохраняются всегда
    if flag:sub(1,6) == "addon." then return JL._addonAutoSave == true end
    return JL._autoSave ~= false
end
local function cfgLoad(name)
    _cfgFile = name .. ".json"
    if readfile then
        local ok,r = pcall(readfile, _cfgFile)
        if ok and r and r ~= "" then
            local ok2,d = pcall(HTTP.JSONDecode, HTTP, r)
            if ok2 and type(d) == "table" then _cfgData = d end
        end
    end
    JL._autoSave = (_cfgData._autosave ~= false)
    JL._addonAutoSave = (_cfgData._addons_autosave == true)
end
local function cfgSave()
    if not (_cfgFile and writefile) or _saveQueued then return end
    _saveQueued = true
    trackedDelay(.4, function()
        _saveQueued = false
        pcall(function() writefile(_cfgFile, HTTP:JSONEncode(_cfgData)) end)
    end)
end
local function cfgHas(flag)
    if flag == nil then return false end
    if persistable(flag) then return _cfgData[flag] ~= nil end
    return _memData[flag] ~= nil
end
local function cfgSet(flag,val,store)
    if not flag then return end
    if store == nil then store = val end
    JL.Flags[flag] = val
    if persistable(flag) then _cfgData[flag] = store; _memData[flag] = nil; cfgSave()
    else _memData[flag] = store end
end
local function cfgGet(flag,default)
    if flag then
        if persistable(flag) then
            if _cfgData[flag] ~= nil then JL.Flags[flag] = _cfgData[flag]; return _cfgData[flag] end
        elseif _memData[flag] ~= nil then
            JL.Flags[flag] = _memData[flag]; return _memData[flag]
        end
        JL.Flags[flag] = default
    end
    return default
end
-- Auto Save снова включили: записываем на диск то, что копилось в памяти
function JL._cfgFlush()
    local any = false
    for flag,v in pairs(_memData) do
        if persistable(flag) then _cfgData[flag] = v; _memData[flag] = nil; any = true end
    end
    if any then cfgSave() end
end
-- ===== Preview UI bridge (PreviewUI.lua берёт отсюда темы, конфиг и хуки Unload) =====
JL._extraRoots = {}; JL._themeHooks = {}; JL._unloadHooks = {}
JL._streamerMode = false
local streamerRecords = setmetatable({}, {__mode = "k"})
local streamerConnections = {}
local function streamerNames()
    local names, seen = {}, {}
    for _,name in ipairs({LP.Name, LP.DisplayName}) do
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a,b) return #a > #b end)
    return names
end
local function streamerMaskText(value)
    if type(value) ~= "string" or value == "" then return value end
    local names = streamerNames()
    for _,name in ipairs(names) do
        local charCount = #name
        if utf8 and utf8.len then
            local ok,count = pcall(utf8.len, name)
            if ok and count then charCount = count end
        end
        local replacement = string.rep("#", charCount)
        local parts, position = {}, 1
        while true do
            local first,last = string.find(value, name, position, true)
            if not first then
                parts[#parts + 1] = string.sub(value, position)
                break
            end
            parts[#parts + 1] = string.sub(value, position, first - 1)
            parts[#parts + 1] = replacement
            position = last + 1
        end
        value = table.concat(parts)
    end
    return value
end
local function streamerWatch(obj)
    if not JL._streamerMode or not obj or streamerRecords[obj] then return end
    local isText = false
    pcall(function()
        isText = obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
    end)
    if not isText then return end
    local record = {original = obj.Text, masked = nil, writing = false}
    streamerRecords[obj] = record
    local function apply()
        if record.writing then return end
        local current
        local ok = pcall(function() current = obj.Text end)
        if not ok then return end
        record.original = current
        local masked = streamerMaskText(current)
        record.masked = masked
        if masked ~= current then
            record.writing = true
            pcall(function() obj.Text = masked end)
            record.writing = false
        end
    end
    local ok,connection = pcall(function()
        return obj:GetPropertyChangedSignal("Text"):Connect(apply)
    end)
    if ok and connection then record.connection = connection end
    apply()
end
local function streamerStop()
    for _,connection in ipairs(streamerConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(streamerConnections)
    for obj,record in pairs(streamerRecords) do
        if record.connection then pcall(function() record.connection:Disconnect() end) end
        pcall(function()
            if obj.Parent and record.masked ~= nil and obj[record.property] == record.masked then
                obj[record.property] = record.original
            end
        end)
        streamerRecords[obj] = nil
    end
end
function JL:SetStreamerMode(enabled)
    enabled = enabled == true
    if JL._streamerMode == enabled then return true end
    JL._streamerMode = enabled
    if not enabled then
        streamerStop()
        return true
    end
    local ok,descendants = pcall(function() return game:GetDescendants() end)
    if ok then
        for _,obj in ipairs(descendants) do streamerWatch(obj) end
    end
    local added
    pcall(function()
        added = game.DescendantAdded:Connect(streamerWatch)
    end)
    if added then streamerConnections[#streamerConnections + 1] = added end
    return true
end
function JL:GetStreamerMode()
    return JL._streamerMode == true
end
table.insert(JL._unloadHooks, function()
    JL._streamerMode = false
    streamerStop()
end)

JL._remoteAttach = function() end -- заменяется, когда создаётся окно (Remote)
JL._bridge = {
    C = C, ACCENTS = ACCENTS, cfgGet = cfgGet, cfgSet = cfgSet, cfgHas = cfgHas,
    keep = keep, tw = tw, icon = resolveIcon,
    track = function(resource, cleanup) return JL:Track(resource, cleanup) end,
    connect = function(signal, callback) return JL:Connect(signal, callback) end,
    spawn = trackedSpawn, delay = trackedDelay, defer = trackedDefer,
    isAlive = function() return not _disposed end,
    registry = JL._registry, noSave = JL._noSave, flags = JL.Flags,
    extraRoots = JL._extraRoots, themeHooks = JL._themeHooks, unloadHooks = JL._unloadHooks,
    notify = function(c) return JL:Notify(c) end,
    isListening = function() return JL._listening end,
    onDestroyed = function(obj) if JL._preview == obj then JL._preview = nil end end,
}
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
        local x = edgeXY(notifySide())
        local top = (notifySide() == "TopLeft" or notifySide() == "TopRight")
        local camObj = workspace.CurrentCamera
        local vpY = camObj and camObj.ViewportSize.Y or 720
        local off = 0
        for k = #active, 1, -1 do
            local nd = active[k]
            if nd and nd.f then
                local y = top and (MARGIN + off) or (vpY - MARGIN - nd.h - off)
                tw(nd.f,{Position = UDim2.new(0,x,0,y)},.35,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
                off = off + nd.h + 17.5
            end
        end
    end
    JL._notifyReposition = updPos
    local function typeAllowed(typ)
        if typ == "Warn" then return cfgGet("_notify_show_warning", true) end
        if typ == "Error" then return cfgGet("_notify_show_error", true) end
        return cfgGet("_notify_show_regular", true)
    end
    function JL:Notify(cfg2)
        if _disposed then return false end
        cfg2 = cfg2 or {}
        local typ = cfg2.Type or "Info"
        if not typeAllowed(typ) then return end
        local title = cfg2.Title or "JustLib"; local desc = cfg2.Desc or ""
        local dur = cfg2.Duration or tonumber(cfgGet("_notify_duration",5)) or 5
        local col=Color3.fromRGB(158,198,255); local ico="rbxassetid://70718918423383"
        if typ=="Error" then col=Color3.fromRGB(255,82,82); ico="rbxassetid://113114601887005"
        elseif typ=="Success" then col=Color3.fromRGB(145,255,128); ico="rbxassetid://18567015051"
        elseif typ=="Warn" then col=Color3.fromRGB(255,225,117); ico="rbxassetid://14863060512" end
        if cfgGet("_notify_stack", false) then
            for _,nd in ipairs(active) do
                if nd and not nd.closing and nd.title == title and nd.desc == desc and nd.typ == typ then
                    nd.count = nd.count + 1
                    if nd.countLbl then nd.countLbl.Text = "x" .. nd.count; nd.countLbl.Visible = true end
                    nd.restart(dur)
                    return
                end
            end
        end
        local side = notifySide()
        local x, yBase, top, left = edgeXY(side)
        local startX = left and (x - 260) or (x + 260)
        local titleH = math.max(20, math.min(TextService:GetTextSize(title, 14, GB, Vector2.new(116,200)).Y, 56))
        local descH = (desc == "") and 2 or math.max(14, math.min(TextService:GetTextSize(desc, 10, G, Vector2.new(180,2000)).Y + 2, 240))
        local barY = 2 + titleH + descH
        local h = barY + 5
        local camObj = workspace.CurrentCamera
        local vpY = camObj and camObj.ViewportSize.Y or 720
        local startY = top and MARGIN or (vpY - MARGIN - h)
        local sg2=Instance.new("ScreenGui"); sg2.Name="JLNotif"; sg2.Parent=CoreGui; sg2.ClipToDeviceSafeArea=false; sg2.ResetOnSpawn=false
        local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(0,0,0); f.Size=UDim2.new(0,W,0,h); f.Position=UDim2.new(0,startX,0,startY); f.Parent=sg2; corner(8,f)
        f:SetAttribute("JLNoRepaint", true)
        local te=Instance.new("Frame"); te.ZIndex=0; te.BorderSizePixel=0; te.BackgroundColor3=col; te.Size=UDim2.new(0,20,0,h); te.Position=UDim2.new(0,-3,0,0); te.Parent=f; corner(8,te)
        local ti=Instance.new("ImageLabel"); ti.BorderSizePixel=0; ti.BackgroundTransparency=1; ti.ImageColor3=col; ti.Image=ico; ti.Size=UDim2.new(0,15,0,15); ti.Position=UDim2.new(0,3,0,3); ti.Parent=f
        local titleLbl = newTxt({Parent=f,Text=title,Font=GB,Size=14,Color=Color3.new(1,1,1),Wrap=true,Sz=UDim2.new(0,116,0,titleH),Pos=UDim2.new(0,22,0,2),Z=5})
        titleLbl:SetAttribute("JLNoRepaint", true)
        local countLbl = newTxt({Parent=f,Text="",Font=GB,Size=12,Color=col,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,24,0,20),Pos=UDim2.new(1,-52,0,2),Z=5})
        countLbl.Visible = false
        local td=newTxt({Parent=f,Text=desc,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(0,180,0,descH),Pos=UDim2.new(0,10,0,2 + titleH),Z=5,Wrap=true}); td.TextTransparency=0.25
        td.TextYAlignment = Enum.TextYAlignment.Top
        td:SetAttribute("JLNoRepaint", true)
        local db=Instance.new("Frame"); db.BorderSizePixel=0; db.BackgroundColor3=col; db.Size=UDim2.new(0,180,0,3); db.Position=UDim2.new(0,10,0,barY); db.BackgroundTransparency=0.2; db.Parent=f; corner(2,db)
        local cb=Instance.new("TextButton"); cb.BorderSizePixel=0; cb.BackgroundTransparency=1; cb.TextSize=14; cb.Font=GB; cb.TextColor3=Color3.new(1,1,1); cb.ZIndex=6; cb.Size=UDim2.new(0,20,0,20); cb.Position=UDim2.new(1,-22,0,2); cb.Text="x"; cb.Parent=f
        cb:SetAttribute("JLNoRepaint", true)
        local nd = {f=f, g=sg2, title=title, desc=desc, typ=typ, count=1, countLbl=countLbl, db=db, closing=false, h=h, gen=0}
        table.insert(active,nd)
        local function close()
            if nd.closing then return end; nd.closing=true
            if nd.barTw then nd.barTw:Cancel() end
            for i,v in ipairs(active) do if v==nd then table.remove(active,i); break end end
            updPos()
            if f and f.Parent then
                local exitX = left and (x - 260) or (x + 260)
                local t2=createTween(f,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position=UDim2.new(0,exitX,0,f.Position.Y.Offset)}); t2:Play(); t2.Completed:Connect(function() sg2:Destroy() end)
            end
        end
        nd.close = close
        function nd.restart(d)
            nd.gen = nd.gen + 1
            local gen = nd.gen
            if nd.barTw then nd.barTw:Cancel() end
            db.Size = UDim2.new(0,180,0,3)
            local tween = createTween(db, TweenInfo.new(d,Enum.EasingStyle.Linear), {Size = UDim2.new(0,0,0,3)})
            nd.barTw = tween
            tween.Completed:Connect(function(state)
                if state == Enum.PlaybackState.Completed and nd.gen == gen and not nd.closing then close() end
            end)
            tween:Play()
        end
        cb.MouseButton1Click:Connect(close)
        updPos()
        trackedDelay(.35, function() if not nd.closing and nd.gen == 0 then nd.restart(dur) end end)
    end
    table.insert(JL._unloadHooks, function()
        for i = #active, 1, -1 do
            local nd = active[i]
            if nd and nd.g then pcall(function() nd.g:Destroy() end) end
            active[i] = nil
        end
    end)
end
local function mkPopup(backdrop,w,h,hero)
    local shell = Instance.new("Frame"); shell.Size = UDim2.new(0,w,0,h); shell.BackgroundTransparency = 1; shell.BorderSizePixel = 0
    shell.Position = UDim2.new(0.5,-w/2,0.5,-h/2 + 10); shell.Parent = backdrop
    local group = Instance.new("CanvasGroup"); group.Size = UDim2.new(1,0,1,0); group.BackgroundColor3 = C.panel; group.BorderSizePixel = 0
    group.ClipsDescendants = true
    group.GroupTransparency = 1; group.Parent = shell; corner(16,group)
    BG.register("Popup", group, 16)
    local outline = Instance.new("Frame"); outline.Size = UDim2.new(1,0,1,0); outline.BackgroundTransparency = 1; outline.BorderSizePixel = 0; outline.ZIndex = 50; outline.Parent = shell; corner(16,outline)
    local ol = stroke(C.border,1,outline); ol.Transparency = 1
    local heroH = 0
    local shineTw
    if hero then
        heroH = hero.Height or 76
        local col = hero.Color or ACCENTS[1]
        local band = Instance.new("Frame"); band.Size = UDim2.new(1,0,0,heroH); band.BackgroundColor3 = col; band.BorderSizePixel = 0; band.ClipsDescendants = true; band.Parent = group
        local bg = Instance.new("UIGradient"); bg.Rotation = 105; bg.Color = ColorSequence.new(col:Lerp(Color3.new(1,1,1),0.12), col:Lerp(Color3.new(0,0,0),0.45)); bg.Parent = band
        local shine = Instance.new("Frame"); shine.Size = UDim2.new(0.45,0,3,0); shine.Position = UDim2.new(-0.5,0,-1,0); shine.Rotation = 18
        shine.BackgroundColor3 = Color3.new(1,1,1); shine.BorderSizePixel = 0; shine.BackgroundTransparency = 1; shine.ZIndex = 2; shine.Parent = band
        local sg = Instance.new("UIGradient"); sg.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.82),NumberSequenceKeypoint.new(1,1)}); sg.Parent = shine
        shineTw = createTween(shine, TweenInfo.new(3.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Position = UDim2.new(1.15,0,-1,0)})
        shineTw:Play()
        if hero.Icon then
            local ic = mkIcon(band, hero.Icon, 26, 4); ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0, (hero.Title and 30 or (w/2)), 0.5, 2)
            if not hero.Title then ic.Position = UDim2.new(0.5,0,0.5,2) end
            if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
            ic.ZIndex = 3
        end
        if hero.Title then
            local tx = hero.Icon and 56 or 18
            newTxt({Parent=band,Text=hero.Title,Font=GB,Size=17,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-tx - 44,0,22),Pos=UDim2.new(0,tx,0,heroH/2 - (hero.Subtitle and 16 or 11)),Z=3})
            if hero.Subtitle then newTxt({Parent=band,Text=hero.Subtitle,Font=GM,Size=11,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-tx - 44,0,14),Pos=UDim2.new(0,tx,0,heroH/2 + 6),Z=3}).TextTransparency = 0.2 end
        end
    end
    local function show()
        tw(backdrop,{BackgroundTransparency = 0.45},.2)
        tw(group,{GroupTransparency = 0},.2); tw(ol,{Transparency = 0},.2)
        tw(shell,{Position = UDim2.new(0.5,-w/2,0.5,-h/2)},.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end
    local function hide()
        tw(backdrop,{BackgroundTransparency = 1},.15)
        tw(group,{GroupTransparency = 1},.15); tw(ol,{Transparency = 1},.15)
        tw(shell,{Position = UDim2.new(0.5,-w/2,0.5,-h/2 + 8)},.15)
        if shineTw then shineTw:Cancel() end
    end
    return shell, group, show, hide, heroH
end
local function mkTopBar(parent,color,z)
    local b = Instance.new("Frame"); b.Size = UDim2.new(1,-32,0,3); b.Position = UDim2.new(0,16,0,0); b.BackgroundColor3 = color; b.BorderSizePixel = 0
    if z then b.ZIndex = z end
    b.Parent = parent; corner(2,b)
    return b
end
local function confirmDialog(promptTitle,promptDesc,opts)
    opts = opts or {}
    local CoreGui = game:GetService("CoreGui")
    local sg3 = Instance.new("ScreenGui"); sg3.Name = "JLConfirm"; sg3.ResetOnSpawn = false; sg3.IgnoreGuiInset = true; sg3.DisplayOrder = 1000
    local okp = pcall(function() sg3.Parent = CoreGui end); if not okp or not sg3.Parent then sg3.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sg3
    local shell,card,showPopup,hidePopup = mkPopup(bd,280,150)
    local accentCol = opts.Danger and C.danger or ACCENTS[1]
    local topBar = mkTopBar(card, accentCol)
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
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sg3:Destroy()
    return result
end
local function unloadDialog()
    local CoreGui = game:GetService("CoreGui")
    local sgU = Instance.new("ScreenGui"); sgU.Name = "JLUnload"; sgU.ResetOnSpawn = false; sgU.IgnoreGuiInset = true; sgU.DisplayOrder = 1000
    local okp = pcall(function() sgU.Parent = CoreGui end); if not okp or not sgU.Parent then sgU.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgU
    local shell,card,showPopup,hidePopup = mkPopup(bd,340,222)
    local function dlgIcon(parent,name,sz,col,z)
        if not JL._iconPack then return nil end
        local ic = mkIcon(parent,name,sz,z)
        if ic:IsA("ImageLabel") then ic.ImageColor3 = col else ic:Destroy(); return nil end
        return ic
    end
    local accent = mkTopBar(card, C.danger, 12)
    local badge = Instance.new("Frame"); badge.Size = UDim2.new(0,38,0,38); badge.Position = UDim2.new(0,18,0,19); badge.BackgroundColor3 = C.panel:Lerp(C.danger,0.25); badge.BorderSizePixel = 0; badge.ZIndex = 12; badge.Parent = card; corner(10,badge)
    local warn = dlgIcon(badge,"triangle-alert",19,C.danger,13)
    if warn then warn.AnchorPoint = Vector2.new(0.5,0.5); warn.Position = UDim2.new(0.5,0,0.5,0) end
    newTxt({Parent=card,Text="Unload interface?",Font=GB,Size=16,Sz=UDim2.new(1,-86,0,23),Pos=UDim2.new(0,67,0,19),Z=12})
    newTxt({Parent=card,Text="You are about to close the hub",Font=G,Size=11,Color=C.dim,Sz=UDim2.new(1,-86,0,18),Pos=UDim2.new(0,67,0,43),Z=12})
    local div = Instance.new("Frame"); div.Size = UDim2.new(1,-36,0,1); div.Position = UDim2.new(0,18,0,72); div.BackgroundColor3 = C.border; div.BorderSizePixel = 0; div.ZIndex = 12; div.Parent = card
    newTxt({Parent=card,Text="The interface will be removed. Any running features may stop.",Font=G,Size=12,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-38,0,43),Pos=UDim2.new(0,19,0,87),Z=12}).TextYAlignment = Enum.TextYAlignment.Top
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,-36,0,40); row.Position = UDim2.new(0,18,1,-58); row.BackgroundTransparency = 1; row.ZIndex = 12; row.Parent = card
    local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.HorizontalAlignment = Enum.HorizontalAlignment.Center; lay.VerticalAlignment = Enum.VerticalAlignment.Center; lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0,10); lay.Parent = row
    local cancelBtn = Instance.new("TextButton"); cancelBtn.LayoutOrder = 1; cancelBtn.Size = UDim2.new(0.5,-5,1,0); cancelBtn.BackgroundColor3 = C.btnBg; cancelBtn.BorderSizePixel = 0; cancelBtn.AutoButtonColor = false
    cancelBtn.Text = "Cancel"; cancelBtn.Font = GM; cancelBtn.TextSize = 13; cancelBtn.TextColor3 = C.txt; cancelBtn.ZIndex = 13; cancelBtn.Parent = row; corner(8,cancelBtn); stroke(C.border,1,cancelBtn)
    local unloadBtn = Instance.new("TextButton"); unloadBtn.LayoutOrder = 2; unloadBtn.Size = UDim2.new(0.5,-5,1,0); unloadBtn.BackgroundColor3 = C.danger; unloadBtn.BorderSizePixel = 0; unloadBtn.AutoButtonColor = false
    unloadBtn.Text = ""; unloadBtn.ZIndex = 13; unloadBtn.Parent = row; corner(8,unloadBtn)
    local exitIcon = dlgIcon(unloadBtn,"log-out",15,Color3.new(1,1,1),14)
    if exitIcon then exitIcon.Position = UDim2.new(0,17,0.5,-7) end
    newTxt({Parent=unloadBtn,Text="Unload",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=exitIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,Sz=UDim2.new(1,exitIcon and -42 or 0,1,0),Pos=UDim2.new(0,exitIcon and 37 or 0,0,0),Z=14})
    cancelBtn.MouseEnter:Connect(function() if touchLast() then return end tw(cancelBtn,{BackgroundColor3 = C.btnHov},.1) end)
    cancelBtn.MouseLeave:Connect(function() tw(cancelBtn,{BackgroundColor3 = C.btnBg},.1) end)
    unloadBtn.MouseEnter:Connect(function() tw(unloadBtn,{BackgroundColor3 = C.danger:Lerp(Color3.new(1,1,1),0.1)},.1) end)
    unloadBtn.MouseLeave:Connect(function() tw(unloadBtn,{BackgroundColor3 = C.danger},.1) end)
    local result = nil
    cancelBtn.Activated:Connect(function() if result == nil then result = false end end)
    unloadBtn.Activated:Connect(function() if result == nil then result = true end end)
    bd.InputBegan:Connect(function(i)
        if not isPtr(i) or result ~= nil then return end
        local p,s = shell.AbsolutePosition, shell.AbsoluteSize
        local x,y = i.Position.X, i.Position.Y
        if x < p.X or x > p.X + s.X or y < p.Y or y > p.Y + s.Y then result = false end
    end)
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sgU:Destroy()
    return result
end
function JL:Confirm(opts)
    opts = opts or {}
    return confirmDialog(opts.Title or "Are you sure?", opts.Desc or "", opts)
end
local function restartPrompt()
    local CoreGui = game:GetService("CoreGui")
    local sg4 = Instance.new("ScreenGui"); sg4.Name = "JLRestart"; sg4.ResetOnSpawn = false; sg4.IgnoreGuiInset = true; sg4.DisplayOrder = 1000
    local okp = pcall(function() sg4.Parent = CoreGui end); if not okp or not sg4.Parent then sg4.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sg4
    local shell,card,showPopup,hidePopup = mkPopup(bd,260,300)
    local glowHolder = Instance.new("Frame"); glowHolder.Size = UDim2.new(0,86,0,86); glowHolder.AnchorPoint = Vector2.new(0.5,0); glowHolder.Position = UDim2.new(0.5,0,0,34); glowHolder.BackgroundTransparency = 1; glowHolder.Parent = card
    local ring = Instance.new("Frame"); ring.Size = UDim2.new(1,0,1,0); ring.AnchorPoint = Vector2.new(0.5,0.5); ring.Position = UDim2.new(0.5,0,0.5,0); ring.BackgroundTransparency = 1; ring.Parent = glowHolder
    corner(43,ring); local ringStroke = stroke(ACCENTS[1],2,ring); ringStroke.Transparency = 0.3
    local pulseTw = createTween(ring, TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Size = UDim2.new(1.25,0,1.25,0)})
    local pulseFadeTw = createTween(ringStroke, TweenInfo.new(1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true), {Transparency = 0.85})
    pulseTw:Play(); pulseFadeTw:Play()
    local iconCircle = Instance.new("Frame"); iconCircle.Size = UDim2.new(0,64,0,64); iconCircle.AnchorPoint = Vector2.new(0.5,0.5); iconCircle.Position = UDim2.new(0.5,0,0.5,0); iconCircle.BackgroundColor3 = ACCENTS[1]; iconCircle.BorderSizePixel = 0; iconCircle.Parent = glowHolder; corner(32,iconCircle)
    local ig = Instance.new("UIGradient"); ig.Rotation = 100; ig.Color = ColorSequence.new(ACCENTS[1]:Lerp(Color3.new(1,1,1),0.15), ACCENTS[1]:Lerp(Color3.new(0,0,0),0.4)); ig.Parent = iconCircle
    local ic = mkIcon(iconCircle, "refresh-cw", 28, 4); ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0.5,0,0.5,0)
    if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
    newTxt({Parent=card,Text="Hub Already Running",Font=GB,Size=16,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-30,0,20),Pos=UDim2.new(0,15,0,130)})
    newTxt({Parent=card,Text="Another JustLib hub is already open. Restart it to continue, or cancel to leave the existing one running.",Font=GM,Size=11,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-36,0,44),Pos=UDim2.new(0,18,0,154)})
    local restartBtn = Instance.new("TextButton"); restartBtn.Size = UDim2.new(1,-32,0,38); restartBtn.Position = UDim2.new(0,16,1,-86); restartBtn.BackgroundColor3 = ACCENTS[1]; restartBtn.BorderSizePixel = 0; restartBtn.AutoButtonColor = false; restartBtn.Text = ""; restartBtn.Parent = card; corner(9,restartBtn)
    newTxt({Parent=restartBtn,Text="Restart Hub",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center})
    local cancelBtn = Instance.new("TextButton"); cancelBtn.Size = UDim2.new(1,-32,0,32); cancelBtn.Position = UDim2.new(0,16,1,-40); cancelBtn.BackgroundTransparency = 1; cancelBtn.AutoButtonColor = false; cancelBtn.Text = ""; cancelBtn.Parent = card
    newTxt({Parent=cancelBtn,Text="Cancel",Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
    local result = nil
    restartBtn.MouseEnter:Connect(function() tw(restartBtn,{BackgroundColor3 = ACCENTS[1]:Lerp(Color3.new(1,1,1),0.1)},.1) end)
    restartBtn.MouseLeave:Connect(function() tw(restartBtn,{BackgroundColor3 = ACCENTS[1]},.1) end)
    restartBtn.MouseButton1Click:Connect(function() if result == nil then result = true end end)
    cancelBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    showPopup()
    while result == nil do task.wait() end
    pulseTw:Cancel(); pulseFadeTw:Cancel()
    hidePopup(); task.wait(.16)
    sg4:Destroy()
    return result
end
local function detectExecutor()
    local ok,name,ver = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        return nil
    end)
    if ok and name then return tostring(name), ver and tostring(ver) or nil end
    return nil, nil
end
local function execRequest(reqOpts)
    local fn = (typeof(request) == "function" and request)
        or (typeof(http_request) == "function" and http_request)
        or (syn and typeof(syn.request) == "function" and syn.request)
    if not fn then return nil end
    local ok,res = pcall(fn, reqOpts)
    return ok and res or nil
end
local function joinLowestServer(placeId, onFail)
    local hasReq = typeof(request) == "function" or typeof(http_request) == "function" or (syn and typeof(syn.request) == "function")
    if not hasReq then
        if onFail then onFail("Your executor doesn't support cross-origin requests") end
        return
    end
    trackedSpawn(function()
        local best,bestN,cursor = nil,math.huge,""
        for _ = 1,6 do
            local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
            local res = execRequest({Url = url, Method = "GET"})
            if not res or not res.Body then break end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body)
            if not ok or type(data) ~= "table" or not data.data then break end
            for _,srv in ipairs(data.data) do
                if srv.playing and srv.id ~= game.JobId and srv.playing < bestN and (not srv.maxPlayers or srv.playing < srv.maxPlayers) then
                    bestN = srv.playing; best = srv.id
                end
            end
            cursor = data.nextPageCursor
            if not cursor or cursor == "" then break end
        end
        if best then
            local ok = pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, best, LP) end)
            if not ok and onFail then onFail("Teleport failed") end
        elseif onFail then
            onFail("No other server found")
        end
    end)
end
-- ===== Sub-Places v2: список карточек с картинками + окно места (Teleport / Copy Teleport Script) =====
-- Иконки рисуются фреймами: символы вроде ◈ ➤ ❐ ✓ в шрифте Gotham отсутствуют и превращаются в квадраты
local function spIcon(kind, parent, size, color, z)
    z = z or 18
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,size,0,size); f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = z; f.Parent = parent
    local function bar(w, h, x, y, rot)
        local b = Instance.new("Frame"); b.AnchorPoint = Vector2.new(0.5,0.5); b.Size = UDim2.new(0,w,0,h); b.Position = UDim2.new(0,x,0,y); b.Rotation = rot or 0
        b.BackgroundColor3 = color; b.BorderSizePixel = 0; b.ZIndex = z; b.Parent = f; corner(math.min(w,h) / 2, b); return b
    end
    local function ring(d, x, y, th)
        local r = Instance.new("Frame"); r.AnchorPoint = Vector2.new(0.5,0.5); r.Size = UDim2.new(0,d,0,d); r.Position = UDim2.new(0,x,0,y)
        r.BackgroundTransparency = 1; r.BorderSizePixel = 0; r.ZIndex = z; r.Parent = f; corner(d / 2, r); stroke(color, th, r); return r
    end
    local s = size
    if kind == "compass" then ring(s, s/2, s/2, 1.6); bar(2, s*0.55, s/2, s/2, 45)
    elseif kind == "pin" then ring(s*0.86, s/2, s/2, 1.6); bar(s*0.3, s*0.3, s/2, s/2, 0)
    elseif kind == "copy" then
        bar(s*0.45, 1.6, s*0.33, s*0.12, 0); bar(1.6, s*0.45, s*0.12, s*0.33, 0)
        local fr = Instance.new("Frame"); fr.Size = UDim2.new(0,s*0.58,0,s*0.58); fr.Position = UDim2.new(0,s*0.34,0,s*0.34); fr.BackgroundTransparency = 1; fr.BorderSizePixel = 0
        fr.ZIndex = z; fr.Parent = f; corner(2, fr); stroke(color, 1.6, fr)
    elseif kind == "info" then ring(s, s/2, s/2, 1.4); bar(2, 2, s/2, s*0.3, 0); bar(2, s*0.32, s/2, s*0.62, 0)
    elseif kind == "check" then bar(s*0.34, 2.2, s*0.34, s*0.58, 45); bar(s*0.7, 2.2, s*0.62, s*0.48, -50)
    elseif kind == "menu" then bar(s*0.72, 2.2, s/2, s*0.26, 0); bar(s*0.72, 2.2, s/2, s*0.5, 0); bar(s*0.72, 2.2, s/2, s*0.74, 0)
    elseif kind == "window" then
        local fr = Instance.new("Frame"); fr.Size = UDim2.new(0,s*0.86,0,s*0.68); fr.Position = UDim2.new(0,s*0.07,0,s*0.16); fr.BackgroundTransparency = 1; fr.BorderSizePixel = 0
        fr.ZIndex = z; fr.Parent = f; corner(2, fr); stroke(color, 1.5, fr); bar(s*0.78, 1.5, s/2, s*0.36, 0)
    elseif kind == "minus" then bar(s*0.62, 2.2, s/2, s/2, 0)
    end
    return f
end
local function spChev(parent, dir, color, z)
    local f = Instance.new("Frame"); f.Size = UDim2.new(0,10,0,10); f.AnchorPoint = Vector2.new(0.5,0.5); f.Position = UDim2.new(0.5,0,0.5,0)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.ZIndex = z or 18; f.Parent = parent
    local right = (dir == "right")
    for k = 1,2 do
        local b = Instance.new("Frame"); b.AnchorPoint = Vector2.new(0.5,0.5); b.Size = UDim2.new(0,7,0,2); b.Position = UDim2.new(0.5, right and -1 or 1, 0.5, (k == 1) and -2.5 or 2.5)
        b.Rotation = ((k == 1) == right) and 45 or -45; b.BackgroundColor3 = color; b.BorderSizePixel = 0; b.ZIndex = f.ZIndex; b.Parent = f; corner(1, b)
    end
    return f
end
-- Лёгкий попап без CanvasGroup: CanvasGroup перерисовывает всё окно на каждый кадр (наведение, прокрутка, ввод),
-- на телефонах это вызывало сильные фризы
local function spPopup(backdrop, w, h)
    local shell = Instance.new("Frame"); shell.AnchorPoint = Vector2.new(0.5,0.5); shell.Position = UDim2.new(0.5,0,0.5,0); shell.Size = UDim2.new(0,w,0,h)
    shell.BackgroundColor3 = C.panel; shell.BorderSizePixel = 0; shell.Parent = backdrop; corner(16, shell); stroke(C.border, 1, shell)
    local sc = Instance.new("UIScale"); sc.Parent = shell
    local function fit()
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(1280,720)
        return math.min(1, (v.Y * 0.94) / h, (v.X * 0.96) / w)
    end
    local base = fit(); sc.Scale = base * 0.94
    local function show() base = fit(); sc.Scale = base * 0.94; tw(backdrop,{BackgroundTransparency = 0.45},.2); tw(sc,{Scale = base},.3,Enum.EasingStyle.Quint) end
    local function hide() tw(backdrop,{BackgroundTransparency = 1},.15); tw(sc,{Scale = base * 0.94},.15) end
    return shell, shell, show, hide
end
local function spInitial(name)
    local s = tostring(name or "?"):gsub("^%s+", "")
    local ok,ch = pcall(function() return utf8.char(utf8.codepoint(s, 1)) end)
    if ok and ch and ch ~= "" then return ch:upper() end
    return "?"
end
local function spColor(name)
    local h, s = 0, tostring(name or "")
    for i = 1,#s do h = (h * 31 + s:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.45, 0.55)
end
-- картинка места: градиент с буквой, поверх плавно проявляется иконка, когда она загрузится
local function spThumb(parent, pl, radius)
    local base = spColor(pl.name)
    local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,1,0); holder.BackgroundColor3 = base; holder.BorderSizePixel = 0
    holder.ClipsDescendants = true; holder.Parent = parent; corner(radius, holder); holder:SetAttribute("JLNoRepaint", true)
    local g = Instance.new("UIGradient"); g.Rotation = 125; g.Color = ColorSequence.new(base:Lerp(Color3.new(1,1,1),0.12), base:Lerp(Color3.new(0,0,0),0.45)); g.Parent = holder
    local letter = newTxt({Parent=holder,Text=spInitial(pl.name),Font=GB,Size=34,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center,Z=2})
    letter.TextTransparency = 0.35
    local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Crop
    img.ImageTransparency = 1; img.ZIndex = 3; img.Parent = holder; img:SetAttribute("JLNoRepaint", true)
    local function setImage(asset)
        if not asset or not img.Parent then return end
        img.Image = asset
        tw(img,{ImageTransparency = 0},.35); tw(letter,{TextTransparency = 1},.35)
    end
    return holder, setImage
end
local spPlayersCache = {}
local function buildSubPlacesUI(universeId, places)
    local CoreGui = game:GetService("CoreGui")
    local sgP = Instance.new("ScreenGui"); sgP.Name = "JLSubPlaces"; sgP.ResetOnSpawn = false; sgP.IgnoreGuiInset = true; sgP.DisplayOrder = 1000
    local okp = pcall(function() sgP.Parent = CoreGui end); if not okp or not sgP.Parent then sgP.Parent = PG end
    local alive = true
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgP
    local W, H = 540, 410
    local shell,card,showPopup,hidePopup = spPopup(bd, W, H)
    mkTopBar(card, ACCENTS[1])
    local HDR = 52
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HDR); hdr.Position = UDim2.new(0,0,0,3); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = card; corner(14, hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,1,0); hline.BackgroundColor3 = C.divLine; hline.BorderSizePixel = 0; hline.ZIndex = 3; hline.Parent = hdr
    local hicon = spIcon("compass", hdr, 24, ACCENTS[1], 4); hicon.Position = UDim2.new(0,16,0.5,-12)
    local backBtn = Instance.new("TextButton"); backBtn.Size = UDim2.new(0,30,0,30); backBtn.Position = UDim2.new(0,10,0.5,-15); backBtn.BackgroundColor3 = C.btnBg; backBtn.BorderSizePixel = 0
    backBtn.Text = ""; backBtn.AutoButtonColor = false; backBtn.Visible = false; backBtn.ZIndex = 5; backBtn.Parent = hdr
    corner(8, backBtn); stroke(C.border, 1, backBtn); spChev(backBtn, "left", C.txt, 6)
    local titleL = newTxt({Parent=hdr,Text="Sub-Places",Font=GB,Size=15,Sz=UDim2.new(1,-110,0,20),Pos=UDim2.new(0,52,0,8),Z=4})
    local subL = newTxt({Parent=hdr,Text=#places .. " place" .. (#places == 1 and "" or "s") .. " in this experience",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-110,0,14),Pos=UDim2.new(0,52,0,28),Z=4})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,28,0,28); closeBtn.Position = UDim2.new(1,-40,0.5,-14); closeBtn.BackgroundColor3 = C.btnBg; closeBtn.BorderSizePixel = 0
    closeBtn.Text = ""; closeBtn.AutoButtonColor = false; closeBtn.ZIndex = 5; closeBtn.Parent = hdr; corner(8, closeBtn); stroke(C.border, 1, closeBtn)
    local xl = {}
    for _,rot in ipairs({45,-45}) do
        local l = Instance.new("Frame"); l.AnchorPoint = Vector2.new(0.5,0.5); l.Position = UDim2.new(0.5,0,0.5,0); l.Size = UDim2.new(0,12,0,2); l.Rotation = rot
        l.BackgroundColor3 = C.dim; l.BorderSizePixel = 0; l.ZIndex = 6; l.Parent = closeBtn; corner(1, l); xl[#xl + 1] = l
    end
    closeBtn.MouseEnter:Connect(function() if not touchLast() then for _,l in ipairs(xl) do tw(l,{BackgroundColor3 = C.danger},.12) end end end)
    closeBtn.MouseLeave:Connect(function() for _,l in ipairs(xl) do tw(l,{BackgroundColor3 = C.dim},.12) end end)
    local function closePopup()
        alive = false
        hidePopup()
        trackedDelay(.18, function() sgP:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closePopup)

    local body = Instance.new("Frame"); body.Position = UDim2.new(0,0,0,HDR + 3); body.Size = UDim2.new(1,0,1,-(HDR + 3)); body.BackgroundTransparency = 1; body.BorderSizePixel = 0
    body.ClipsDescendants = true; body.Parent = card
    local listPage = Instance.new("Frame"); listPage.Size = UDim2.new(1,0,1,0); listPage.BackgroundTransparency = 1; listPage.BorderSizePixel = 0; listPage.Parent = body
    local detailPage = Instance.new("Frame"); detailPage.Size = UDim2.new(1,0,1,0); detailPage.Position = UDim2.new(1,0,0,0); detailPage.BackgroundTransparency = 1
    detailPage.BorderSizePixel = 0; detailPage.Visible = false; detailPage.Parent = body

    -- иконки мест: сначала то, что есть сразу (иконка игры для текущего места), потом настоящие иконки мест
    local setters, assets = {}, {}
    local function applyAsset(id, asset)
        id = tostring(id); assets[id] = asset
        for _,fn in ipairs(setters[id] or {}) do pcall(fn, asset) end
    end
    local function thumbFor(parent, pl, radius)
        local holder,setImage = spThumb(parent, pl, radius)
        local id = tostring(pl.id)
        setters[id] = setters[id] or {}
        table.insert(setters[id], setImage)
        if assets[id] then setImage(assets[id]) end
        return holder
    end

    -- ===== список =====
    local searchBox = Instance.new("Frame"); searchBox.Size = UDim2.new(1,-28,0,30); searchBox.Position = UDim2.new(0,14,0,10); searchBox.BackgroundColor3 = C.input; searchBox.BorderSizePixel = 0; searchBox.Parent = listPage
    corner(8, searchBox); stroke(C.border, 1, searchBox)
    local lens = Instance.new("Frame"); lens.Size = UDim2.new(0,11,0,11); lens.Position = UDim2.new(0,11,0,9); lens.BackgroundTransparency = 1; lens.Parent = searchBox; corner(6, lens); stroke(C.dim, 1.5, lens)
    local lh = Instance.new("Frame"); lh.Size = UDim2.new(0,6,0,2); lh.Position = UDim2.new(0,19,0,20); lh.Rotation = 45; lh.BackgroundColor3 = C.dim; lh.BorderSizePixel = 0; lh.Parent = searchBox
    local search = Instance.new("TextBox"); search.Size = UDim2.new(1,-90,1,0); search.Position = UDim2.new(0,32,0,0); search.BackgroundTransparency = 1; search.Font = G; search.TextSize = 12
    search.TextColor3 = C.txt; search.PlaceholderText = "Search places..."; search.PlaceholderColor3 = C.dim; search.Text = ""; search.ClearTextOnFocus = false
    search.TextXAlignment = Enum.TextXAlignment.Left; search.Parent = searchBox
    local countL = newTxt({Parent=searchBox,Text="",Font=GM,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,52,1,0),Pos=UDim2.new(1,-60,0,0)})

    local gridSc = Instance.new("ScrollingFrame"); gridSc.Position = UDim2.new(0,0,0,48); gridSc.Size = UDim2.new(1,0,1,-48); gridSc.BackgroundTransparency = 1; gridSc.BorderSizePixel = 0
    gridSc.ScrollBarThickness = 4; gridSc.ScrollBarImageColor3 = C.border; gridSc.CanvasSize = UDim2.new(0,0,0,0); gridSc.Parent = listPage
    local usable = W - 28 - 6
    local GAPC = 10
    local cols = 3
    local cw = math.floor((usable - GAPC * (cols - 1)) / cols)
    local grid = Instance.new("UIGridLayout"); grid.CellSize = UDim2.new(0,cw,0,150); grid.CellPadding = UDim2.new(0,GAPC,0,GAPC); grid.SortOrder = Enum.SortOrder.LayoutOrder; grid.Parent = gridSc
    pad(14,8,6,14,gridSc)
    grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() gridSc.CanvasSize = UDim2.new(0,0,0,grid.AbsoluteContentSize.Y + 22) end)
    local emptyL = newTxt({Parent=listPage,Text="No places found.",Font=GM,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,0,24),Pos=UDim2.new(0,0,0,110)})
    emptyL.Visible = false
    showPopup()

    local showDetail
    local cards = {}
    local cardBuildStarted = os.clock()
    for i,pl in ipairs(places) do
        local isCur = (tostring(pl.id) == tostring(game.PlaceId))
        local cf = Instance.new("Frame"); cf.BackgroundColor3 = C.badge; cf.BorderSizePixel = 0; cf.LayoutOrder = i; cf.Parent = gridSc; corner(10, cf)
        local st = stroke(isCur and ACCENTS[1] or C.border, isCur and 1.5 or 1, cf)
        local imgBox = Instance.new("Frame"); imgBox.Size = UDim2.new(1,-12,0,92); imgBox.Position = UDim2.new(0,6,0,6); imgBox.BackgroundTransparency = 1; imgBox.Parent = cf
        thumbFor(imgBox, pl, 7)
        if isCur then
            local ck = Instance.new("Frame"); ck.Size = UDim2.new(0,20,0,20); ck.Position = UDim2.new(1,-26,0,6); ck.BackgroundColor3 = ACCENTS[1]; ck.BorderSizePixel = 0; ck.ZIndex = 8; ck.Parent = imgBox; corner(10, ck)
            local cki = spIcon("check", ck, 12, Color3.new(1,1,1), 9); cki.Position = UDim2.new(0.5,-6,0.5,-6)
        end
        newTxt({Parent=cf,Text=pl.name or ("Place " .. tostring(pl.id)),Font=GB,Size=12,Sz=UDim2.new(1,-20,0,16),Pos=UDim2.new(0,10,0,104)})
        newTxt({Parent=cf,Text=isCur and "Current location" or ("ID " .. tostring(pl.id)),Font=GM,Size=10,Color=isCur and ACCENTS[1] or C.dim,Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,10,0,122)})
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.AutoButtonColor = false; btn.ZIndex = 30; btn.Parent = cf
        btn.MouseEnter:Connect(function()
            if touchLast() then return end
            tw(cf,{BackgroundColor3 = C.btnBg},.15); if not isCur then tw(st,{Color = C.dim},.15) end
        end)
        btn.MouseLeave:Connect(function()
            tw(cf,{BackgroundColor3 = C.badge},.15); if not isCur then tw(st,{Color = C.border},.15) end
        end)
        btn.MouseButton1Click:Connect(function() showDetail(pl) end)
        cards[#cards + 1] = {frame = cf, pl = pl}
        if i % 6 == 0 and i < #places then task.wait() end
    end
    if JL._perfEnabled then
        warn("[JustLib Perf] Sub-Places cards: " .. tostring(#cards) .. " cards in " .. string.format("%.3f s", os.clock() - cardBuildStarted))
    end
    local function applySearch()
        local q = search.Text:lower()
        local n = 0
        for _,c in ipairs(cards) do
            local hay = (tostring(c.pl.name or "") .. " " .. tostring(c.pl.id)):lower()
            local ok = q == "" or hay:find(q, 1, true) ~= nil
            c.frame.Visible = ok
            if ok then n = n + 1 end
        end
        countL.Text = n .. "/" .. #cards
        emptyL.Visible = (#cards > 0 and n == 0) or #cards == 0
        emptyL.Text = (#cards == 0) and "No places found." or "No matches."
    end
    search:GetPropertyChangedSignal("Text"):Connect(applySearch)
    applySearch()

    -- ===== окно места =====
    local view = "list"
    local curPl
    local function slide(toDetail)
        view = toDetail and "detail" or "list"
        local info = TweenInfo.new(.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if toDetail then
            detailPage.Visible = true; detailPage.Position = UDim2.new(0.14,0,0,0)
            createTween(detailPage, info, {Position = UDim2.new(0,0,0,0)}):Play()
            createTween(listPage, info, {Position = UDim2.new(-0.14,0,0,0)}):Play()
            backBtn.Visible = true; hicon.Visible = false
        else
            listPage.Visible = true
            createTween(listPage, info, {Position = UDim2.new(0,0,0,0)}):Play()
            createTween(detailPage, info, {Position = UDim2.new(0.14,0,0,0)}):Play()
            backBtn.Visible = false; hicon.Visible = true
            titleL.Text = "Sub-Places"; subL.Text = #places .. " place" .. (#places == 1 and "" or "s") .. " in this experience"
        end
        local mark = view
        trackedDelay(.4, function()
            if not alive or view ~= mark then return end
            if toDetail then listPage.Visible = false else detailPage.Visible = false end
        end)
    end
    backBtn.MouseButton1Click:Connect(function() if view == "detail" then slide(false) end end)
    backBtn.MouseEnter:Connect(function() if not touchLast() then tw(backBtn,{BackgroundColor3 = C.btnHov},.12) end end)
    backBtn.MouseLeave:Connect(function() tw(backBtn,{BackgroundColor3 = C.btnBg},.12) end)

    local function spButton(parent, y, text, iconKind, primary)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,38); b.Position = UDim2.new(0,0,0,y)
        b.BackgroundColor3 = primary and ACCENTS[1] or C.btnBg; b.BorderSizePixel = 0; b.Text = ""; b.AutoButtonColor = false; b.Parent = parent
        corner(9, b); local st = stroke(primary and ACCENTS[1] or C.border, 1, b)
        local ic = spIcon(iconKind, b, 16, primary and Color3.new(1,1,1) or ACCENTS[1], 5); ic.Position = UDim2.new(0,14,0.5,-8)
        local lbl = newTxt({Parent=b,Text=text,Font=GB,Size=12,Color=primary and Color3.new(1,1,1) or C.txt,Sz=UDim2.new(1,-62,1,0),Pos=UDim2.new(0,40,0,0),Z=5})
        local ch = spChev(b, "right", primary and Color3.new(1,1,1) or C.dim, 5); ch.Position = UDim2.new(1,-20,0.5,0)
        local rest = b.BackgroundColor3
        b.MouseEnter:Connect(function()
            if touchLast() or b:GetAttribute("off") then return end
            tw(b,{BackgroundColor3 = primary and rest:Lerp(Color3.new(1,1,1),0.14) or C.btnHov},.12)
        end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = rest},.12) end)
        return b, lbl, ic, ch
    end

    local function loadPlayers(pl, label, force)
        local id = tostring(pl.id)
        local e = spPlayersCache[id]
        if e and not force and os.clock() - e.t < 60 then label.Text = e.text; return end
        label.Text = "..."
        trackedSpawn(function()
            local total, cursor, pages, truncated = 0, "", 0, false
            for _ = 1,4 do
                local res = execRequest({Url = "https://games.roblox.com/v1/games/" .. id .. "/servers/Public?limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or ""), Method = "GET"})
                local ok,data = false,nil
                if res and res.Body then ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body) end
                if not ok or type(data) ~= "table" or type(data.data) ~= "table" then
                    if pages == 0 then if label.Parent then label.Text = "-" end; return end
                    break
                end
                for _,s in ipairs(data.data) do total = total + (tonumber(s.playing) or 0) end
                pages = pages + 1
                cursor = data.nextPageCursor
                if not cursor or cursor == "" then break end
                if pages == 4 then truncated = true end
            end
            local text = tostring(total) .. (truncated and "+" or "")
            spPlayersCache[id] = {t = os.clock(), text = text}
            if label.Parent and curPl == pl then label.Text = text end
        end)
    end

    showDetail = function(pl)
        curPl = pl
        for _,ch in ipairs(detailPage:GetChildren()) do ch:Destroy() end
        local isCur = (tostring(pl.id) == tostring(game.PlaceId))
        titleL.Text = pl.name or ("Place " .. tostring(pl.id))
        subL.Text = isCur and "You are here" or ("Place ID " .. tostring(pl.id))
        -- слева: картинка и две «таблетки»
        local imgBox = Instance.new("Frame"); imgBox.Size = UDim2.new(0,232,0,170); imgBox.Position = UDim2.new(0,16,0,16); imgBox.BackgroundTransparency = 1; imgBox.Parent = detailPage
        thumbFor(imgBox, pl, 12); stroke(C.border, 1, imgBox); corner(12, imgBox)
        if isCur then
            local tag = Instance.new("Frame"); tag.Size = UDim2.new(0,104,0,22); tag.Position = UDim2.new(0,8,0,8); tag.BackgroundColor3 = ACCENTS[1]; tag.BorderSizePixel = 0; tag.ZIndex = 8; tag.Parent = imgBox; corner(11, tag)
            local tci = spIcon("check", tag, 10, Color3.new(1,1,1), 9); tci.Position = UDim2.new(0,10,0.5,-5)
            newTxt({Parent=tag,Text="You are here",Font=GB,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(1,-24,1,0),Pos=UDim2.new(0,24,0,0),Z=9})
        end
        local function chip(y, label, value, onClick)
            local c = Instance.new("TextButton"); c.Size = UDim2.new(0,232,0,28); c.Position = UDim2.new(0,16,0,y); c.BackgroundColor3 = C.badge; c.BorderSizePixel = 0; c.Text = ""; c.AutoButtonColor = false; c.Parent = detailPage
            corner(8, c); stroke(C.border, 1, c)
            newTxt({Parent=c,Text=label,Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(0.5,0,1,0),Pos=UDim2.new(0,10,0,0),Z=5})
            local v = newTxt({Parent=c,Text=value,Font=GB,Size=11,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.5,-10,1,0),Pos=UDim2.new(0.5,0,0,0),Z=5})
            c.MouseEnter:Connect(function() if not touchLast() then tw(c,{BackgroundColor3 = C.btnBg},.12) end end)
            c.MouseLeave:Connect(function() tw(c,{BackgroundColor3 = C.badge},.12) end)
            c.MouseButton1Click:Connect(function() onClick(v) end)
            return v
        end
        chip(196, "Place ID", tostring(pl.id), function(v)
            if setclipboard then
                setclipboard(tostring(pl.id)); v.Text = "Copied!"
                trackedDelay(1.2, function() if v.Parent then v.Text = tostring(pl.id) end end)
            else JL:Notify({Title = "Copy", Desc = "Clipboard unsupported", Type = "Error", Duration = 3}) end
        end)
        local pv = chip(230, "Players online", "...", function(v) loadPlayers(pl, v, true) end)
        loadPlayers(pl, pv, false)
        -- справа: название, описание, кнопки
        local nm = newTxt({Parent=detailPage,Text=pl.name or ("Place " .. tostring(pl.id)),Font=GB,Size=18,Wrap=true,Sz=UDim2.new(0,260,0,46),Pos=UDim2.new(0,264,0,14)})
        nm.TextYAlignment = Enum.TextYAlignment.Top
        local desc = tostring(pl.description or "")
        if desc == "" then desc = "No description." end
        local dsc = Instance.new("ScrollingFrame"); dsc.Size = UDim2.new(0,260,0,108); dsc.Position = UDim2.new(0,264,0,66); dsc.BackgroundTransparency = 1; dsc.BorderSizePixel = 0
        dsc.ScrollBarThickness = 3; dsc.ScrollBarImageColor3 = C.border; dsc.CanvasSize = UDim2.new(0,0,0,0); dsc.Parent = detailPage
        local dh = fitH(desc, 12, GM, 250, 16, 4)
        local dl = newTxt({Parent=dsc,Text=desc,Font=GM,Size=12,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-8,0,dh),Pos=UDim2.new(0,0,0,0)})
        dl.TextYAlignment = Enum.TextYAlignment.Top
        dsc.CanvasSize = UDim2.new(0,0,0,dh + 4)
        local btnHost = Instance.new("Frame"); btnHost.Size = UDim2.new(0,260,0,84); btnHost.Position = UDim2.new(0,264,0,186); btnHost.BackgroundTransparency = 1; btnHost.Parent = detailPage
        local tp, tpLbl = spButton(btnHost, 0, isCur and "You are here" or "Teleport", "pin", true)
        if isCur then tp.BackgroundTransparency = 0.55; tp.AutoButtonColor = false; tp:SetAttribute("off", true) end
        local busy = false
        tp.MouseButton1Click:Connect(function()
            if isCur or busy then return end
            busy = true; tpLbl.Text = "Teleporting..."
            local ok = pcall(function() game:GetService("TeleportService"):Teleport(pl.id, LP) end)
            if not ok then
                JL:Notify({Title = "Teleport", Desc = "Teleport failed", Type = "Error", Duration = 4})
            end
            trackedDelay(4, function() busy = false; if tpLbl.Parent then tpLbl.Text = "Teleport" end end)
        end)
        local cp, cpLbl = spButton(btnHost, 46, "Copy Teleport Script", "copy", false)
        cp.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard('game:GetService("TeleportService"):Teleport(' .. tostring(pl.id) .. ', game.Players.LocalPlayer)')
                cpLbl.Text = "Copied!"
                JL:Notify({Title = "Copied", Desc = "Teleport script copied", Type = "Success", Duration = 3})
                trackedDelay(1.4, function() if cpLbl.Parent then cpLbl.Text = "Copy Teleport Script" end end)
            else
                JL:Notify({Title = "Copy", Desc = "Clipboard unsupported", Type = "Error", Duration = 3})
            end
        end)
        -- нижняя подпись
        local fl = Instance.new("Frame"); fl.Size = UDim2.new(1,-32,0,1); fl.Position = UDim2.new(0,16,0,282); fl.BackgroundColor3 = C.divLine; fl.BorderSizePixel = 0; fl.Parent = detailPage
        local sh = spIcon("info", detailPage, 14, C.dim, 4); sh.Position = UDim2.new(0,16,0,298)
        newTxt({Parent=detailPage,Text=isCur and "You are already in this place." or "Teleporting will move you to the selected sub place.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-60,0,16),Pos=UDim2.new(0,38,0,297)})
        slide(true)
    end

    -- настоящие иконки мест: Roblox thumbnails -> файл -> getcustomasset (если executor умеет); иначе остаётся градиент с буквой
    pcall(function()
        for _,pl in ipairs(places) do
            if tostring(pl.id) == tostring(game.PlaceId) then
                applyAsset(pl.id, "rbxthumb://type=GameIcon&id=" .. tostring(universeId) .. "&w=256&h=256")
            end
        end
    end)
    -- Для остальных мест оставляем локальный градиент с первой буквой.
    -- Не скачиваем миниатюры через executor request: синхронный HTTP может
    -- заморозить весь клиент даже из task.spawn/task.delay.
end
local function openSubPlaces(universeId)
    local hasReq = typeof(request) == "function" or typeof(http_request) == "function" or (syn and typeof(syn.request) == "function")
    if not hasReq then
        JL:Notify({Title = "Sub-Places", Desc = "Your executor doesn't support cross-origin requests", Type = "Error", Duration = 4})
        return
    end
    JL:Notify({Title = "Sub-Places", Desc = "Fetching place list...", Type = "Info", Duration = 2})
    trackedSpawn(function()
        local fetchStarted = os.clock()
        local places, cursor = {}, ""
        for _ = 1,3 do
            local res = execRequest({Url = "https://develop.roblox.com/v1/universes/" .. universeId .. "/places?sortOrder=Asc&limit=100" .. (cursor ~= "" and ("&cursor=" .. cursor) or ""), Method = "GET"})
            if not res or not res.Body then
                if #places == 0 then JL:Notify({Title = "Sub-Places", Desc = "Could not fetch the place list", Type = "Error", Duration = 4}); return end
                break
            end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, res.Body)
            if not ok or type(data) ~= "table" or not data.data then
                if #places == 0 then JL:Notify({Title = "Sub-Places", Desc = "Unexpected response from Roblox", Type = "Error", Duration = 4}); return end
                break
            end
            for _,pl in ipairs(data.data) do places[#places + 1] = pl end
            cursor = data.nextPageCursor
            if not cursor or cursor == "" then break end
        end
        if JL._perfEnabled then
            warn("[JustLib Perf] Sub-Places fetch: " .. tostring(#places) .. " places in " .. string.format("%.3f s", os.clock() - fetchStarted))
        end
        local uiStarted = os.clock()
        local ok,err = pcall(buildSubPlacesUI, universeId, places)
        if JL._perfEnabled then
            warn("[JustLib Perf] Sub-Places UI total: " .. string.format("%.3f s", os.clock() - uiStarted))
        end
        if not ok then
            JL:Notify({Title = "Sub-Places", Desc = "UI error: " .. tostring(err), Type = "Error", Duration = 5})
            local g = (PG and PG:FindFirstChild("JLSubPlaces")) or game:GetService("CoreGui"):FindFirstChild("JLSubPlaces")
            if g then g:Destroy() end
        end
    end)
end
local function fetchDiscordInfo(inviteUrl, callback)
    local code = tostring(inviteUrl):match("discord%.gg/([%w-]+)") or tostring(inviteUrl):match("discord%.com/invite/([%w-]+)")
    if not code then return end
    trackedSpawn(function()
        local ok,body = pcall(function() return game:HttpGet("https://discord.com/api/v10/invites/" .. code .. "?with_counts=true") end)
        if not ok or not body then return end
        local ok2,data = pcall(HTTP.JSONDecode, HTTP, body)
        if ok2 and type(data) == "table" then
            pcall(callback, {
                name = data.guild and data.guild.name,
                members = data.approximate_member_count,
                online = data.approximate_presence_count,
            })
        end
    end)
end
function JL:KeySystem(kopts)
    kopts = kopts or {}
    local keyFile = (kopts.ConfigFile or (kopts.Title or "JustLib") .. "_Key") .. ".json"
    local function checkKey(key)
        if kopts.Subscription then
            local ok,reason = JL:RedeemKey(key)
            return ok, reason
        end
        if kopts.KeyValidator then
            local ok,r = pcall(kopts.KeyValidator, key)
            if ok and r then return true end
            return false, (ok and type(r) == "string" and r) or nil
        end
        if kopts.Keys then
            for _,k in ipairs(kopts.Keys) do if k == key then return true end end
        end
        return false
    end
    if kopts.SaveKey and readfile and isfile and pcall(isfile, keyFile) and isfile(keyFile) then
        local ok,raw = pcall(readfile, keyFile)
        if ok and raw and raw ~= "" then
            local ok2,saved = pcall(HTTP.JSONDecode, HTTP, raw)
            if ok2 and type(saved) == "table" and saved.userId == LP.UserId and saved.key and checkKey(saved.key) then
                return true
            end
        end
    end
    local CoreGui = game:GetService("CoreGui")
    local sgK = Instance.new("ScreenGui"); sgK.Name = "JLKeySystem"; sgK.ResetOnSpawn = false; sgK.IgnoreGuiInset = true; sgK.DisplayOrder = 1000
    local okp = pcall(function() sgK.Parent = CoreGui end); if not okp or not sgK.Parent then sgK.Parent = PG end
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgK
    local CW,CH = 580,352
    local shell,card,showPopup,hidePopup,heroH = mkPopup(bd,CW,CH,{
        Color = kopts.AccentColor or ACCENTS[1], Icon = kopts.Icon or "key-round",
        Title = kopts.Title or "Key System", Subtitle = kopts.Subtitle or "Key system",
    })
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-38,0,heroH/2 - 13); closeBtn.BackgroundColor3 = Color3.new(0,0,0); closeBtn.BackgroundTransparency = 0.65; closeBtn.Text = "x"; closeBtn.Font = GB; closeBtn.TextSize = 13; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.ZIndex = 5; closeBtn.Parent = card; corner(8,closeBtn)
    local topY = heroH + 20
    local LW = 348
    local left = Instance.new("Frame"); left.Size = UDim2.new(0,LW,1,-topY - 16); left.Position = UDim2.new(0,20,0,topY); left.BackgroundTransparency = 1; left.Parent = card
    local divider = Instance.new("Frame"); divider.Size = UDim2.new(0,1,1,-topY - 20); divider.Position = UDim2.new(0,LW + 32,0,topY); divider.BackgroundColor3 = C.divLine; divider.BorderSizePixel = 0; divider.Parent = card
    local right = Instance.new("Frame"); right.Size = UDim2.new(0,CW - LW - 68,1,-topY - 16); right.Position = UDim2.new(0,LW + 48,0,topY); right.BackgroundTransparency = 1; right.Parent = card
    if kopts.Note then newTxt({Parent=left,Text=kopts.Note,Font=GM,Size=11,Color=C.dim,Wrap=true,Sz=UDim2.new(1,0,0,32),Pos=UDim2.new(0,0,0,0)}) end
    local inputY = kopts.Note and 40 or 0
    newTxt({Parent=left,Text="License key",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,0,0,14),Pos=UDim2.new(0,0,0,inputY)})
    local inputBg = Instance.new("Frame"); inputBg.Size = UDim2.new(1,0,0,38); inputBg.Position = UDim2.new(0,0,0,inputY + 18); inputBg.BackgroundColor3 = C.input; inputBg.BorderSizePixel = 0; inputBg.Parent = left; corner(8,inputBg)
    local inputStroke = stroke(C.border,1,inputBg)
    local keyIcon = mkIcon(inputBg, "key", 15, 3); keyIcon.Position = UDim2.new(0,12,0.5,-7); if keyIcon:IsA("TextLabel") then keyIcon.TextColor3 = C.dim else keyIcon.ImageColor3 = C.dim end
    local keyBox = Instance.new("TextBox"); keyBox.Size = UDim2.new(1,-40,1,0); keyBox.Position = UDim2.new(0,34,0,0); keyBox.BackgroundTransparency = 1
    keyBox.PlaceholderText = "Paste your key here"; keyBox.PlaceholderColor3 = C.dim; keyBox.Font = GB; keyBox.TextSize = 13; keyBox.TextColor3 = C.txt; keyBox.ClearTextOnFocus = false; keyBox.Text = ""; keyBox.Parent = inputBg
    local btnY = inputY + 64
    local submitBtn = Instance.new("TextButton"); submitBtn.Size = UDim2.new(0.62,-4,0,38); submitBtn.Position = UDim2.new(0,0,0,btnY); submitBtn.BackgroundColor3 = ACCENTS[1]; submitBtn.BorderSizePixel = 0; submitBtn.AutoButtonColor = false; submitBtn.Text = ""; submitBtn.Parent = left; corner(8,submitBtn)
    newTxt({Parent=submitBtn,Text="Submit",Font=GB,Size=13,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center})
    local getKeyBtn = Instance.new("TextButton"); getKeyBtn.Size = UDim2.new(0.38,-4,0,38); getKeyBtn.Position = UDim2.new(0.62,8,0,btnY); getKeyBtn.BackgroundColor3 = C.btnBg; getKeyBtn.BorderSizePixel = 0; getKeyBtn.AutoButtonColor = false; getKeyBtn.Text = ""; getKeyBtn.Parent = left; corner(8,getKeyBtn); stroke(C.border,1,getKeyBtn)
    newTxt({Parent=getKeyBtn,Text="Get a key",Font=GB,Size=12,XAlign=Enum.TextXAlignment.Center})
    getKeyBtn.MouseButton1Click:Connect(function()
        if not kopts.GetKeyURL then return end
        if setclipboard then setclipboard(kopts.GetKeyURL); JL:Notify({Title = "Get a Key", Desc = "Link copied — open it in your browser", Type = "Info", Duration = 4})
        else JL:Notify({Title = "Get a Key", Desc = kopts.GetKeyURL, Type = "Info", Duration = 6}) end
    end)
    local statusY = btnY + 52
    
    avatarBox:SetAttribute("JLNoRepaint", true)
    trackedSpawn(function()
        local ok,content = pcall(function() return game:GetService("Players"):GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
        if ok then avatarBox.Image = content end
    end)
    newTxt({Parent=left,Text="Welcome Back",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-46,0,12),Pos=UDim2.new(0,46,0,statusY + 2)})
    newTxt({Parent=left,Text=LP.DisplayName .. "!",Font=GB,Size=13,Sz=UDim2.new(1,-46,0,18),Pos=UDim2.new(0,46,0,statusY + 14)})
    newTxt({Parent=right,Text="Detected game",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14)})
    local gameCard = Instance.new("Frame"); gameCard.Size = UDim2.new(1,0,0,54); gameCard.Position = UDim2.new(0,0,0,18); gameCard.BackgroundColor3 = C.pHdr; gameCard.BorderSizePixel = 0; gameCard.Parent = right; corner(9,gameCard)
    local gIcon = Instance.new("ImageLabel"); gIcon.Size = UDim2.new(0,38,0,38); gIcon.Position = UDim2.new(0,8,0.5,-19); gIcon.BackgroundColor3 = C.btnBg; gIcon.BorderSizePixel = 0; gIcon.Parent = gameCard; corner(7,gIcon)
    gIcon:SetAttribute("JLNoRepaint", true)
    local gName = newTxt({Parent=gameCard,Text="Loading...",Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-56,0,16),Pos=UDim2.new(0,50,0,8)})
    local gSub = newTxt({Parent=gameCard,Text="",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-56,0,14),Pos=UDim2.new(0,50,0,26)})
    trackedSpawn(function()
        local ok,info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset) end)
        if ok and info then
            gName.Text = kopts.GameName or info.Name or "Unknown"
            gSub.Text = "In list"
            if info.IconImageAssetId and info.IconImageAssetId ~= 0 then gIcon.Image = "rbxassetid://" .. info.IconImageAssetId end
        end
    end)
    local execName = detectExecutor()
    local rowY = 84
    local function statRow(label,value,valueColor)
        local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,18); row.Position = UDim2.new(0,0,0,rowY); row.BackgroundTransparency = 1; row.Parent = right
        newTxt({Parent=row,Text=label,Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(0.5,0,1,0)})
        local v = newTxt({Parent=row,Text=value,Font=GB,Size=11,Color=valueColor or C.txt,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.5,0,1,0),Pos=UDim2.new(0.5,0,0,0)})
        rowY = rowY + 22
        return v
    end
    statRow("Executor", execName or "Unknown")
    local statusV = statRow("Status", "Key required", ACCENTS[4] or C.dim)
    if kopts.DiscordInvite then
        rowY = rowY + 6
        local commCard = Instance.new("Frame"); commCard.Size = UDim2.new(1,0,0,64); commCard.Position = UDim2.new(0,0,0,rowY); commCard.BackgroundColor3 = C.pHdr; commCard.BorderSizePixel = 0; commCard.Parent = right; corner(9,commCard)
        local dIcon = mkIcon(commCard, "message-circle", 20, 3); dIcon.Position = UDim2.new(0,10,0,8)
        newTxt({Parent=commCard,Text="Community",Font=GB,Size=11,Sz=UDim2.new(1,-16,0,14),Pos=UDim2.new(0,10,0,32)})
        local dSub = newTxt({Parent=commCard,Text="...",Font=GM,Size=9,Color=C.dim,Sz=UDim2.new(1,-16,0,12),Pos=UDim2.new(0,10,0,46)})
        fetchDiscordInfo(kopts.DiscordInvite, function(info2)
            local bits = {}
            if info2.members then bits[#bits+1] = info2.members .. " members" end
            if info2.online then bits[#bits+1] = info2.online .. " online" end
            if #bits > 0 then dSub.Text = table.concat(bits, " · ") end
        end)
        local joinBtn = Instance.new("TextButton"); joinBtn.Size = UDim2.new(0,50,0,22); joinBtn.Position = UDim2.new(1,-58,0,7); joinBtn.BackgroundColor3 = ACCENTS[1]; joinBtn.BorderSizePixel = 0; joinBtn.Text = "Join"; joinBtn.Font = GB; joinBtn.TextSize = 10; joinBtn.TextColor3 = Color3.new(1,1,1); joinBtn.Parent = commCard; corner(6,joinBtn)
        joinBtn.MouseButton1Click:Connect(function()
            if setclipboard then setclipboard(kopts.DiscordInvite); JL:Notify({Title = "Copied", Desc = "Invite link copied", Type = "Success", Duration = 3}) end
        end)
    end
    local result = nil
    closeBtn.MouseButton1Click:Connect(function() if result == nil then result = false end end)
    local function shakeInvalid(msg)
        tw(inputStroke,{Color = C.danger},.1)
        trackedDelay(.5, function() tw(inputStroke,{Color = C.border},.2) end)
        statusV.Text = "Invalid"; statusV.TextColor3 = C.danger
        JL:Notify({Title = "Key System", Desc = msg or "That key is not valid", Type = "Error", Duration = 4})
    end
    submitBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text:gsub("^%s+",""):gsub("%s+$","")
        if key == "" then shakeInvalid("Enter a key first"); return end
        statusV.Text = "Checking..."; statusV.TextColor3 = C.dim
        local valid,reason = checkKey(key)
        if valid then
            statusV.Text = "Valid"; statusV.TextColor3 = C.fpsGrn
            if kopts.SaveKey and writefile then
                pcall(writefile, keyFile, HTTP:JSONEncode({key = key, userId = LP.UserId}))
            end
            trackedDelay(.2, function() if result == nil then result = true end end)
        else
            shakeInvalid(reason)
        end
    end)
    showPopup()
    while result == nil do task.wait() end
    hidePopup(); task.wait(.16)
    sgK:Destroy()
    return result
end
local SUB = {tiers = {}, order = {}, current = nil, expDay = 0, key = nil, watchers = {}, opts = {}}
JL._sub = SUB
local function mul32(a,b)
    local ah,al = math.floor(a / 65536), a % 65536
    local bh,bl = math.floor(b / 65536), b % 65536
    return (((ah * bl + al * bh) % 65536) * 65536 + al * bl) % 4294967296
end
local function fnv32(str,seed)
    local h = seed
    for i = 1,#str do
        h = bit32.bxor(h, string.byte(str,i))
        h = mul32(h, 16777619)
    end
    h = bit32.bxor(h, bit32.rshift(h,15)); h = mul32(h, 2246822519)
    h = bit32.bxor(h, bit32.rshift(h,13)); h = mul32(h, 3266489917)
    return bit32.bxor(h, bit32.rshift(h,16))
end
local B36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function toB36(n,width)
    local out = ""
    repeat
        local d = n % 36
        out = B36:sub(d + 1,d + 1) .. out
        n = math.floor(n / 36)
    until n == 0
    while width and #out < width do out = "0" .. out end
    return out
end
local function keySig(secret,tierName,bind,nonce,expS)
    local msg = secret .. "|" .. tierName .. "|" .. bind .. "|" .. nonce .. "|" .. expS
    return toB36(fnv32(msg,2166136261),7) .. toB36(fnv32(msg .. "#",2654435761),7)
end
local function bindValue(mode)
    if mode == "Name" then return LP.Name:lower() end
    return tostring(LP.UserId)
end
local function todayDay() return math.floor(DateTime.now().UnixTimestamp / 86400) end
local function subFile() return (SUB.opts.File or "JustLib") .. "_Sub.json" end
function JL:GenerateKey(g)
    g = g or {}
    assert(g.Secret and g.Tier, "GenerateKey needs Secret and Tier")
    local prefix = g.Prefix or (g.Tier:gsub("%s",""))
    local mode = g.Bind or "UserId"
    local bind = "0"
    if mode == "UserId" and g.UserId then bind = tostring(g.UserId)
    elseif mode == "Name" and g.Name then bind = tostring(g.Name):lower() end
    local expDay = 0
    if g.Days and g.Days > 0 then expDay = todayDay() + math.floor(g.Days) end
    local rnd = Random.new()
    local nonce = ""
    for _ = 1,6 do local d = rnd:NextInteger(1,36); nonce = nonce .. B36:sub(d,d) end
    local expS = toB36(expDay)
    return prefix .. "-" .. nonce .. "-" .. expS .. "-" .. keySig(g.Secret, g.Tier, bind, nonce, expS)
end
function JL:ValidateKey(key)
    key = tostring(key or ""):gsub("%s","")
    if key == "" then return nil, "Enter a key first" end
    local o = SUB.opts
    if o.Validator then
        local ok,tierName,extra = pcall(o.Validator, key)
        if ok and type(tierName) == "string" and SUB.tiers[tierName] then
            local expDay = (type(extra) == "number" and extra > 0) and math.floor(extra / 86400) or 0
            return tierName, expDay
        end
        if o.ValidatorOnly then return nil, (ok and type(extra) == "string") and extra or "Invalid key" end
    end
    if not o.Secret then return nil, "Invalid key" end
    local up = key:upper()
    for _,rk in ipairs(o.Revoked or {}) do
        if tostring(rk):upper() == up then return nil, "This key was revoked" end
    end
    local prefix,nonce,expS,sig = up:match("^(.+)%-(%w+)%-(%w+)%-(%w+)$")
    if not prefix then return nil, "That doesn't look like a valid key" end
    local tier
    for _,t in ipairs(SUB.order) do
        local p = t.Prefix or (t.Name:gsub("%s",""))
        if p:upper() == prefix then tier = t; break end
    end
    if not tier then return nil, "Unknown key type" end
    local expDay = tonumber(expS,36) or 0
    if expDay ~= 0 and expDay <= todayDay() then return nil, "This key has expired" end
    local mode = o.Bind or "UserId"
    local binds = {"0"}
    if mode ~= "None" then binds[#binds + 1] = bindValue(mode) end
    for _,b in ipairs(binds) do
        if keySig(o.Secret, tier.Name, b, nonce, expS) == sig then return tier.Name, expDay end
    end
    return nil, "Invalid key, or it belongs to another account"
end
local function notifyTier()
    for _,cb in ipairs(SUB.watchers) do pcall(cb, SUB.current) end
end
local function clearSaved()
    if delfile and isfile then pcall(function() if isfile(subFile()) then delfile(subFile()) end end) end
end
local function applyTier(tierName,expDay,key,persist)
    SUB.current = tierName; SUB.expDay = expDay or 0; SUB.key = key
    if persist and writefile then pcall(writefile, subFile(), HTTP:JSONEncode({key = key, userId = LP.UserId})) end
    notifyTier()
end
local function checkExpiry()
    if SUB.current and SUB.expDay ~= 0 and SUB.expDay <= todayDay() then
        clearSaved(); applyTier(nil,0,nil,false)
    end
end
local function levelOf(name)
    if not name then return 0 end
    for i,t in ipairs(SUB.order) do if t.Name == name then return i end end
    return 0
end
function JL:RedeemKey(key,expectTier)
    local t,extra = JL:ValidateKey(key)
    if not t then return false, extra end
    if expectTier and t ~= expectTier then return false, "That key is for " .. t .. ", not " .. expectTier end
    applyTier(t, extra, (tostring(key):gsub("%s","")), true)
    return true
end
function JL:DeactivateSubscription() clearSaved(); applyTier(nil,0,nil,false) end
function JL:GetTier() checkExpiry(); return SUB.current end
function JL:GetTierLevel() checkExpiry(); return levelOf(SUB.current) end
function JL:HasTier(name)
    if not name then return true end
    local need = levelOf(name)
    if need == 0 then return false end
    return JL:GetTierLevel() >= need
end
function JL:OnTierChanged(cb) SUB.watchers[#SUB.watchers + 1] = cb; return cb end
function JL:OffTierChanged(cb)
    for i,w in ipairs(SUB.watchers) do if w == cb then table.remove(SUB.watchers, i); break end end
end
function JL:GetSubscriptionInfo()
    checkExpiry()
    local timeText
    if SUB.current then
        if SUB.expDay == 0 then timeText = "Lifetime"
        else
            local left = SUB.expDay - todayDay()
            timeText = left .. (left == 1 and " day left" or " days left")
        end
    end
    return {Name = SUB.current or (SUB.opts.FreeName or "Free"), Tier = SUB.current and SUB.tiers[SUB.current] or nil, Subscribed = SUB.current ~= nil, TimeText = timeText}
end
function JL:Subscriptions(o)
    SUB.opts = o or {}; SUB.tiers = {}; SUB.order = {}
    for _,t in ipairs(SUB.opts.Tiers or {}) do SUB.tiers[t.Name] = t; SUB.order[#SUB.order + 1] = t end
    if readfile and isfile then
        local okf,exists = pcall(isfile, subFile())
        if okf and exists then
            local okr,raw = pcall(readfile, subFile())
            if okr and raw and raw ~= "" then
                local okj,saved = pcall(HTTP.JSONDecode, HTTP, raw)
                if okj and type(saved) == "table" and saved.userId == LP.UserId and saved.key then
                    local t2,extra = JL:ValidateKey(saved.key)
                    if t2 then SUB.current = t2; SUB.expDay = extra or 0; SUB.key = saved.key end
                end
            end
        end
    end
    checkExpiry()
    notifyTier()
end
function JL:OpenSubscriptions()
    if #SUB.order == 0 then JL:Notify({Title = "Subscriptions", Desc = "No subscriptions are configured", Type = "Warn", Duration = 3}); return end
    if SUB._gui and SUB._gui.Parent then return end
    local CoreGui = game:GetService("CoreGui")
    local sgS = Instance.new("ScreenGui"); sgS.Name = "JLSubscriptions"; sgS.ResetOnSpawn = false; sgS.IgnoreGuiInset = true; sgS.DisplayOrder = 1000
    local okp = pcall(function() sgS.Parent = CoreGui end); if not okp or not sgS.Parent then sgS.Parent = PG end
    SUB._gui = sgS
    local bd = Instance.new("Frame"); bd.Size = UDim2.new(1,0,1,0); bd.BackgroundColor3 = Color3.new(0,0,0); bd.BackgroundTransparency = 1; bd.BorderSizePixel = 0; bd.Active = true; bd.Parent = sgS
    local PW,PH = 664,424
    local shell,card,showPopup,hidePopup,heroH = mkPopup(bd,PW,PH,{Color = ACCENTS[1], Icon = "gem", Title = "Subscriptions"})
    local statusL = newTxt({Parent=card,Text="",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-32,0,16),Pos=UDim2.new(0,18,0,heroH + 10)})
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-38,0,heroH/2 - 13); closeBtn.BackgroundColor3 = Color3.new(0,0,0); closeBtn.BackgroundTransparency = 0.65; closeBtn.Text = "x"; closeBtn.Font = GB; closeBtn.TextSize = 13; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.Parent = card; corner(8,closeBtn)
    local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1,-24,1,-heroH - 40); scroll.Position = UDim2.new(0,12,0,heroH + 32); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = C.border; scroll.ScrollingDirection = Enum.ScrollingDirection.X; scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize = Enum.AutomaticSize.X; scroll.Parent = card
    local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.Padding = UDim.new(0,12); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = scroll
    pad(0,0,0,10,scroll)
    local wheelConn = keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseWheel then return end
        local m = UIS:GetMouseLocation(); local ap,as = scroll.AbsolutePosition, scroll.AbsoluteSize
        if m.X >= ap.X and m.X <= ap.X + as.X and m.Y >= ap.Y and m.Y <= ap.Y + as.Y then
            scroll.CanvasPosition = Vector2.new(math.max(0, scroll.CanvasPosition.X - i.Position.Z * 80), 0)
        end
    end))
    local build
    local watcher
    local function closePopup()
        pcall(function() wheelConn:Disconnect() end)
        if watcher then JL:OffTierChanged(watcher) end
        hidePopup()
        trackedDelay(.16, function() sgS:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closePopup)
    build = function()
        for _,c in ipairs(scroll:GetChildren()) do if c:IsA("CanvasGroup") then c:Destroy() end end
        local info = JL:GetSubscriptionInfo()
        statusL.Text = "Current plan: " .. info.Name .. (info.TimeText and (" · " .. info.TimeText) or "")
        for idx,t in ipairs(SUB.order) do
            local col = t.Color or ACCENTS[((idx - 1) % #ACCENTS) + 1]
            local tc = Instance.new("CanvasGroup"); tc.Size = UDim2.new(0,208,1,-6); tc.BackgroundColor3 = C.pHdr; tc.BorderSizePixel = 0; tc.LayoutOrder = idx; tc.Parent = scroll; corner(12,tc)
            local ts = stroke((info.Name == t.Name) and col or C.border, (info.Name == t.Name) and 2 or 1, tc)
            local art = Instance.new("Frame"); art.Size = UDim2.new(1,0,0,108); art.BackgroundColor3 = col; art.BorderSizePixel = 0; art.Parent = tc
            art:SetAttribute("JLNoRepaint", true)
            local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(col, col:Lerp(Color3.new(0,0,0), 0.55)); g.Rotation = 90; g.Parent = art
            if t.Image then
                local img = Instance.new("ImageLabel"); img.Size = UDim2.new(1,0,1,0); img.BackgroundTransparency = 1; img.ScaleType = Enum.ScaleType.Crop; img.Parent = art
                local id = tostring(t.Image); if id:match("^%d+$") then id = "rbxassetid://" .. id end
                img.Image = id; img:SetAttribute("JLNoRepaint", true)
            else
                local big = newTxt({Parent=art,Text=t.Name:sub(1,1):upper(),Font=GB,Size=44,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center}); big:SetAttribute("JLNoRepaint", true)
            end
            local nm = newTxt({Parent=tc,Text=t.Name,Font=GB,Size=21,Color=col,Sz=UDim2.new(1,-20,0,26),Pos=UDim2.new(0,12,0,116)}); nm:SetAttribute("JLNoRepaint", true)
            if t.Tagline then newTxt({Parent=tc,Text=t.Tagline,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,12,0,143)}) end
            local perkText = t.Description
            if t.Perks then
                local lines = {}
                for _,p in ipairs(t.Perks) do lines[#lines + 1] = "• " .. p end
                perkText = table.concat(lines, "\n")
            end
            if perkText then newTxt({Parent=tc,Text=perkText,Font=GM,Size=11,Color=C.txt,Wrap=true,XAlign=Enum.TextXAlignment.Left,Sz=UDim2.new(1,-24,0,74),Pos=UDim2.new(0,12,0,164)}) end
            local act = Instance.new("Frame"); act.Size = UDim2.new(1,-24,0,64); act.Position = UDim2.new(0,12,1,-74); act.BackgroundTransparency = 1; act.Parent = tc
            local function clearAct() for _,c in ipairs(act:GetChildren()) do c:Destroy() end end
            local function mkBtn(text,y,h,bg,tcol,parent2)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,h); b.Position = UDim2.new(0,0,0,y); b.BackgroundColor3 = bg; b.BorderSizePixel = 0; b.AutoButtonColor = true
                b.Text = text; b.Font = GB; b.TextSize = 12; b.TextColor3 = tcol; b.Parent = parent2 or act; corner(8,b); return b
            end
            local showIdle, showInput
            showIdle = function()
                clearAct()
                if info.Name == t.Name then
                    newTxt({Parent=act,Text="Active" .. (info.TimeText and (" · " .. info.TimeText) or ""),Font=GB,Size=11,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,0,18)})
                    local d = mkBtn("Deactivate", 26, 32, C.btnBg, C.txt); stroke(C.border,1,d)
                    d.MouseButton1Click:Connect(function()
                        if confirmDialog("Deactivate " .. t.Name, "Remove this subscription from this account?", {Danger = true, ConfirmText = "Deactivate", CancelText = "Cancel"}) then
                            JL:DeactivateSubscription()
                        end
                    end)
                elseif JL:HasTier(t.Name) then
                    newTxt({Parent=act,Text="Included in " .. info.Name,Font=GM,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
                else
                    local a = mkBtn(t.ButtonText or "Activate", 14, 36, col, Color3.new(1,1,1)); a:SetAttribute("JLNoRepaint", true)
                    a.MouseButton1Click:Connect(function() showInput() end)
                end
            end
            showInput = function()
                clearAct()
                local boxBg = Instance.new("Frame"); boxBg.Size = UDim2.new(1,0,0,28); boxBg.BackgroundColor3 = C.input; boxBg.BorderSizePixel = 0; boxBg.Parent = act; corner(7,boxBg)
                local bs = stroke(C.border,1,boxBg)
                local box = Instance.new("TextBox"); box.Size = UDim2.new(1,-14,1,0); box.Position = UDim2.new(0,7,0,0); box.BackgroundTransparency = 1; box.PlaceholderText = "Paste your key"; box.PlaceholderColor3 = C.dim
                box.Font = GB; box.TextSize = 11; box.TextColor3 = C.txt; box.ClearTextOnFocus = false; box.Text = ""; box.Parent = boxBg
                local redeem = mkBtn("Redeem", 34, 28, col, Color3.new(1,1,1)); redeem:SetAttribute("JLNoRepaint", true)
                redeem.MouseButton1Click:Connect(function()
                    local ok,reason = JL:RedeemKey(box.Text, t.Name)
                    if ok then
                        JL:Notify({Title = t.Name, Desc = "Subscription activated", Type = "Success", Duration = 4})
                    else
                        tw(bs,{Color = C.danger},.1); trackedDelay(.5, function() tw(bs,{Color = C.border},.2) end)
                        JL:Notify({Title = "Subscriptions", Desc = reason or "Invalid key", Type = "Error", Duration = 4})
                    end
                end)
            end
            showIdle()
        end
    end
    watcher = JL:OnTierChanged(function() if sgS.Parent then build() end end)
    build()
    showPopup()
end
local function mkSwitch(parent,pos,state,ac)
    local SWW, SWH, KN = ST.swW or 34, ST.swH or 18, ST.swKnob or 12
    local KP = (SWH - KN) / 2
    local function kpos(v) return v and UDim2.new(1,-(KN + KP),0.5,-KN / 2) or UDim2.new(0,KP,0.5,-KN / 2) end
    -- позиции из старых вызовов (1,-44 / y -9) подстраиваются под размер переключателя стиля
    if pos.X.Scale == 1 and pos.X.Offset == -44 then pos = UDim2.new(1,-(SWW + 10),pos.Y.Scale,pos.Y.Offset) end
    if pos.Y.Scale == 0.5 and pos.Y.Offset == -9 then pos = UDim2.new(pos.X.Scale,pos.X.Offset,0.5,-SWH / 2) end
    local track = Instance.new("Frame"); track.Size = UDim2.new(0,SWW,0,SWH); track.Position = pos
    track.BackgroundColor3 = state and ac or C.togOff; track.BorderSizePixel = 0; track.Parent = parent; corner(SWH / 2,track)
    local st = stroke(state and ac or C.border, 1, track)
    local grad
    if ST.swGradient then
        grad = Instance.new("UIGradient"); grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(185,170,235)); grad.Rotation = 0
        grad.Enabled = state and true or false; grad.Parent = track
    end
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,KN,0,KN)
    knob.Position = kpos(state)
    knob.BackgroundColor3 = state and Color3.new(1,1,1) or C.dim; knob.BorderSizePixel = 0; knob.Parent = track; corner(KN / 2,knob)
    local obj = {Frame = track}
    function obj.Set(v)
        if grad then grad.Enabled = v and true or false end
        tw(track,{BackgroundColor3 = v and ac or C.togOff},.15)
        tw(knob,{Position = kpos(v), BackgroundColor3 = v and Color3.new(1,1,1) or C.dim},.15)
        tw(st,{Color = v and ac or C.border},.15)
    end
    return obj
end
local function mkSliderBar(parent,pos,size,ac,vmin,vmax,step,init,onChange,onRelease)
    local KN = ST.knob or 14
    local track = Instance.new("Frame"); track.Size = size; track.Position = pos; track.BackgroundColor3 = C.slTrack; track.BorderSizePixel = 0; track.Parent = parent; corner(ST.trackCorner or 3,track)
    local fill = Instance.new("Frame"); fill.BackgroundColor3 = ac; fill.BorderSizePixel = 0; fill.Parent = track; corner(ST.trackCorner or 3,fill)
    if ST.sliderGradient then
        local fg = Instance.new("UIGradient"); fg.Color = ColorSequence.new(Color3.fromRGB(165,145,235), Color3.new(1,1,1)); fg.Rotation = 0; fg.Parent = fill
    end
    local knob = Instance.new("Frame"); knob.Size = UDim2.new(0,KN,0,KN); knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0; knob.ZIndex = 2; knob.Parent = track; corner(KN / 2,knob)
    local knobStroke = stroke(Color3.fromRGB(20,20,24),1,knob)
    skinKnob(knob, knobStroke)
    local hit = Instance.new("TextButton"); hit.Size = UDim2.new(1,KN,0,26); hit.Position = UDim2.new(0,-KN / 2,0.5,-13); hit.BackgroundTransparency = 1; hit.Text = ""; hit.AutoButtonColor = false; hit.ZIndex = 3; hit.Parent = track
    local val = snap(tonumber(init) or vmin, vmin, vmax, step)
    local function paint()
        local p = (vmax > vmin) and (val - vmin) / (vmax - vmin) or 0
        fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,-KN / 2,0.5,-KN / 2)
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
        fromX(i.Position.X); beginDrag(function(m) fromX(m.Position.X) end, onRelease)
    end)
    return obj
end
local function buildSteps(cfg)
    local steps = {}
    if cfg.Labels then
        for i,l in ipairs(cfg.Labels) do steps[i] = {label = tostring(l), value = (cfg.LabelValues and cfg.LabelValues[i]) or l} end
    else
        local mn,mx,st = cfg.Min or 1, cfg.Max or 5, cfg.Step or 1
        if st <= 0 then st = 1 end
        local dec = decimalsOf(st)
        local k = 0
        while mn + k * st <= mx + 1e-9 and k < 200 do
            local v = snap(mn + k * st, mn, mx, st)
            steps[#steps + 1] = {label = fmtNum(v, dec) .. (cfg.Suffix or ""), value = v}
            k = k + 1
        end
    end
    if cfg.All then
        local allStep = {label = cfg.AllText or "All", value = cfg.AllValue or "All"}
        if cfg.All == "Start" or cfg.All == "First" then table.insert(steps, 1, allStep) else steps[#steps + 1] = allStep end
    end
    return steps
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
-- Переключатель страниц мультисекции (до 9 страниц):
--   "Segmented" - как раньше, одна полоса (удобно для 2-3 страниц)
--   "Scroll"    - одна лента, которую можно листать вправо/влево (колесо, перетаскивание, стрелки)
--   "Rows"      - кнопки складываются в строки по N штук (по умолчанию 3 в строке)
local function mkPageTabs(parent,pos,size,options,init,ac,onChange,mode,cols,unscale)
    if mode ~= "Rows" and mode ~= "Scroll" then return mkSegmented(parent,pos,size,options,init,ac,onChange) end
    unscale = unscale or function(px) return px end
    local f = Instance.new("Frame"); f.Size = size; f.Position = pos; f.BorderSizePixel = 0; f.Parent = parent
    local cur = init; local btns = {}; local obj = {}
    if mode == "Scroll" then f.BackgroundColor3 = C.pHdr; corner(8,f); stroke(C.border,1,f) else f.BackgroundTransparency = 1 end
    local function paint()
        for name,b in pairs(btns) do
            local on = (name == cur)
            tw(b,{BackgroundColor3 = on and ac or C.pHdr, TextColor3 = on and Color3.new(1,1,1) or C.dim},.15)
        end
    end
    local function mkBtn(name, host)
        local b = Instance.new("TextButton"); b.BackgroundColor3 = C.pHdr; b.BorderSizePixel = 0; b.AutoButtonColor = false; b.Text = tostring(name)
        b.Font = GB; b.TextSize = 11; b.TextColor3 = C.dim; b.Parent = host; corner(6,b)
        btns[name] = b
        b.MouseButton1Click:Connect(function()
            if cur == name then return end
            cur = name; paint()
            if obj.reveal then obj.reveal(name) end
            if onChange then onChange(name) end
        end)
        return b
    end
    if mode == "Rows" then
        local GAP, BH = 4, 26
        local n = #options; local c = math.max(cols or 3, 1)
        local idx, r = 1, 0
        while idx <= n do
            local k = math.min(c, n - idx + 1) -- последняя строка растягивается на всю ширину
            for j = 1,k do
                local b = mkBtn(options[idx + j - 1], f)
                b.Size = UDim2.new(1 / k, -GAP * (k - 1) / k, 0, BH)
                b.Position = UDim2.new((j - 1) / k, (j - 1) * GAP / k, 0, 2 + r * (BH + GAP))
                b.TextScaled = true
                local tc = Instance.new("UITextSizeConstraint"); tc.MaxTextSize = 11; tc.MinTextSize = 7; tc.Parent = b
            end
            idx = idx + k; r = r + 1
        end
    else
        local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,-4,1,-4); sc.Position = UDim2.new(0,2,0,2); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
        sc.ScrollBarThickness = 0; sc.ScrollingDirection = Enum.ScrollingDirection.X; sc.CanvasSize = UDim2.new(0,0,0,0)
        sc.ElasticBehavior = Enum.ElasticBehavior.Never; sc.Parent = f
        local lay = Instance.new("UIListLayout"); lay.FillDirection = Enum.FillDirection.Horizontal; lay.Padding = UDim.new(0,4); lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Parent = sc
        for i,name in ipairs(options) do
            local b = mkBtn(name, sc); b.LayoutOrder = i
            local okm,bm = pcall(function() return TextService:GetTextSize(tostring(name), 11, GB, Vector2.new(240,30)) end)
            b.Size = UDim2.new(0, math.max(52, math.ceil(okm and bm.X or (#tostring(name) * 7)) + 24), 1, 0)
        end
        local function arrow(left)
            local a = Instance.new("TextButton"); a.Size = UDim2.new(0,24,1,-4); a.Position = left and UDim2.new(0,2,0,2) or UDim2.new(1,-26,0,2)
            a.BackgroundColor3 = C.pHdr; a.BorderSizePixel = 0; a.Text = ""; a.AutoButtonColor = false; a.ZIndex = 6; a.Visible = false; a.Parent = f; corner(6,a)
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new(left
                and {NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(0.6,0.12), NumberSequenceKeypoint.new(1,1)}
                or {NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(0.4,0.12), NumberSequenceKeypoint.new(1,0)})
            g.Parent = a
            for k = 1,2 do -- шеврон рисуется фреймами
                local ln = Instance.new("Frame"); ln.AnchorPoint = Vector2.new(0.5,0.5); ln.Size = UDim2.new(0,7,0,2); ln.BackgroundColor3 = C.txt; ln.BorderSizePixel = 0; ln.ZIndex = 7
                ln.Position = UDim2.new(0.5, left and -3 or 3, 0.5, (k == 1) and -3 or 3)
                ln.Rotation = ((k == 1) == (not left)) and 45 or -45; ln.Parent = a; corner(1,ln)
            end
            return a
        end
        local aL, aR = arrow(true), arrow(false)
        local function win() return unscale(sc.AbsoluteWindowSize.X) end
        local function total() return unscale(lay.AbsoluteContentSize.X) end
        local function upd()
            sc.CanvasSize = UDim2.new(0, total(), 0, 0)
            local x = sc.CanvasPosition.X
            aL.Visible = x > 2; aR.Visible = x + win() < total() - 2
        end
        local function scrollTo(x)
            x = math.clamp(x, 0, math.max(0, total() - win()))
            createTween(sc, TweenInfo.new(.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(x,0)}):Play()
        end
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(upd)
        sc:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(upd)
        sc:GetPropertyChangedSignal("CanvasPosition"):Connect(upd)
        aL.MouseButton1Click:Connect(function() scrollTo(sc.CanvasPosition.X - 120) end)
        aR.MouseButton1Click:Connect(function() scrollTo(sc.CanvasPosition.X + 120) end)
        sc.InputChanged:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseWheel then scrollTo(sc.CanvasPosition.X - i.Position.Z * 80) end
        end)
        function obj.reveal(name) -- активная страница всегда в центре ленты
            local b = btns[name]; if not b then return end
            local rel = unscale(b.AbsolutePosition.X - sc.AbsolutePosition.X) + sc.CanvasPosition.X
            scrollTo(rel - win() / 2 + unscale(b.AbsoluteSize.X) / 2)
        end
        trackedDefer(upd)
    end
    paint()
    function obj.Set(v,silent) if btns[v] then cur = v; paint(); if obj.reveal then obj.reveal(v) end; if not silent and onChange then onChange(v) end end end
    function obj.Get() return cur end
    return obj
end
local function attachLockHidden(row,o)
    o = o or {}
    if o.Hidden then row.Visible = false end
    local locked = false
    local overlay
    local function build()
        if overlay then return end
        overlay = Instance.new("Frame"); overlay.Size = UDim2.new(1,0,1,0); overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.5; overlay.BorderSizePixel = 0; overlay.ZIndex = 50; overlay.Visible = false; overlay.Parent = row
        corner(7,overlay)
        local blocker = Instance.new("TextButton"); blocker.Size = UDim2.new(1,0,1,0); blocker.BackgroundTransparency = 1; blocker.Text = ""; blocker.ZIndex = 51; blocker.Parent = overlay
        blocker.MouseButton1Click:Connect(function()
            local msg = o.LockedMessage or (o.Requires and ("Requires " .. o.Requires))
            if msg then JL:Notify({Title = o.LockedTitle or "Locked", Desc = msg, Type = "Warn", Duration = 3}) end
            if o.Requires and o.OpenStore ~= false and JL.OpenSubscriptions then JL:OpenSubscriptions() end
        end)
        local badge = Instance.new("Frame"); badge.Size = UDim2.new(0,22,0,22); badge.AnchorPoint = Vector2.new(1,0.5); badge.Position = UDim2.new(1,-6,0.5,0)
        badge.BackgroundColor3 = Color3.fromRGB(40,40,44); badge.BorderSizePixel = 0; badge.ZIndex = 52; badge.Parent = overlay; corner(11,badge); stroke(Color3.fromRGB(90,90,98),1,badge)
        if JL._iconPack then
            local ic = mkIcon(badge, o.LockIcon or "lock", 13, 53)
            ic.AnchorPoint = Vector2.new(0.5,0.5); ic.Position = UDim2.new(0.5,0,0.5,0)
            if ic:IsA("TextLabel") then ic.TextColor3 = Color3.new(1,1,1) else ic.ImageColor3 = Color3.new(1,1,1) end
        else
            local body = Instance.new("Frame"); body.Size = UDim2.new(0,10,0,8); body.AnchorPoint = Vector2.new(0.5,0.5); body.Position = UDim2.new(0.5,0,0.5,3)
            body.BackgroundColor3 = Color3.new(1,1,1); body.BorderSizePixel = 0; body.ZIndex = 53; body.Parent = badge; corner(2,body)
            local ring = Instance.new("Frame"); ring.Size = UDim2.new(0,7,0,7); ring.AnchorPoint = Vector2.new(0.5,1); ring.Position = UDim2.new(0.5,0,0.5,0)
            ring.BackgroundTransparency = 1; ring.ZIndex = 52; ring.Parent = badge; corner(4,ring); stroke(Color3.new(1,1,1),1.5,ring)
        end
    end
    local function setLocked(v)
        locked = v
        if v then build(); overlay.Visible = true elseif overlay then overlay.Visible = false end
    end
    local function setHidden(v) row.Visible = not v end
    if o.Locked then setLocked(true) end
    if o.Requires or o.HiddenUntil then
        local function evalTier()
            if o.Requires then setLocked(not JL:HasTier(o.Requires)) end
            if o.HiddenUntil then setHidden(not JL:HasTier(o.HiddenUntil)) end
        end
        evalTier(); JL:OnTierChanged(evalTier)
    end
    return {
        SetLocked = function(_,v) setLocked(v) end,
        SetHidden = function(_,v) setHidden(v) end,
        ToggleLocked = function() setLocked(not locked); return locked end,
        ToggleHidden = function() setHidden(row.Visible); return not row.Visible end,
        IsLocked = function() return locked end,
        IsHidden = function() return not row.Visible end,
    }
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
        trackedDefer(function() JL._listening = false end)
        if i.KeyCode == Enum.KeyCode.Escape then btn.Text = shortKey(key); return end
        if i.KeyCode == Enum.KeyCode.Backspace then key = nil else key = i.KeyCode end
        btn.Text = shortKey(key); if onSet then onSet(key) end
    end))
    local obj = {Btn = btn}
    function obj.Get() return key end
    function obj.Set(k) key = k; btn.Text = shortKey(k) end
    return obj
end
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
    local svBg = Instance.new("Frame"); svBg.Size = UDim2.new(1,-20,0,130); svBg.Position = UDim2.new(0,10,0,44); svBg.BackgroundColor3 = Color3.fromHSV(h,1,1); svBg.BorderSizePixel = 0; svBg.Parent = card; corner(6,svBg)
    local svSat = Instance.new("Frame"); svSat.Size = UDim2.new(1,0,1,0); svSat.BackgroundColor3 = Color3.new(1,1,1); svSat.BorderSizePixel = 0; svSat.ZIndex = 2; svSat.Parent = svBg; corner(6,svSat)
    local g1 = Instance.new("UIGradient"); g1.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); g1.Parent = svSat
    local svVal = Instance.new("Frame"); svVal.Size = UDim2.new(1,0,1,0); svVal.BackgroundColor3 = Color3.new(0,0,0); svVal.BorderSizePixel = 0; svVal.ZIndex = 3; svVal.Parent = svBg; corner(6,svVal)
    local g2 = Instance.new("UIGradient"); g2.Rotation = 90; g2.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); g2.Parent = svVal
    local svCursor = Instance.new("Frame"); svCursor.Size = UDim2.new(0,12,0,12); svCursor.BackgroundTransparency = 1; svCursor.ZIndex = 4; svCursor.Parent = svBg; corner(6,svCursor); stroke(Color3.new(1,1,1),2,svCursor)
    local svHit = Instance.new("TextButton"); svHit.Size = UDim2.new(1,0,1,0); svHit.BackgroundTransparency = 1; svHit.Text = ""; svHit.ZIndex = 5; svHit.Parent = svBg
    local hueBar = Instance.new("Frame"); hueBar.Size = UDim2.new(1,-20,0,12); hueBar.Position = UDim2.new(0,10,0,184); hueBar.BackgroundColor3 = Color3.new(1,1,1); hueBar.BorderSizePixel = 0; hueBar.Parent = card; corner(5,hueBar)
    local hueG = Instance.new("UIGradient"); hueG.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}); hueG.Parent = hueBar
    local hueCursor = Instance.new("Frame"); hueCursor.Size = UDim2.new(0,8,1,6); hueCursor.BackgroundColor3 = Color3.new(1,1,1); hueCursor.BorderSizePixel = 0; hueCursor.ZIndex = 2; hueCursor.Parent = hueBar; corner(3,hueCursor); stroke(Color3.new(0,0,0),1,hueCursor)
    local hueHit = Instance.new("TextButton"); hueHit.Size = UDim2.new(1,0,1,8); hueHit.Position = UDim2.new(0,0,0,-4); hueHit.BackgroundTransparency = 1; hueHit.Text = ""; hueHit.ZIndex = 3; hueHit.Parent = hueBar
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
    local cb0 = callback; callback = nil; commit(0); callback = cb0
end
local function compactWidth(cfg)
    if not cfg then return 0 end
    local t = cfg.Type or "Toggle"
    if t == "Toggle" then return 34
    elseif t == "ColorPicker" then return 30
    elseif t == "Keybind" then return 84
    elseif t == "Button" then return cfg.Width or 78
    elseif t == "Slider" then return cfg.Width or 96
    elseif t == "Segmented" then return cfg.Width or 110
    end
    return 0
end
local function mkCompactControl(parent,x,w,cfg,ac,regFlag,parentSg)
    cfg = cfg or {}
    local t = cfg.Type or "Toggle"
    if t == "Toggle" then
        local had = cfgHas(cfg.Flag); local state = cfgGet(cfg.Flag, cfg.Default or false)
        local sw = mkSwitch(parent, UDim2.new(0,x,0.5,-9), state, ac)
        local hit = Instance.new("TextButton"); hit.Size = UDim2.new(0,34,0,22); hit.Position = UDim2.new(0,x,0.5,-11); hit.BackgroundTransparency = 1; hit.Text = ""; hit.Parent = parent
        hit.MouseButton1Click:Connect(function()
            state = not state; sw.Set(state); cfgSet(cfg.Flag, state)
            if cfg.Callback then pcall(cfg.Callback, state) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, state) end
        local ret = {Set = function(_,v) state = v; sw.Set(v); cfgSet(cfg.Flag, v) end, Get = function() return state end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "ColorPicker" then
        local had = cfgHas(cfg.Flag)
        local cur = cfgGet(cfg.Flag, cfg.Default or Color3.fromRGB(255,255,255))
        if type(cur) == "table" then cur = Color3.fromRGB(cur[1] or 255, cur[2] or 255, cur[3] or 255) end
        if cfg.Flag then JL.Flags[cfg.Flag] = cur end
        local sw = Instance.new("TextButton"); sw.Size = UDim2.new(0,30,0,20); sw.Position = UDim2.new(0,x,0.5,-10); sw.BackgroundColor3 = cur; sw.AutoButtonColor = false; sw.Text = ""; sw.BorderSizePixel = 0; sw.Parent = parent
        corner(6,sw); stroke(C.border,1,sw); sw:SetAttribute("JLNoRepaint", true)
        sw.MouseButton1Click:Connect(function()
            openColorPicker(parentSg, cur, function(col)
                cur = col; sw.BackgroundColor3 = col
                cfgSet(cfg.Flag, col, {math.round(col.R * 255), math.round(col.G * 255), math.round(col.B * 255)})
                if cfg.Callback then pcall(cfg.Callback, col) end
            end)
        end)
        if cfg.Callback and had then pcall(cfg.Callback, cur) end
        local ret = {Get = function() return cur end, Set = function(_,v) cur = v; sw.BackgroundColor3 = v end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Keybind" then
        local defName = (typeof(cfg.Default) == "EnumItem" and cfg.Default.Name) or (cfg.Default and tostring(cfg.Default)) or "None"
        local nm = cfgGet(cfg.Flag, defName)
        local chip = mkKeyChip(parent, UDim2.new(0,x,0.5,-11), nm, function(k)
            cfgSet(cfg.Flag, k and k.Name or "None"); if cfg.Callback then pcall(cfg.Callback, k) end
        end)
        local ret = {Get = function() return chip.Get() end, Set = function(_,k) chip.Set(k); cfgSet(cfg.Flag, k and k.Name or "None") end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Slider" then
        local vmin = cfg.Min or 0; local vmax = cfg.Max or 100; local step = cfg.Step or 1; local dec = decimalsOf(step); local suffix = cfg.Suffix or ""
        local had = cfgHas(cfg.Flag)
        local val = snap(tonumber(cfgGet(cfg.Flag, cfg.Default or vmin)) or vmin, vmin, vmax, step)
        local valL = newTxt({Parent=parent,Text=fmtNum(val,dec) .. suffix,Font=GB,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,w,0,12),Pos=UDim2.new(0,x,0.5,-17)})
        local bar = mkSliderBar(parent, UDim2.new(0,x,0.5,0), UDim2.new(0,w,0,6), ac, vmin, vmax, step, val, function(v)
            val = v; valL.Text = fmtNum(v,dec) .. suffix; cfgSet(cfg.Flag, v)
            if cfg.Callback then pcall(cfg.Callback, v) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, val) end
        local ret = {
            Get = function() return val end,
            Set = function(_,v) bar.Set(v, true); val = bar.Get(); valL.Text = fmtNum(val,dec) .. suffix; cfgSet(cfg.Flag, val) end,
        }
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Segmented" then
        local opts2 = cfg.Options or {}; local had = cfgHas(cfg.Flag)
        local cur = cfgGet(cfg.Flag, cfg.Default or opts2[1])
        local seg = mkSegmented(parent, UDim2.new(0,x,0.5,-12), UDim2.new(0,w,0,24), opts2, cur, ac, function(v)
            cfgSet(cfg.Flag, v); if cfg.Callback then pcall(cfg.Callback, v) end
        end)
        if cfg.Callback and had then pcall(cfg.Callback, cur) end
        local ret = {Get = seg.Get, Set = function(_,v) seg.Set(v, true); cfgSet(cfg.Flag, v) end}
        regFlag(cfg.Flag, ret, cfg.NoSave)
        return ret
    elseif t == "Button" then
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0,w,0,26); b.Position = UDim2.new(0,x,0.5,-13); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
        b.Text = cfg.Name or "Button"; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.txt; b.TextWrapped = true; b.Parent = parent
        corner(6,b); stroke(C.border,1,b)
        b.MouseEnter:Connect(function()
            if touchLast() then return end
            b:SetAttribute("JLHover", true); tw(b,{BackgroundColor3 = C.btnHov},.1)
        end)
        b.MouseLeave:Connect(function() b:SetAttribute("JLHover", false); tw(b,{BackgroundColor3 = C.btnBg},.1) end)
        b.MouseButton1Click:Connect(function()
            local fl = (b:GetAttribute("JLFlash") or 0) + 1; b:SetAttribute("JLFlash", fl)
            tw(b,{BackgroundColor3 = ac},.06)
            trackedDelay(.14, function()
                if b:GetAttribute("JLFlash") ~= fl then return end
                tw(b,{BackgroundColor3 = b:GetAttribute("JLHover") and C.btnHov or C.btnBg},.12)
            end)
            if cfg.Callback then pcall(cfg.Callback) end
        end)
        return {Instance = b}
    end
    return {}
end
local function isDividerOpt(o) return type(o) == "table" and o.Divider ~= nil end
local function dividerHeight(o) return (type(o.Divider) == "string") and 22 or 12 end
local function mkOptDivider(container,order,o,h)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,h); row.BackgroundTransparency = 1; row.LayoutOrder = order; row.Parent = container
    local line = Instance.new("Frame"); line.Size = UDim2.new(1,0,0,1); line.Position = UDim2.new(0,0,0.5,0); line.BackgroundColor3 = C.divLine; line.BorderSizePixel = 0; line.Parent = row
    if type(o.Divider) == "string" then
        local lw = math.min(#o.Divider * 6 + 14, 140)
        local chip = Instance.new("Frame"); chip.Size = UDim2.new(0,lw,0,14); chip.Position = UDim2.new(0.5,-lw / 2,0.5,-7); chip.BackgroundColor3 = C.pHdr; chip.BorderSizePixel = 0; chip.Parent = row
        newTxt({Parent=chip,Text=o.Divider,Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center})
    end
end
local function attachWidgets(content,INNER,ac,uiScale,parentSg,attachTip)
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local iOrd = 0
    local Sec = {}
    local ICONW = 22
    local ROWMIN = ST.rowMin or 32
    local CCR = ST.ctrlCorner or 7
    local function iconAtLabel(holder,icon,topH)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 15, 5); ic.Position = UDim2.new(0,4,0,math.floor((topH - 15) / 2)); ic.Size = UDim2.new(0,15,0,15)
        if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
        return ICONW
    end
    local function edgeIcon(holder,icon,left,y)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 14, 5); ic.Size = UDim2.new(0,14,0,14)
        ic.Position = left and UDim2.new(0,5,0,y) or UDim2.new(1,-19,0,y)
        if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end
        return 20
    end
    local function iconSlot(holder,icon)
        if not icon then return 0 end
        local ic = mkIcon(holder, icon, 15, 5); ic.Position = UDim2.new(0,10,0.5,-7); ic.Size = UDim2.new(0,15,0,15)
        if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end
        return ICONW
    end
    local function tip(guiObject,text) if attachTip then attachTip(guiObject, text) end end
    JL._metaButtons = JL._metaButtons or {}
    local function openMetaPanel(title, meta, settingsMode)
        local overlay = Instance.new("Frame")
        overlay.Name = "JLMetaOverlay"; overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = C.backdrop; overlay.BackgroundTransparency = 0.28
        overlay.BorderSizePixel = 0; overlay.ZIndex = 90; overlay.Parent = parentSg
        local panel = Instance.new("Frame")
        panel.Name = "JLMetaPanel"; panel.Size = UDim2.new(0.68,0,0.52,0)
        panel.Position = UDim2.new(0.5,0,0.5,0); panel.AnchorPoint = Vector2.new(0.5,0.5)
        panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
        panel.ClipsDescendants = true; panel.ZIndex = 91; panel.Parent = overlay
        corner(12,panel); stroke(C.border,1,panel)
        local limit = Instance.new("UISizeConstraint")
        limit.MinSize = Vector2.new(190,150); limit.MaxSize = Vector2.new(300,340); limit.Parent = panel
        local accentBar = Instance.new("Frame")
        accentBar.Size = UDim2.new(1,0,0,3); accentBar.BackgroundColor3 = ac
        accentBar.BorderSizePixel = 0; accentBar.ZIndex = 94; accentBar.Parent = panel
        local head = Instance.new("Frame")
        head.Size = UDim2.new(1,0,0,42); head.Position = UDim2.new(0,0,0,3)
        head.BackgroundColor3 = C.pHdr; head.BorderSizePixel = 0; head.ZIndex = 92; head.Parent = panel
        local iconTile = Instance.new("Frame")
        iconTile.Size = UDim2.new(0,25,0,25); iconTile.Position = UDim2.new(0,10,0,8)
        iconTile.BackgroundColor3 = C.badgeHi; iconTile.BorderSizePixel = 0; iconTile.ZIndex = 93; iconTile.Parent = head
        corner(10,iconTile)
        newTxt({Parent=iconTile,Text=settingsMode and "⚙" or "ⓘ",Font=GB,Size=13,Color=ac,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0),Z=94})
        newTxt({Parent=head,Text=tostring(title or (settingsMode and "Settings" or "Information")),Font=GB,Size=11,Color=C.txt,Sz=UDim2.new(1,-76,0,16),Pos=UDim2.new(0,43,0,6),Z=94})
        newTxt({Parent=head,Text=settingsMode and "Customize this item" or "Item information and details",Font=GM,Size=8,Color=C.dim,Sz=UDim2.new(1,-76,0,12),Pos=UDim2.new(0,43,0,22),Z=94})
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0,22,0,22); close.Position = UDim2.new(1,-30,0,8)
        close.BackgroundColor3 = C.btnBg; close.BorderSizePixel = 0; close.AutoButtonColor = false
        close.Text = "×"; close.Font = GB; close.TextSize = 18; close.TextColor3 = C.txt
        close.ZIndex = 95; close.Parent = head; corner(9,close); stroke(C.border,1,close)
        close.MouseEnter:Connect(function() if not touchLast() then tw(close,{BackgroundColor3=C.btnHov},0.1) end end)
        close.MouseLeave:Connect(function() tw(close,{BackgroundColor3=C.btnBg},0.1) end)
        close.MouseButton1Click:Connect(function() overlay:Destroy() end)
        local body = Instance.new("ScrollingFrame")
        body.Size = UDim2.new(1,-14,1,-51); body.Position = UDim2.new(0,7,0,48)
        body.BackgroundTransparency = 1; body.BorderSizePixel = 0
        body.ScrollBarThickness = 3; body.ScrollBarImageColor3 = ac
        body.ScrollingDirection = Enum.ScrollingDirection.Y; body.Active = true
        body.AutomaticCanvasSize = Enum.AutomaticSize.Y; body.CanvasSize = UDim2.new(0,0,0,0)
        body.ZIndex = 92; body.Parent = panel
        if settingsMode then
            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0,6); layout.Parent = body
            pad(2,2,3,6,body)
            local innerWidth = math.max(170, math.min(264, panel.AbsoluteSize.X - 28))
            local nested = attachWidgets(body,innerWidth,ac,uiScale,parentSg,attachTip)
            local count = 0
            for _,definition in ipairs(type(meta) == "table" and meta or {}) do
                if type(definition) == "table" then
                    count = count + 1
                    local kind = tostring(definition.Type or "Toggle")
                    if kind == "Textbox" or kind == "TextBox" then kind = "Input" end
                    local create = nested[kind]
                    if type(create) == "function" then
                        local config = {}
                        for k,v in pairs(definition) do config[k] = v end
                        config.Flag = config.Flag or ("JLMeta_" .. tostring(title) .. "_" .. tostring(config.Name or kind))
                        create(nested,config)
                    else
                        newTxt({Parent=body,Text="Unsupported setting: " .. kind,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-8,0,20),Z=93})
                    end
                end
            end
            if count == 0 then newTxt({Parent=body,Text="No settings are available for this item.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-8,0,24),Pos=UDim2.new(0,4,0,4),Z=93}) end
        else
            local info = type(meta) == "table" and meta or {Description=tostring(meta or "")}
            local blocks = {
                {Title=info.Title or "Overview",Text=info.Description or info.Desc or info.Text,Kind="main"},
                {Title=info.DetailsTitle or "Additional details",Text=info.Details,Kind="detail"},
                {Title=info.Warning and (info.WarningTitle or "Important") or nil,Text=info.Warning,Kind="warning"},
            }
            local y, count = 4, 0
            for _,item in ipairs(blocks) do
                if item.Text and tostring(item.Text) ~= "" then
                    count = count + 1
                    local headingText = item.Title and tostring(item.Title) or ""
                    local cardWidth = math.max(140,panel.AbsoluteSize.X - 36)
                    local titleHeight = headingText ~= "" and fitH(headingText,11,GB,cardWidth,16,4) or 0
                    local descHeight = fitH(tostring(item.Text),10,GM,cardWidth,18,9)
                    local card = Instance.new("Frame")
                    card.Size = UDim2.new(1,-6,0,titleHeight + descHeight + (titleHeight > 0 and 5 or 0) + 18)
                    card.Position = UDim2.new(0,2,0,y)
                    card.BackgroundColor3 = item.Kind == "warning" and C.pHdr or C.btnBg
                    card.BorderSizePixel = 0; card.ZIndex = 93; card.Parent = body
                    corner(9,card)
                    local accent = Instance.new("Frame")
                    accent.Size = UDim2.new(0,3,1,-18); accent.Position = UDim2.new(0,0,0,9)
                    accent.BackgroundColor3 = item.Kind == "warning" and C.danger or ac
                    accent.BorderSizePixel = 0; accent.ZIndex = 94; accent.Parent = card; corner(2,accent)
                    local content = Instance.new("Frame")
                    content.Size = UDim2.new(1,-22,1,-12); content.Position = UDim2.new(0,12,0,6)
                    content.BackgroundTransparency = 1; content.ZIndex = 94; content.Parent = card
                    if titleHeight > 0 then
                        newTxt({Parent=content,Text=headingText,Font=GB,Size=11,Color=item.Kind == "warning" and C.danger or ac,Wrap=true,Sz=UDim2.new(1,0,0,titleHeight),Z=95})
                    end
                    local desc = newTxt({Parent=content,Text=tostring(item.Text),Font=GM,Size=10,Color=C.txt,Wrap=true,Sz=UDim2.new(1,0,0,descHeight),Pos=UDim2.new(0,0,0,titleHeight > 0 and titleHeight + 5 or 0),Z=95})
                    desc.TextYAlignment = Enum.TextYAlignment.Top
                    y = y + card.Size.Y.Offset + 6
                end
            end
            if count == 0 then newTxt({Parent=body,Text="No additional information has been provided.",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-8,0,24),Pos=UDim2.new(0,4,0,4),Z=93}) end
            body.CanvasSize = UDim2.new(0,0,0,y + 6)
        end
    end
    local function addMetaButtons(row, definition)
        if type(definition) ~= "table" or not row then return end
        local settings = type(definition.Settings) == "table" and #definition.Settings > 0
        local info = definition.Info ~= nil and definition.Info ~= false and definition.Info ~= ""
        if not settings and not info then return end

        -- Metadata actions use a separate wrapper. The control row and its
        -- internal GUI hierarchy are not resized or repositioned.
        local parent = row.Parent
        if not parent then return end
        local wrapper = Instance.new("Frame")
        wrapper.Name = "JLMetaRow"
        wrapper.Size = UDim2.new(1,0,0,0)
        wrapper.AutomaticSize = Enum.AutomaticSize.Y
        wrapper.BackgroundTransparency = 1
        wrapper.BorderSizePixel = 0
        wrapper.ClipsDescendants = false
        wrapper.LayoutOrder = row.LayoutOrder
        wrapper.Parent = parent

        local originalSize = row.Size
        row.Parent = wrapper
        row.Position = UDim2.new(0,0,0,18)
        row.Size = originalSize

        local capsule = Instance.new("Frame")
        capsule.Name = "JLMetaActions"
        capsule.Size = UDim2.new(0,(settings and info) and 38 or 19,0,16)
        capsule.Position = UDim2.new(1,-4,0,1)
        capsule.AnchorPoint = Vector2.new(1,0)
        capsule.BackgroundColor3 = C.pHdr
        capsule.BorderSizePixel = 0
        capsule.ZIndex = 56
        capsule.Parent = wrapper
        corner(7,capsule)

        local function make(iconName,help,order,action)
            local button = Instance.new("TextButton")
            button.Name = iconName == "settings" and "JLSettingsAction" or "JLInfoAction"
            button.Size = UDim2.new(0,17,0,16)
            button.Position = UDim2.new(0,(order-1)*19,0,0)
            button.BackgroundTransparency = 1
            button.BorderSizePixel = 0
            button.AutoButtonColor = false
            button.Text = ""
            button.ZIndex = 57
            button.Parent = capsule
            local icon = mkIcon(button,iconName,11,58)
            icon.AnchorPoint = Vector2.new(0.5,0.5)
            icon.Position = UDim2.new(0.5,0,0.5,0)
            icon.Size = UDim2.new(0,11,0,11)
            if icon:IsA("TextLabel") then icon.TextColor3 = ac else icon.ImageColor3 = ac end
            button.MouseEnter:Connect(function()
                if touchLast() then return end
                tw(capsule,{BackgroundColor3=C.btnHov},0.1)
            end)
            button.MouseLeave:Connect(function()
                tw(capsule,{BackgroundColor3=C.pHdr},0.1)
            end)
            tip(button,help)
            button.MouseButton1Click:Connect(action)
            JL._metaButtons[#JL._metaButtons + 1] = button
            button.Visible = not JL._remoteEditActive
        end

        local order = 1
        if settings then
            make("settings","Settings",order,function()
                openMetaPanel((definition.Name or "Control") .. " · Settings",definition.Settings,true)
            end)
            order = order + 1
        end
        if info then
            make("info","More information",order,function()
                openMetaPanel((definition.Name or "Control") .. " · Info",definition.Info,false)
            end)
        end
    end
    local function newRow(h2)
        iOrd = iOrd + 1
        local r = Instance.new("Frame"); r.Size = UDim2.new(1,0,0,h2); r.BackgroundTransparency = 1; r.BorderSizePixel = 0; r.LayoutOrder = iOrd; r.Parent = content
        JL._newRows[#JL._newRows + 1] = r
        return r
    end
    local function hover(b,base,hov)
        -- цвета роли (C.btnBg / C.btnHov) читаются «вживую», чтобы смена темы продолжала работать
        local liveB, liveH = (base == nil or base == C.btnBg), (hov == nil or hov == C.btnHov)
        b.MouseEnter:Connect(function()
            if touchLast() then return end
            b:SetAttribute("JLHover", true); tw(b,{BackgroundColor3 = liveH and C.btnHov or hov},.1)
        end)
        b.MouseLeave:Connect(function()
            b:SetAttribute("JLHover", false); tw(b,{BackgroundColor3 = liveB and C.btnBg or base},.1)
        end)
    end
    local function regFlag(flag,ctrl,noSave)
        if not flag then return end
        JL._registry[flag] = ctrl
        if noSave then JL._noSave[flag] = true else JL._noSave[flag] = nil end
    end
    local function mergeLock(ret,row,o)
        local lh = attachLockHidden(row, o)
        ret.SetLocked = lh.SetLocked; ret.SetHidden = lh.SetHidden; ret.IsLocked = lh.IsLocked; ret.IsHidden = lh.IsHidden
        ret.ToggleLocked = lh.ToggleLocked; ret.ToggleHidden = lh.ToggleHidden
        ret.Row = row
        return ret
    end
    function Sec:Toggle(o)
        o = o or {}
        local had = cfgHas(o.Flag); local state = cfgGet(o.Flag, o.Default or false)
        local name = o.Name or "Toggle"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - ((ST.swW or 34) + 14) - iconW
        local row = newRow(fitH(name, 12, GB, labW, ROWMIN, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(CCR,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        local titleLabel = newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local sw = mkSwitch(bg, UDim2.new(1,-((ST.swW or 34) + 10),0.5,-((ST.swH or 18) / 2)), state, ac)
        local ret
        local watchers = {}
        local function notifyW(v) for _,w in ipairs(watchers) do pcall(w, v) end end
        local function commitState(v)
            state = v; sw.Set(v); cfgSet(o.Flag, v)
            if o.Callback then pcall(o.Callback, v) end
            notifyW(v)
        end
        local function click()
            local nxt = not state
            local when = o.NeedsWhen or "On"
            if o.Needs and (when == "Both" or (when == "On") == nxt) and GUIDE.block(o, row, function() commitState(nxt) end) then return end
            commitState(nxt)
        end
        bg.MouseButton1Click:Connect(click)
        if o.Callback and had then pcall(o.Callback, state) end
        ret = {
            Set = function(_,v) state = v; sw.Set(v); cfgSet(o.Flag, v); notifyW(v) end, Get = function() return state end,
            Click = function() click() end, Watch = function(_,fn) watchers[#watchers + 1] = fn end,
        }
        -- Keep the Remote edit layout inside this Toggle's scope so it can resize
        -- the real label and switch instances instead of relying on out-of-scope locals.
        ret._remoteEditLayout = function(editing)
            local reserve = editing and 32 or 0
            bg.Size = UDim2.new(1,-reserve,bg.Size.Y.Scale,bg.Size.Y.Offset)
            bg.ClipsDescendants = true
            titleLabel.Size = UDim2.new(0,math.max(0,labW - reserve - (editing and 8 or 0)),1,0)
            titleLabel.ClipsDescendants = true
            sw.Frame.Position = UDim2.new(1,editing and -((ST.swW or 34) + 42) or -((ST.swW or 34) + 10),0.5,-((ST.swH or 18) / 2))
        end
        regFlag(o.Flag, ret, o.NoSave)
        local out = mergeLock(ret, row, o)
        if o.Remote then JL._remoteAttach("Toggle", o, out) end
        return out
    end
    function Sec:ToggleGroup(o)
        o = o or {}
        local mode = (o.Mode == "Move") and "Move" or "Lock"
        local clearOthers = o.ClearOthers ~= false
        local maxActive = tonumber(o.MaxActive)
        local order, defs, items, state, mset, fifo = {}, {}, {}, {}, {}, {}
        for _,it in ipairs(o.Options or {}) do
            local d = type(it) == "table" and it or {Name = tostring(it)}
            local n = d.Name or "Item"
            order[#order + 1] = n; defs[n] = d
        end
        if #order == 0 then return nil end
        local masterList = {}
        local ml = o.Masters
        if type(ml) == "string" then ml = {ml} end
        for _,m in ipairs(ml or {order[1]}) do if defs[m] and not mset[m] then mset[m] = true; masterList[#masterList + 1] = m end end
        local defaults = {}
        if type(o.Default) == "string" then defaults[o.Default] = true
        elseif type(o.Default) == "table" then for _,n in ipairs(o.Default) do defaults[n] = true end end
        local msg = o.LockedMessage or ("Turn off " .. table.concat(masterList, " / ") .. " first")
        local building = true
        local function anyMaster() for _,m in ipairs(masterList) do if state[m] then return true end end return false end
        local function activeList() local t = {}; for _,n in ipairs(order) do if state[n] then t[#t + 1] = n end end; return t end
        local function refreshLocks()
            local lock = mode == "Lock" and anyMaster()
            for _,n in ipairs(order) do if not mset[n] then items[n]:SetLocked(lock) end end
        end
        local function fire(n,v,quiet)
            if quiet then return end
            local d = defs[n]
            if d.Callback then pcall(d.Callback, v) end
            if o.Callback then pcall(o.Callback, n, v, activeList()) end
        end
        local function dropFifo(n)
            for i = #fifo,1,-1 do if fifo[i] == n then table.remove(fifo,i) end end
        end
        local function setQuiet(n,v)
            state[n] = v; items[n]:Set(v)
            dropFifo(n)
            if v and not mset[n] then fifo[#fifo + 1] = n end
        end
        local function onChange(n,v,quiet)
            state[n] = v
            dropFifo(n)
            if v and not mset[n] then fifo[#fifo + 1] = n end
            if v then
                if mset[n] then
                    if clearOthers then
                        for _,x in ipairs(order) do
                            if not mset[x] and state[x] then setQuiet(x,false); fire(x,false,quiet) end
                        end
                    end
                else
                    if mode == "Move" then
                        for _,m in ipairs(masterList) do
                            if state[m] then setQuiet(m,false); fire(m,false,quiet) end
                        end
                    end
                    if maxActive and maxActive >= 1 then
                        while #fifo > maxActive do
                            local old = table.remove(fifo,1)
                            if old == n then break end
                            setQuiet(old,false); fire(old,false,quiet)
                        end
                    end
                end
            end
            refreshLocks()
            fire(n,v,quiet)
        end
        if o.Name then self:Divider({Label = o.Name}) end
        local hadSaved = false
        for _,n in ipairs(order) do
            local d = defs[n]
            local flag = d.Flag or (o.Flag and (o.Flag .. "_" .. n) or nil)
            if cfgHas(flag) then hadSaved = true end
            items[n] = self:Toggle({
                Name = n, Flag = flag, Default = d.Default or defaults[n] or false, Icon = d.Icon, Tooltip = d.Tooltip, NoSave = o.NoSave,
                Background = d.Background or o.Background, LockedTitle = o.LockedTitle or "Locked", LockedMessage = msg, LockIcon = o.LockIcon,
                Callback = function(v) if building then state[n] = v else onChange(n,v) end end,
            })
            state[n] = items[n]:Get()
        end
        building = false
        if anyMaster() and clearOthers then
            for _,x in ipairs(order) do if not mset[x] and state[x] then setQuiet(x,false) end end
        end
        for _,n in ipairs(order) do if state[n] and not mset[n] then fifo[#fifo + 1] = n end end
        if maxActive and maxActive >= 1 then
            while #fifo > maxActive do setQuiet(table.remove(fifo,1),false) end
        end
        refreshLocks()
        if hadSaved then for _,n in ipairs(order) do fire(n,state[n]) end end
        local ret = {Items = items}
        function ret.Get() local t = {}; for k,v in pairs(state) do t[k] = v end; return t end
        function ret.GetActive() return activeList() end
        function ret.GetMode() return mode end
        function ret.SetMode(_,m) mode = (m == "Move") and "Move" or "Lock"; refreshLocks() end
        function ret.Set(_,n,v,fireCallbacks)
            if items[n] == nil then return false end
            v = v and true or false
            if state[n] == v then return true end
            if mode == "Lock" and v and not mset[n] and anyMaster() then return false end
            items[n]:Set(v)
            onChange(n,v,fireCallbacks ~= true)
            return true
        end
        return ret
    end
    function Sec:Slider(o)
        o = o or {}
        local vmin = o.Min or 0; local vmax = o.Max or 100; local step = o.Step or o.Increment or 1
        local dec = decimalsOf(step); local suffix = o.Suffix or ""
        local had = cfgHas(o.Flag)
        local val = snap(tonumber(cfgGet(o.Flag, o.Default or vmin)) or vmin, vmin, vmax, step)
        local name = o.Name or "Slider"; local iconW = o.Icon and ICONW or 0
        local inline = ST.sliderInline == true
        local labelW = inline and math.clamp(#name * 7 + 8, 44, math.floor(INNER * 0.4)) or 0
        local boxW, boxH = inline and 46 or 58, inline and 26 or 18
        local topH = inline and ROWMIN or fitH(name, 12, GB, INNER - 4 - 66 - iconW, 18, 2)
        local row = newRow(inline and topH or (topH + 24))
        tip(row, o.Tooltip)
        local holder = row
        if inline then
            holder = Instance.new("Frame"); holder.Size = UDim2.new(1,0,1,0); holder.BackgroundColor3 = C.btnBg; holder.BorderSizePixel = 0; holder.Parent = row
            corner(CCR,holder); stroke(C.border,1,holder)
        end
        iconAtLabel(holder, o.Icon, topH)
        local eL = inline and 0 or edgeIcon(row, o.IconLeft, true, topH + 5)
        local eR = inline and 0 or edgeIcon(row, o.IconRight, false, topH + 5)
        newTxt(inline
            and {Parent=holder,Text=name,Font=GB,Size=12,Sz=UDim2.new(0,labelW,1,0),Pos=UDim2.new(0,12 + iconW,0,0)}
            or {Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-66 - iconW,0,topH),Pos=UDim2.new(0,4 + iconW,0,0)})
        local box = Instance.new("TextBox"); box.Size = UDim2.new(0,boxW,0,boxH)
        box.Position = inline and UDim2.new(1,-(boxW + 8),0.5,-boxH / 2) or UDim2.new(1,-58,0,math.floor((topH - 18) / 2))
        box.BackgroundColor3 = C.pHdr; box.BorderSizePixel = 0; box.Font = GB; box.TextSize = 11; box.TextColor3 = C.dim; box.ClearTextOnFocus = false
        box.Text = fmtNum(val, dec) .. suffix; box.Parent = holder; corner(inline and 8 or 5,box)
        local bar
        bar = mkSliderBar(holder,
            inline and UDim2.new(0,16 + labelW + iconW,0.5,-3) or UDim2.new(0,6 + eL,0,topH + 9),
            inline and UDim2.new(1,-(16 + labelW + iconW + boxW + 22),0,6) or UDim2.new(1,-12 - eL - eR,0,6),
            ac, vmin, vmax, step, val, function(v)
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
        return mergeLock(ret, row, o)
    end
    function Sec:Button(o)
        o = o or {}
        local iconW = o.Icon and ICONW or 0
        local row = newRow(fitH(o.Name or "Button", 12, GB, INNER - 20 - iconW, ROWMIN, 14))
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundColor3 = C.btnBg; btn.BorderSizePixel = 0; btn.AutoButtonColor = false
        btn.Text = ""; btn.Font = GB; btn.TextSize = 12; btn.TextColor3 = C.txt; btn.Parent = row
        local fill = ST.btnFill == true
        local function curBase() return fill and ac or C.btnBg end
        local function curHov() return fill and ac:Lerp(Color3.new(1,1,1),0.14) or C.btnHov end
        btn.BackgroundColor3 = curBase()
        corner(CCR,btn); local btnStroke = stroke(C.border,1,btn); if fill then btnStroke.Transparency = 1 end
        hover(btn, fill and curBase() or C.btnBg, fill and curHov() or C.btnHov); tip(btn, o.Tooltip)
        if fill and ST.btnGradient then
            local bgG = Instance.new("UIGradient"); bgG.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(190,175,240)); bgG.Rotation = 0; bgG.Parent = btn
        end
        iconSlot(btn, o.Icon)
        newTxt({Parent=btn,Text=o.Name or "Button",Font=GB,Size=12,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-10 - iconW,1,0),Pos=UDim2.new(0,iconW,0,0)})
        if fill and ST.btnChevron then
            newTxt({Parent=btn,Text="›",Font=GB,Size=22,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,24,1,0),Pos=UDim2.new(1,-32,0,0),Z=18})
        end
        local presses = 0
        local function press()
            presses = presses + 1
            local fl = (btn:GetAttribute("JLFlash") or 0) + 1; btn:SetAttribute("JLFlash", fl)
            tw(btn,{BackgroundColor3 = fill and ac:Lerp(Color3.new(1,1,1),0.3) or ac},.06)
            trackedDelay(.14, function()
                if btn:GetAttribute("JLFlash") ~= fl then return end
                tw(btn,{BackgroundColor3 = btn:GetAttribute("JLHover") and curHov() or curBase()},.12)
            end)
            if o.Callback then pcall(o.Callback) end
        end
        local function activate()
            if o.Needs and GUIDE.block(o, row, press) then return end
            press()
        end
        btn.MouseButton1Click:Connect(activate)
        local bret = {Instance = btn, Get = function() return presses end, Click = function() activate() end}
        regFlag(o.Flag, bret, true)
        local out = mergeLock(bret, row, o)
        if o.Remote then JL._remoteAttach("Button", o, out) end
        return out
    end
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
        return mergeLock(ret, row, o)
    end
    local function getDropdownOptionIcon(optionName,o)
        local custom = o.OptionIcons and o.OptionIcons[optionName]
        if custom ~= nil then return custom, nil end
        if o.Icons == true then
            local players = game:GetService("Players")
            for _,player in ipairs(players:GetPlayers()) do
                if player.Name == tostring(optionName) or player.DisplayName == tostring(optionName) then
                    return nil, player
                end
            end
        end
        return nil, nil
    end
    local function addDropdownOptionIcon(parent,optionName,o,height)
        local custom,player = getDropdownOptionIcon(optionName,o)
        if player then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0,20,0,20)
            img.Position = UDim2.new(0,7,0,math.floor((height - 20) / 2))
            img.BackgroundColor3 = C.pHdr
            img.BorderSizePixel = 0
            img.ScaleType = Enum.ScaleType.Crop
            img.Parent = parent
            corner(10,img)
            img:SetAttribute("JLNoRepaint", true)
            trackedSpawn(function()
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
                end)
                if ok and img.Parent then img.Image = content end
            end)
            return 24
        elseif custom ~= nil then
            local ic = mkIcon(parent,custom,20,5)
            ic.Position = UDim2.new(0,7,0,math.floor((height - 20) / 2))
            ic.Size = UDim2.new(0,20,0,20)
            if ic:IsA("TextLabel") then
                ic.TextColor3 = ac
            elseif tostring(custom):match("^%d+$") or tostring(custom):match("^rbxassetid://") then
                ic.ImageColor3 = Color3.new(1,1,1)
                ic.ScaleType = Enum.ScaleType.Fit
            else
                ic.ImageColor3 = ac
            end
            return 24
        end
        return 0
    end
    function Sec:Dropdown(o)
        o = o or {}
        local rawOptions = o.Options or {}
        local options, optionMeta, optionLabels = {}, {}, {}
        for _,entry in ipairs(rawOptions) do
            if isDividerOpt(entry) then options[#options + 1] = entry
            elseif type(entry) == "table" then
                local value = entry.Value
                if value == nil then value = entry.Name end
                if value ~= nil then options[#options + 1] = value; optionMeta[value] = entry; optionLabels[value] = tostring(entry.Name or value) end
            else options[#options + 1] = entry; optionLabels[entry] = tostring(entry) end
        end
        local multi = o.MultiSelect; local maxSel = o.MaxSelect or (multi and math.max(#options,1) or 1)
        local selected = {}
        local had = cfgHas(o.Flag)
        local saved = cfgGet(o.Flag, o.Default)
        if saved then
            if type(saved) == "table" then for _,v in ipairs(saved) do selected[v] = true end
            elseif saved ~= "" then selected[saved] = true end
        end
        local baseName = o.Name or "Dropdown"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 30 - iconW
        local function labelText()
            if o.Static then return baseName end
            local picked = {}
            for _,opt in ipairs(options) do if not isDividerOpt(opt) and selected[opt] then picked[#picked + 1] = optionLabels[opt] or tostring(opt) end end
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
        for i,optName in ipairs(options) do
            local meta = optionMeta[optName]
            local label = optionLabels[optName] or tostring(optName)
            local actionsWidth = meta and ((meta.Info and 22 or 0) + (type(meta.Settings) == "table" and #meta.Settings > 0 and 22 or 0)) or 0
            heights[i] = isDividerOpt(optName) and dividerHeight(optName) or fitH(label, 11, GB, optW - actionsWidth, 30, 12)
            total = total + heights[i] + 2
        end
        if o.Search then total = total + 28 end
        local TOTAL = math.min(total, 180); local dropOpen = false
        local container = Instance.new("ScrollingFrame"); container.Size = UDim2.new(1,0,0,0); container.Position = UDim2.new(0,0,0,bgH + 4); container.BackgroundColor3 = C.pHdr
        container.BorderSizePixel = 0; container.Visible = false; container.ClipsDescendants = true; container.ScrollBarThickness = 3; container.ScrollBarImageColor3 = C.border
        container.CanvasSize = UDim2.new(0,0,0,0); container.Parent = row; corner(7,container); stroke(C.border,1,container)
        local cStack = Instance.new("UIListLayout"); cStack.SortOrder = Enum.SortOrder.LayoutOrder; cStack.Padding = UDim.new(0,2); cStack.Parent = container; pad(4,4,4,4,container)
        cStack:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.CanvasSize = UDim2.new(0,0,0,unscale(cStack.AbsoluteContentSize.Y) + 8) end)
        local optRefs = {}
        local sBox
        if o.Search then
            local sHold = Instance.new("Frame"); sHold.Size = UDim2.new(1,0,0,24); sHold.BackgroundTransparency = 1; sHold.LayoutOrder = 0; sHold.Parent = container
            sBox = Instance.new("TextBox"); sBox.Size = UDim2.new(1,0,1,0); sBox.BackgroundColor3 = C.input; sBox.BorderSizePixel = 0
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
            row.Size = UDim2.new(1,0,0,(dropOpen and (bgH + 4 + TOTAL) or bgH))
        end
        local function mark(ref,on) ref.mark.Visible = on; ref.label.TextColor3 = on and ac or C.txt end
        local rules = multi and groupRules(o) or nil
        local function masterOn()
            if not rules then return false end
            for _,m in ipairs(rules.list) do if selected[m] then return true end end
            return false
        end
        local function refreshBlocked()
            if not rules then return end
            local lock = (not rules.move) and masterOn()
            for nm,ref in pairs(optRefs) do ref.label.TextTransparency = (lock and not rules.set[nm]) and 0.6 or 0 end
        end
        local function normalize()
            if rules and rules.clear and masterOn() then
                for nm in pairs(selected) do if not rules.set[nm] then selected[nm] = nil end end
            end
        end
        normalize()
        for i,optName in ipairs(options) do
            if isDividerOpt(optName) then
                mkOptDivider(container, i, optName, heights[i])
            else
            local meta = optionMeta[optName]
            local labelText = optionLabels[optName] or tostring(optName)
            local actionCount = meta and ((meta.Info and 1 or 0) + (type(meta.Settings) == "table" and #meta.Settings > 0 and 1 or 0)) or 0
            local actionWidth = actionCount * 25
            local opt = Instance.new("Frame"); opt.Size = UDim2.new(1,0,0,heights[i]); opt.BackgroundColor3 = C.btnBg
            opt.BorderSizePixel = 0; opt.LayoutOrder = i; opt.Parent = container; corner(6,opt)
            local selectButton = Instance.new("TextButton")
            selectButton.Name = "JLDropdownOptionSelect"; selectButton.Size = UDim2.new(1,-actionWidth,1,0)
            selectButton.BackgroundTransparency = 1; selectButton.BorderSizePixel = 0
            selectButton.AutoButtonColor = false; selectButton.Text = ""; selectButton.Parent = opt
            local optIconW = addDropdownOptionIcon(selectButton,optName,o,heights[i])
            local optLbl = newTxt({Parent=selectButton,Text=labelText,Font=GB,Size=11,Wrap=true,Sz=UDim2.new(1,-16-optIconW,1,0),Pos=UDim2.new(0,10+optIconW,0,0)})
            local mk = Instance.new("Frame"); mk.Size = UDim2.new(0,3,0.6,0); mk.Position = UDim2.new(0,2,0.2,0)
            mk.BackgroundColor3 = ac; mk.BorderSizePixel = 0; mk.Parent = selectButton; corner(2,mk)
            optRefs[optName] = {opt = opt, button = selectButton, mark = mk, label = optLbl}
            mark(optRefs[optName], selected[optName] or false)
            hover(opt, C.btnBg, C.btnHov)
            if o.OptionTooltips then tip(selectButton, o.OptionTooltips[optName]) end
            if meta then
                local actionIndex = 0
                local function addOptionAction(iconName,caption,callback)
                    actionIndex = actionIndex + 1
                    local button = Instance.new("TextButton")
                    button.Name = iconName == "info" and "JLOptionInfo" or "JLOptionSettings"
                    button.Size = UDim2.new(0,22,0,22); button.Position = UDim2.new(1,-(actionIndex * 25) + 1,0.5,-11)
                    button.BackgroundColor3 = C.pHdr; button.BorderSizePixel = 0
                    button.AutoButtonColor = false; button.Text = ""; button.ZIndex = 16; button.Parent = opt
                    corner(6,button)
                    local glyph = mkIcon(button,iconName,12,17)
                    glyph.AnchorPoint = Vector2.new(0.5,0.5); glyph.Position = UDim2.new(0.5,0,0.5,0)
                    glyph.Size = UDim2.new(0,12,0,12)
                    if glyph:IsA("TextLabel") then glyph.TextColor3 = ac else glyph.ImageColor3 = ac end
                    tip(button,caption)
                    button.MouseButton1Click:Connect(callback)
                    JL._metaButtons[#JL._metaButtons + 1] = button
                    button.Visible = not JL._remoteEditActive
                end
                if type(meta.Settings) == "table" and #meta.Settings > 0 then
                    addOptionAction("settings","Item settings",function() openMetaPanel(labelText .. " · Settings",meta.Settings,true) end)
                end
                if meta.Info then
                    addOptionAction("info","Item information",function() openMetaPanel(labelText .. " · Info",meta.Info,false) end)
                end
            end
            if o.OptionLocked or o.OptionHidden or o.OptionRequires or o.OptionHiddenUntil then
                attachLockHidden(opt, {
                    Locked = o.OptionLocked and o.OptionLocked[optName],
                    Hidden = o.OptionHidden and o.OptionHidden[optName],
                    Requires = o.OptionRequires and o.OptionRequires[optName],
                    HiddenUntil = o.OptionHiddenUntil and o.OptionHiddenUntil[optName],
                    LockedMessage = o.LockedMessage, LockedTitle = o.LockedTitle,
                })
            end
            selectButton.MouseButton1Click:Connect(function()
                if multi then
                    local willSelect = not selected[optName]
                    if rules and willSelect and not rules.move and not rules.set[optName] and masterOn() then
                        JL:Notify({Title = "Locked", Desc = "Turn off " .. table.concat(rules.list, " / ") .. " first", Type = "Warn", Duration = 2.5})
                        return
                    end
                    local cnt = 0; for _ in pairs(selected) do cnt = cnt + 1 end
                    if rules and willSelect then
                        local drop = {}
                        if rules.set[optName] then
                            if rules.clear then for nm in pairs(selected) do if not rules.set[nm] then drop[#drop + 1] = nm end end end
                        elseif rules.move then
                            for _,m in ipairs(rules.list) do if selected[m] then drop[#drop + 1] = m end end
                        end
                        if cnt - #drop >= maxSel then return end
                        for _,nm in ipairs(drop) do selected[nm] = nil; if optRefs[nm] then mark(optRefs[nm], false) end end
                        selected[optName] = true; mark(optRefs[optName], true)
                    elseif selected[optName] then selected[optName] = nil; mark(optRefs[optName], false)
                    elseif cnt < maxSel then selected[optName] = true; mark(optRefs[optName], true)
                    else return end
                    refreshBlocked()
                    local sel = {}; for _,nm in ipairs(options) do if not isDividerOpt(nm) and selected[nm] then sel[#sel + 1] = nm end end
                    cfgSet(o.Flag, sel); refreshLabel(); if o.Callback then pcall(o.Callback, sel) end
                else
                    for _,ref in pairs(optRefs) do mark(ref, false) end
                    if selected[optName] then
                        selected = {}
                        cfgSet(o.Flag, nil)
                        refreshLabel()
                        if o.Callback then pcall(o.Callback, nil) end
                    else
                        selected = {}; selected[optName] = true; mark(optRefs[optName], true)
                        cfgSet(o.Flag, optName); refreshLabel()
                        if o.Callback then pcall(o.Callback, optName) end
                    end
                end
            end)
            end
        end
        refreshBlocked()
        bg.MouseButton1Click:Connect(function()
            dropOpen = not dropOpen; container.Visible = true
            tw(container,{Size = UDim2.new(1,0,0,dropOpen and TOTAL or 0)},.2)
            tw(row,{Size = UDim2.new(1,0,0,(dropOpen and (bgH + 4 + TOTAL) or bgH))},.2)
            darr.Text = dropOpen and "▲" or "▼"
            if not dropOpen then trackedDelay(.21, function() if not dropOpen then container.Visible = false end end) end
        end)
        if o.Callback and had then
            if multi then local sel = {}; for _,nm in ipairs(options) do if not isDividerOpt(nm) and selected[nm] then sel[#sel + 1] = nm end end; pcall(o.Callback, sel)
            else for k in pairs(selected) do pcall(o.Callback, k) end end
        end
        ret = {
            _searchTargetRows = searchTargetRows,
            _searchOptionRows = optRefs,
            Open = function()
                if not dropOpen then
                    dropOpen = true; container.Visible = true
                    tw(container,{Size = UDim2.new(1,0,0,TOTAL)},.2)
                    tw(row,{Size = UDim2.new(1,0,0,bgH + 4 + TOTAL)},.2)
                    darr.Text = "▲"
                end
            end,
            Get = function() return selected end,
            Set = function(_,v)
                selected = {}
                if type(v) == "table" then for _,x in ipairs(v) do selected[x] = true end elseif v then selected[v] = true end
                normalize()
                for nm,ref in pairs(optRefs) do mark(ref, selected[nm] or false) end
                refreshBlocked()
                refreshLabel()
            end,
            GetDynamicState = function()
                return {Open = dropOpen, Search = sBox and sBox.Text or nil, CanvasPosition = container.CanvasPosition}
            end,
            RestoreDynamicState = function(_,state)
                if type(state) ~= "table" then return end
                if sBox and state.Search ~= nil then sBox.Text = state.Search end
                if state.Open then
                    dropOpen = true
                    container.Visible = true
                    container.Size = UDim2.new(1,0,0,TOTAL)
                    row.Size = UDim2.new(1,0,0,bgH + 4 + TOTAL)
                    darr.Text = "▲"
                end
                if state.CanvasPosition then
                    trackedDefer(function()
                        if container.Parent then container.CanvasPosition = state.CanvasPosition end
                    end)
                end
            end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        local control = mergeLock(ret, row, o)
        addMetaButtons(row,o)
        return control
    end
    function Sec:TextSlider(o)
        o = o or {}
        local steps
        if o.Options then
            steps = {}
            for i,l in ipairs(o.Options) do steps[i] = {label = tostring(l), value = l} end
        else
            steps = buildSteps(o)
        end
        if #steps == 0 then steps = {{label = "-", value = 0}} end
        local n = #steps
        local had = cfgHas(o.Flag)
        local function idxOf(v)
            if v == nil then return nil end
            for i,s in ipairs(steps) do if s.value == v or s.label == tostring(v) then return i end end
        end
        local init = idxOf(cfgGet(o.Flag, o.Default)) or idxOf(o.Default) or 1
        local name = o.Name or "Level"; local iconW = o.Icon and ICONW or 0
        local widest = 0
        for _,s in ipairs(steps) do widest = math.max(widest, TextService:GetTextSize(s.label, 11, GB, Vector2.new(300,20)).X) end
        local chipW = math.clamp(math.ceil(widest) + 20, 58, 130)
        local topH = fitH(name, 12, GB, INNER - 14 - chipW - iconW, 18, 2)
        local ticks = n > 1 and n <= 12 and o.Ticks ~= false
        local row = newRow(topH + 24 + (ticks and 8 or 0))
        tip(row, o.Tooltip); iconAtLabel(row, o.Icon, topH)
        local eL = edgeIcon(row, o.IconLeft, true, topH + 5)
        local eR = edgeIcon(row, o.IconRight, false, topH + 5)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(1,-chipW - 10 - iconW,0,topH),Pos=UDim2.new(0,4 + iconW,0,0)})
        local chip = Instance.new("TextLabel"); chip.Size = UDim2.new(0,chipW,0,18); chip.Position = UDim2.new(1,-chipW,0,math.floor((topH - 18) / 2)); chip.BackgroundColor3 = C.pHdr; chip.BorderSizePixel = 0
        chip.Font = GB; chip.TextSize = 11; chip.TextColor3 = ac; chip.Text = steps[init].label; chip.Parent = row; corner(5,chip)
        local cur = init
        local bar = mkSliderBar(row, UDim2.new(0,6 + eL,0,topH + 9), UDim2.new(1,-12 - eL - eR,0,6), ac, 1, n, 1, init, function(v)
            cur = v; chip.Text = steps[v].label; cfgSet(o.Flag, steps[v].value)
            if o.Callback then pcall(o.Callback, steps[v].value, v, steps[v].label) end
        end)
        if ticks then
            local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,-12 - eL - eR,0,4); holder.Position = UDim2.new(0,6 + eL,0,topH + 22); holder.BackgroundTransparency = 1; holder.Parent = row
            for i = 1,n do
                local t = Instance.new("Frame"); t.Size = UDim2.new(0,2,1,0); t.Position = UDim2.new((i - 1) / (n - 1),-1,0,0); t.BackgroundColor3 = C.border; t.BackgroundTransparency = 0.35; t.BorderSizePixel = 0; t.Parent = holder
            end
        end
        if o.Callback and had then pcall(o.Callback, steps[init].value, init, steps[init].label) end
        local ret = {
            Get = function() return steps[cur].value, cur, steps[cur].label end,
            Set = function(_,v)
                local i = idxOf(v) or (type(v) == "number" and math.clamp(math.floor(v), 1, n)) or cur
                bar.Set(i, true); cur = i; chip.Text = steps[i].label; cfgSet(o.Flag, steps[i].value)
            end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        return mergeLock(ret, row, o)
    end
    Sec.NumberTextSlider = Sec.TextSlider
    function Sec:ColorPicker(o)
        o = o or {}
        local had = cfgHas(o.Flag)
        local cur = cfgGet(o.Flag, o.Default or Color3.fromRGB(255,255,255))
        if type(cur) == "table" then cur = Color3.fromRGB(cur[1] or 255, cur[2] or 255, cur[3] or 255) end
        if o.Flag then JL.Flags[o.Flag] = cur end
        local name = o.Name or "Color"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - ((ST.cpW or 34) + 18 + (ST.cpChev and 18 or 0)) - iconW
        local row = newRow(fitH(name, 12, GB, labW, ROWMIN, 14))
        local bg = Instance.new("TextButton"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.Text = ""; bg.AutoButtonColor = false; bg.BorderSizePixel = 0; bg.Parent = row
        corner(CCR,bg); stroke(C.border,1,bg); hover(bg, C.btnBg, C.btnHov); tip(bg, o.Tooltip)
        iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local CPW, CPH = ST.cpW or 34, ST.cpH or 18
        local chevW = ST.cpChev and 18 or 0
        local sw = Instance.new("Frame"); sw.Size = UDim2.new(0,CPW,0,CPH); sw.Position = UDim2.new(1,-(CPW + 10 + chevW),0.5,-CPH / 2); sw.BackgroundColor3 = cur; sw.BorderSizePixel = 0; sw.Parent = bg; corner(ST.cpCorner or 5,sw); stroke(C.border,1,sw)
        if ST.cpChev then newTxt({Parent=bg,Text="›",Font=GB,Size=22,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,16,1,0),Pos=UDim2.new(1,-24,0,0),Z=18}) end
        sw:SetAttribute("JLNoRepaint", true)
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
        return mergeLock(ret, row, o)
    end
    function Sec:Keybind(o)
        o = o or {}
        local defName = (typeof(o.Default) == "EnumItem" and o.Default.Name) or (o.Default and tostring(o.Default)) or "None"
        local nm = cfgGet(o.Flag, defName)
        local name = o.Name or "Keybind"; local iconW = o.Icon and ICONW or 0; local labW = INNER - 10 - 96 - iconW
        local row = newRow(fitH(name, 12, GB, labW, 32, 14))
        local bg = Instance.new("Frame"); bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = C.btnBg; bg.BorderSizePixel = 0; bg.Parent = row; corner(7,bg); stroke(C.border,1,bg)
        tip(bg, o.Tooltip); iconSlot(bg, o.Icon)
        newTxt({Parent=bg,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10 + iconW,0,0)})
        local kw, pw = {}, {}
        local chip = mkKeyChip(bg, UDim2.new(1,-94,0.5,-11), nm, function(k)
            cfgSet(o.Flag, k and k.Name or "None"); if o.Callback then pcall(o.Callback, k) end
            for _,w in ipairs(kw) do pcall(w, k) end
        end)
        keep(UIS.InputBegan:Connect(function(i,gp)
            if gp or JL._listening then return end
            local k = chip.Get()
            if k and i.KeyCode == k then
                if o.OnPress then pcall(o.OnPress) end
                for _,w in ipairs(pw) do pcall(w) end
            end
        end))
        local ret = {
            Get = function() return chip.Get() end,
            Set = function(_,k) chip.Set(k); cfgSet(o.Flag, k and k.Name or "None"); for _,w in ipairs(kw) do pcall(w, k) end end,
            Press = function() if o.OnPress then pcall(o.OnPress) end; for _,w in ipairs(pw) do pcall(w) end end,
            Watch = function(_,fn) kw[#kw + 1] = fn end, OnPulse = function(_,fn) pw[#pw + 1] = fn end,
        }
        regFlag(o.Flag, ret, o.NoSave)
        local out = mergeLock(ret, row, o)
        if o.Remote then JL._remoteAttach("Keybind", o, out) end
        return out
    end
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
        return mergeLock(ret, row, o)
    end
    function Sec:Group(o)
        o = o or {}
        local wA, wB = compactWidth(o.A), compactWidth(o.B)
        local gap = (o.A and o.B) and 14 or 0
        local totalW = wA + wB + gap
        local startX = math.max(10, INNER - totalW - 10)
        local labW = math.max(30, startX - 14)
        local name = o.Name or ""
        local h = math.max(36, fitH(name, 12, GB, labW, 0, 14))
        local row = newRow(h)
        tip(row, o.Tooltip)
        newTxt({Parent=row,Text=name,Font=GB,Size=12,Wrap=true,Sz=UDim2.new(0,labW,1,0),Pos=UDim2.new(0,10,0,0)})
        local ctrls = {}
        local x = startX
        if o.A then ctrls.A = mkCompactControl(row, x, wA, o.A, ac, regFlag, parentSg); x = x + wA + gap end
        if o.B then ctrls.B = mkCompactControl(row, x, wB, o.B, ac, regFlag, parentSg) end
        return mergeLock(ctrls, row, o)
    end
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
        return mergeLock({Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, sz, fnt, INNER - 8 - iconW, 16, 6)) end}, row, o)
    end
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
        img:SetAttribute("JLNoRepaint", true)
        local status = newTxt({Parent=box,Text="",Font=GM,Size=11,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,1,0)})
        local function setId(id)
            local s = tostring(id)
            img.Image = s:match("^%d+$") and ("rbxassetid://" .. s) or s
        end
        local function setPlayer(plr)
            status.Text = "loading..."
            trackedSpawn(function()
                local userId = (typeof(plr) == "Instance") and plr.UserId or tonumber(plr)
                if not userId then status.Text = "invalid player"; return end
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, o.ThumbSize or Enum.ThumbnailSize.Size180x180)
                end)
                if ok then img.Image = content; status.Text = "" else status.Text = "failed to load" end
            end)
        end
        if o.Player then setPlayer(o.Player) elseif o.Image then setId(o.Image) end
        return mergeLock({SetImage = function(_,id) setId(id) end, SetPlayer = function(_,plr) setPlayer(plr) end}, row, o)
    end
    function Sec:Label(o)
        o = o or {}
        local iconW = o.Icon and (ICONW + 2) or 0
        local h0 = fitH(o.Text or "", 11, G, INNER - 8 - iconW, 18, 4)
        local row = newRow(h0)
        tip(row, o.Tooltip)
        if o.Icon then local ic = mkIcon(row,o.Icon,13,5); ic.Position = UDim2.new(0,4,0,2); ic.Size = UDim2.new(0,13,0,13); if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end end
        local l = newTxt({Parent=row,Text=o.Text or "",Size=11,Color=o.Color or C.dim,Wrap=true,Sz=UDim2.new(1,-8 - iconW,1,0),Pos=UDim2.new(0,4 + iconW,0,0)})
        if o.RichText then l.RichText = true end
        return mergeLock({Set = function(_,t) l.Text = t; row.Size = UDim2.new(1,0,0,fitH(t, 11, G, INNER - 8 - iconW, 18, 4)) end}, row, o)
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
    -- ===== Preview UI: открытие из кнопки / тогла / дропдауна =====
    local function pvResolve(o)
        local pv = (o and o.Preview) or JL._preview
        if type(pv) == "table" and rawget(pv, "IsStub") then return nil end
        return pv
    end
    local function pvMissing()
        JL:Notify({Title = "Preview UI", Desc = "Create it first: local Preview = JL:Preview({...})", Type = "Warn", Duration = 3})
    end
    local function pvCopy(o) local t = {}; for k,v in pairs(o or {}) do t[k] = v end; return t end
    function Sec:PreviewButton(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Open Preview"
        o2.Callback = function()
            local pv = pvResolve(o)
            if pv then pv:Open(o.Target) else pvMissing() end
            if cb then pcall(cb, pv) end
        end
        return self:Button(o2)
    end
    function Sec:PreviewToggle(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Preview Window"
        o2.Callback = function(v)
            local pv = pvResolve(o)
            if not pv then pvMissing(); return end
            if v then pv:Open(o.Target) else pv:Close() end
            if cb then pcall(cb, v) end
        end
        local ctrl = self:Toggle(o2)
        local pv0 = pvResolve(o)
        if pv0 and pv0.OnClosed then
            pv0:OnClosed(function() if ctrl and ctrl.Set then pcall(function() ctrl:Set(false) end) end end)
        end
        return ctrl
    end
    function Sec:PreviewDropdown(o)
        o = o or {}; local o2 = pvCopy(o); local cb = o.Callback
        o2.Name = o.Name or "Open Preview tab"
        o2.Options = function()
            local p = pvResolve(o)
            local names = {}
            if p then
                for _,t in ipairs(p:GetTabs()) do names[#names + 1] = t.Name end
            end
            return names
        end
        o2.Static = true; o2.MultiSelect = nil
        o2.Callback = function(sel)
            local p = pvResolve(o)
            if not p then pvMissing(); return end
            if sel and sel ~= "" then p:Open(sel) end
            if cb then pcall(cb, sel) end
        end
        return self:Dropdown(o2)
    end
    function Sec:Custom(height,setupFn)
        iOrd = iOrd + 1
        local f = Instance.new("Frame"); f.Size = UDim2.new(1,0,0,height); f.BackgroundTransparency = 1; f.LayoutOrder = iOrd; f.ClipsDescendants = true; f.Parent = content
        if setupFn then setupFn(f) end
        return f
    end
    for _,kind in ipairs({"Toggle","Slider","Button","Input","Dropdown","TextSlider","Segmented","Keybind","ColorPicker","Group","Screen"}) do
        local orig = Sec[kind]
        if orig then
            Sec[kind] = function(self,o)
                local from = #JL._newRows
                local ret = orig(self,o)
                local own = type(o) == "table" and o.Background or nil
                local rows = JL._newRows
                for i = from + 1, #rows do
                    BG.register(kind, BG.face(rows[i]), 7, own, true)
                    if type(o) == "table" and (kind == "Toggle" or kind == "Slider" or kind == "Button" or kind == "Input") then addMetaButtons(rows[i],o) end
                end
                if from == 0 then JL._newRows = {} end
                return ret
            end
        end
    end
    -- ===== Dynamic Dropdown options =====
    -- Options and Values accept tables or provider functions.
    -- AutoUpdate polls the providers; Refresh() remains available for manual updates.
    local function copyDropdownOptions(src)
        local out = {}
        for k,v in pairs(src or {}) do out[k] = v end
        return out
    end
    local function cloneDropdownData(value,seen)
        if type(value) ~= "table" then return value end
        seen = seen or {}
        if seen[value] then return seen[value] end
        local out = {}
        seen[value] = out
        for k,v in pairs(value) do
            out[cloneDropdownData(k,seen)] = cloneDropdownData(v,seen)
        end
        return out
    end
    local function sameDropdownData(a,b,seen)
        if a == b then return true end
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return false end
        seen = seen or {}
        if seen[a] == b then return true end
        seen[a] = b
        for k,v in pairs(a) do
            if not sameDropdownData(v,b[k],seen) then return false end
        end
        for k in pairs(b) do
            if a[k] == nil then return false end
        end
        return true
    end
    local function resolveDropdownOptions(source,fallback)
        if type(source) == "function" then
            local ok,result = pcall(source)
            if ok and type(result) == "table" then return result end
            return fallback or {}
        end
        if type(source) == "table" then return source end
        return {}
    end
    do
        local create = Sec.Dropdown
        Sec.Dropdown = function(self,o)
            o = o or {}
            local optionsSource = o.Options
            local lastOptions = cloneDropdownData(resolveDropdownOptions(optionsSource,{}))
            local buildOpts = copyDropdownOptions(o)
            buildOpts.Options = lastOptions
            local stable = create(self,buildOpts)
            if type(stable) ~= "table" then return stable end
            local refreshing = false
            local overrideOptions
            local refreshFn
            local function refresh()
                if refreshing then return false end
                local oldRow = stable.Row
                if not oldRow or not oldRow.Parent then return false end
                refreshing = true
                local nextOptions = cloneDropdownData(resolveDropdownOptions(overrideOptions or optionsSource,lastOptions))
                if sameDropdownData(lastOptions,nextOptions) then
                    refreshing = false
                    return true
                end
                local previous
                if stable.Get then
                    local ok,value = pcall(stable.Get)
                    if ok then previous = value end
                end
                local uiState
                if stable.GetDynamicState then
                    local ok,value = pcall(stable.GetDynamicState,stable)
                    if ok then uiState = value end
                end
                local nextOpts = copyDropdownOptions(o)
                nextOpts.Options = nextOptions
                nextOpts._DynamicState = uiState
                nextOpts.Callback = nil
                local oldLayout = oldRow.LayoutOrder
                local oldLocked = stable.IsLocked and stable.IsLocked() or false
                local oldHidden = stable.IsHidden and stable.IsHidden() or false
                local ok,newControl = pcall(create,self,nextOpts)
                if not ok or type(newControl) ~= "table" then
                    refreshing = false
                    return false
                end
                local selectedList = {}
                if type(previous) == "table" then
                    for _,item in ipairs(nextOptions) do
                        if not isDividerOpt(item) then
                            local value = type(item) == "table" and (item.Value or item.Name) or item
                            if value ~= nil and previous[value] then selectedList[#selectedList + 1] = value end
                        end
                    end
                elseif previous ~= nil then
                    for _,item in ipairs(nextOptions) do
                        if not isDividerOpt(item) then
                            local value = type(item) == "table" and (item.Value or item.Name) or item
                            if value == previous then selectedList[1] = value; break end
                        end
                    end
                end
                if not o.MultiSelect and #selectedList > 1 then
                    selectedList = {selectedList[1]}
                end
                if newControl.Set then
                    pcall(newControl.Set,newControl,o.MultiSelect and selectedList or selectedList[1])
                end
                if o.Flag then
                    cfgSet(o.Flag,o.MultiSelect and selectedList or selectedList[1])
                end
                if uiState and newControl.RestoreDynamicState then
                    pcall(newControl.RestoreDynamicState,newControl,uiState)
                end
                if newControl.Row then newControl.Row.LayoutOrder = oldLayout end
                if oldLocked and newControl.SetLocked then pcall(newControl.SetLocked,newControl,true) end
                if oldHidden and newControl.SetHidden then pcall(newControl.SetHidden,newControl,true) end
                oldRow:Destroy()
                for k in pairs(stable) do stable[k] = nil end
                for k,v in pairs(newControl) do stable[k] = v end
                lastOptions = nextOptions
                stable.Refresh = refreshFn
                stable.SetOptions = function(_,list)
                    if type(list) ~= "table" then return false end
                    overrideOptions = list
                    return refreshFn()
                end
                if o.Flag then JL._registry[o.Flag] = stable end
                refreshing = false
                return true
            end
            refreshFn = refresh
            stable.Refresh = refreshFn
            stable.SetOptions = function(_,list)
                if type(list) ~= "table" then return false end
                overrideOptions = list
                return refreshFn()
            end
            local interval
            if o.AutoUpdate == true then
                interval = tonumber(o.Interval) or 5
            elseif o.RefreshInterval ~= nil then
                interval = tonumber(o.RefreshInterval)
            end
            if interval and interval > 0 then
                trackedSpawn(function()
                    while stable.Row and stable.Row.Parent do
                        task.wait(math.max(interval,0.1))
                        if stable.Row and stable.Row.Parent then refreshFn() end
                    end
                end)
            end
            return stable
        end
    end
    local searchMethods = {
        Toggle = true, ToggleGroup = true, Slider = true, Button = true, Input = true,
        Dropdown = true, TextSlider = true, NumberTextSlider = true, ColorPicker = true,
        Keybind = true, Segmented = true, Group = true, Text = true, Screen = true,
        Label = true, PreviewButton = true, PreviewToggle = true, PreviewDropdown = true,
    }
    for methodName in pairs(searchMethods) do
        local original = Sec[methodName]
        if type(original) == "function" then
            Sec[methodName] = function(self, o, ...)
                local result = original(self, o, ...)
                if type(result) == "table" and result.Row and type(o) == "table" and JL._searchRegister then
                    JL._searchRegister({Name = o.Name or methodName, Kind = methodName, Row = result.Row, Control = result})
                    if methodName == "Dropdown" and type(o.Options) == "table" then
                        for _, optionName in ipairs(o.Options) do
                            if not isDividerOpt(optionName) then
                                local optionKey = type(optionName) == "table" and (optionName.Value or optionName.Name) or optionName
                                JL._searchRegister({
                                    Name = tostring(optionKey), Kind = "Option",
                                    ParentName = o.Name or methodName, Row = result.Row, Control = result,
                                    TargetResolver = function()
                                        local refs = result._searchOptionRows
                                        local ref = refs and refs[optionKey]
                                        return ref and ref.opt or nil
                                    end,
                                })
                            end
                        end
                    end
                end
                return result
            end
        end
    end
    return Sec
end
local function makeSection(parentFrame,title,parentSg,layoutOrder,colW,so,uiScale,attachTip)
    so = so or {}
    local ac = ST.uniformAccent and ACCENTS[1] or nxAc()
    local SP = ST.secPad or 8
    local iconW = so.Icon and 22 or 0
    local INNER = colW - 2 * SP
    local HH = ST.secHH or math.max(34, fitH(title, 13, GB, colW - 54 - iconW, 0, 0) + 16)
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel:SetAttribute("JLSearchSection", tostring(title or "Section"))
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    local SC = ST.secCorner or 10
    corner(SC,panel); local panelStroke = stroke(C.border,1,panel); panelStroke.Transparency = ST.secStrokeT or 0
    BG.register("Section", panel, SC, so.Background)
    if ST.decoratePanel then pcall(ST.decoratePanel, panel, ac, UI()) end
    local hdr, hfix, arrow, secBtn, hline
    local customHdr = ST.sectionHeader and ST.sectionHeader({panel = panel, HH = HH, ac = ac, title = title, so = so, colW = colW, attachTip = attachTip}, UI())
    if customHdr then
        hdr, hfix, arrow, secBtn, hline = customHdr.hdr, customHdr.hfix, customHdr.arrow, customHdr.btn, customHdr.hline
    else
    hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    local pill = Instance.new("Frame"); pill.Size = UDim2.new(0,3,0,14); pill.Position = UDim2.new(0,10,0.5,-7); pill.BackgroundColor3 = ac; pill.BorderSizePixel = 0; pill.ZIndex = 3; pill.Parent = hdr; corner(2,pill)
    if so.Icon then local ic = mkIcon(hdr, so.Icon, 15, 3); ic.Position = UDim2.new(0,22,0.5,-7); ic.Size = UDim2.new(0,15,0,15); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    newTxt({Parent=hdr,Text=title,Font=GB,Size=13,Wrap=true,Sz=UDim2.new(1,-54 - iconW,1,0),Pos=UDim2.new(0,22 + iconW,0,0),Z=3})
    arrow = newTxt({Parent=hdr,Text="▼",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,30,1,0),Pos=UDim2.new(1,-30,0,0),Z=3})
    secBtn = Instance.new("TextButton"); secBtn.Size = UDim2.new(1,0,1,0); secBtn.BackgroundTransparency = 1; secBtn.Text = ""; secBtn.ZIndex = 4; secBtn.Parent = hdr
    if attachTip and so.Tooltip then attachTip(hdr, so.Tooltip) end
    hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel
    end
    local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,HH + 1); content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = panel
    local list = Instance.new("UIListLayout"); list.FillDirection = Enum.FillDirection.Vertical; list.Padding = UDim.new(0,ST.secGap or 6); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = content
    pad(SP,SP,SP,SP,content)
    local collapsed = so.Collapsed or false; local storedH = 0; local animating = false
    local function fullH() return HH + 1 + storedH end
    local function updatePanel()
        local ch = list.AbsoluteContentSize.Y
        storedH = (ch > 0) and (unscale(ch) + 2 * SP) or 0
        content.Size = UDim2.new(1,0,0,storedH)
        if not collapsed and not animating then panel.Size = UDim2.new(1,0,0,fullH()) end
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanel)
    local function setCollapsed(c)
        collapsed = c; animating = true
        hfix.Visible = not c; hline.Visible = not c
        tw(arrow,{Rotation = c and 180 or 0},.2)
        if c then
            tw(panel,{Size = UDim2.new(1,0,0,HH)},.18)
            trackedDelay(.2, function() animating = false; if collapsed then content.Visible = false end end)
        else
            content.Visible = true; tw(panel,{Size = UDim2.new(1,0,0,fullH())},.18)
            trackedDelay(.2, function() animating = false; updatePanel() end)
        end
    end
    secBtn.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
    if collapsed then content.Visible = false; arrow.Rotation = 180; hfix.Visible = false; hline.Visible = false end
    local Sec = attachWidgets(content, INNER, ac, uiScale, parentSg, attachTip)
    Sec.Panel = panel
    function Sec:SetCollapsed(c) if c ~= collapsed then setCollapsed(c) end end
    JL._secPanels[panel] = Sec
    function Sec:ToggleCollapsed() setCollapsed(not collapsed); return collapsed end
    function Sec:IsCollapsed() return collapsed end
    local secLock = attachLockHidden(panel, so)
    Sec.SetLocked = secLock.SetLocked; Sec.SetHidden = secLock.SetHidden
    Sec.IsLocked = secLock.IsLocked; Sec.IsHidden = secLock.IsHidden
    Sec.ToggleLocked = secLock.ToggleLocked; Sec.ToggleHidden = secLock.ToggleHidden
    return Sec
end
local function makeMultiSection(parentFrame,sopts,parentSg,layoutOrder,colW,uiScale,attachTip)
    sopts = sopts or {}
    local ac = ST.uniformAccent and ACCENTS[1] or nxAc()
    local INNER = colW - 16
    local pages = sopts.Pages or {"Page 1","Page 2"}
    if #pages > 9 then -- максимум 9 страниц
        warn("[JustLib] MultiSection supports up to 9 pages; extra pages were ignored")
        local cut = {}; for i = 1,9 do cut[i] = pages[i] end; pages = cut
    end
    local iconW = sopts.Icon and 22 or 0
    local titleH = sopts.Title and 20 or 0
    -- Layout: "Auto" (до 3 страниц - одна полоса, больше - строки), "Segmented", "Scroll" (лента) или "Rows" (строки по Columns штук)
    local mode = tostring(sopts.Layout or "Auto")
    if mode == "Auto" then mode = (#pages <= 3) and "Segmented" or "Rows" end
    if mode ~= "Scroll" and mode ~= "Rows" then mode = "Segmented" end
    local cols = math.clamp(math.floor(tonumber(sopts.Columns) or 3), 2, 5)
    local swH = 28
    if mode == "Rows" then local rowsN = math.ceil(#pages / cols); swH = rowsN * 26 + (rowsN - 1) * 4 + 4 end
    local HH = 12 + swH + titleH
    local function unscale(px)
        local s = (uiScale and uiScale.Scale) or 1
        if not s or s <= 0 then s = 1 end
        return px / s
    end
    local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,HH); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
    panel:SetAttribute("JLSearchSection", tostring(sopts.Title or "MultiSection"))
    panel.LayoutOrder = layoutOrder or 1; panel.ClipsDescendants = true; panel.Parent = parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    BG.register("Section", panel, 10)
    local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,HH); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(10,hdr)
    local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0.5,0); hfix.Position = UDim2.new(0,0,0.5,0); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
    if sopts.Title then newTxt({Parent=hdr,Text=sopts.Title,Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-16,0,16),Pos=UDim2.new(0,8,0,3),Z=3}) end
    if sopts.Icon then local ic = mkIcon(hdr, sopts.Icon, 16, 3); ic.Position = UDim2.new(0,8,0,titleH + 12); ic.Size = UDim2.new(0,16,0,16); if ic:IsA("TextLabel") then ic.TextColor3 = ac else ic.ImageColor3 = ac end end
    if attachTip and sopts.Tooltip then attachTip(hdr, sopts.Tooltip) end
    local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,0,HH); hline.BackgroundColor3 = ac; hline.BackgroundTransparency = 0.55; hline.BorderSizePixel = 0; hline.Parent = panel
    local activePage = pages[1]
    local contents = {}; local storedH = {}
    local sharedH = 0 -- высота блока общих элементов (Shared = true): он всегда сверху, на любой странице
    local function contentY() return HH + 1 + sharedH + ((sharedH > 0) and 1 or 0) end
    local function repaint()
        panel.Size = UDim2.new(1,0,0, contentY() + (storedH[activePage] or 0))
        for nm,c in pairs(contents) do c.Visible = (nm == activePage); c.Position = UDim2.new(0,0,0,contentY()) end
    end
    local switcher = mkPageTabs(hdr, UDim2.new(0,8 + iconW,0,6 + titleH), UDim2.new(1,-16 - iconW,0,swH), pages, activePage, ac, function(v)
        activePage = v; repaint()
    end, mode, cols, unscale)
    local sharedHost = Instance.new("Frame"); sharedHost.Size = UDim2.new(1,0,0,0); sharedHost.Position = UDim2.new(0,0,0,HH + 1)
    sharedHost:SetAttribute("JLSearchPage", "Shared")
    sharedHost.BackgroundTransparency = 1; sharedHost.BorderSizePixel = 0; sharedHost.ClipsDescendants = true; sharedHost.Parent = panel
    local sharedList = Instance.new("UIListLayout"); sharedList.Padding = UDim.new(0,6); sharedList.SortOrder = Enum.SortOrder.LayoutOrder; sharedList.Parent = sharedHost
    pad(8,8,8,8,sharedHost)
    local sharedLine = Instance.new("Frame"); sharedLine.Size = UDim2.new(1,-16,0,1); sharedLine.BackgroundColor3 = C.divLine; sharedLine.BorderSizePixel = 0
    sharedLine.Visible = false; sharedLine.Parent = panel
    sharedList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local ch = sharedList.AbsoluteContentSize.Y
        sharedH = (ch > 0) and (unscale(ch) + 16) or 0
        sharedHost.Size = UDim2.new(1,0,0,sharedH)
        sharedLine.Visible = sharedH > 0; sharedLine.Position = UDim2.new(0,8,0,HH + 1 + sharedH)
        repaint()
    end)
    local sharedSec = attachWidgets(sharedHost, INNER, ac, uiScale, parentSg, attachTip)
    -- любой элемент страницы с Shared = true (или Pinned = true) создаётся в общем блоке сверху
    local function redirect(sec)
        for k,fn in pairs(sec) do
            if type(fn) == "function" and type(k) == "string" and k:match("^%u") and type(sharedSec[k]) == "function" then
                sec[k] = function(self, o, ...)
                    if type(o) == "table" and (o.Shared or o.Pinned) then return sharedSec[k](sharedSec, o, ...) end
                    return fn(self, o, ...)
                end
            end
        end
    end
    local pageSecs = {}
    for _,name in ipairs(pages) do
        local content = Instance.new("Frame"); content.Size = UDim2.new(1,0,0,0); content.Position = UDim2.new(0,0,0,contentY())
        content:SetAttribute("JLSearchPage", tostring(name))
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
        redirect(pageSecs[name])
    end
    local MS = {Panel = panel}
    function MS:Page(name) return pageSecs[name] end
    function MS:Shared() return sharedSec end -- общий блок напрямую: MS:Shared():Toggle({...})
    function MS:SetPage(name) if contents[name] and name ~= activePage then activePage = name; switcher.Set(name, true); repaint() end end
    function MS:GetPage() return activePage end
    for pageName,pageFrame in pairs(contents) do
        JL._searchPageTargets[pageFrame] = function()
            if activePage == pageName then return false end
            MS:SetPage(pageName)
            return true
        end
    end
    local msLock = attachLockHidden(panel, sopts)
    MS.SetLocked = msLock.SetLocked; MS.SetHidden = msLock.SetHidden
    MS.IsLocked = msLock.IsLocked; MS.IsHidden = msLock.IsHidden
    MS.ToggleLocked = msLock.ToggleLocked; MS.ToggleHidden = msLock.ToggleHidden
    return MS
end
-- ===== Preview UI loader =====
JL.PreviewSource = "https://raw.githubusercontent.com/JustUser-ALT/JustLib/main/PreviewUI.lua"
-- Если файл не нашёлся или сломан, показываем, ЧТО именно пришло (строка с ошибкой, размер, начало файла)
local function previewDiag(body, err)
    local info = ""
    local ln = tonumber(tostring(err):match(":(%d+):"))
    if ln then
        local i = 0
        for line in (body .. "\n"):gmatch("([^\n]*)\n") do
            i = i + 1
            if i == ln then info = " | line " .. ln .. ": " .. line:sub(1, 70); break end
        end
    end
    return tostring(err) .. info .. " | " .. #body .. " bytes, starts with: " .. body:sub(1, 40):gsub("%s+", " ")
end
local function loadPreviewModule(src)
    if type(src) == "table" then return src end
    if type(src) == "function" then local ok,m = pcall(src); if ok then return m end return nil, tostring(m) end
    local body, how
    if type(src) == "string" then
        if src:match("^https?://") then
            how = "url"
            local ok,r = pcall(function() return game:HttpGet(src) end)
            if ok then body = r else return nil, "download failed (" .. tostring(r) .. "). Check JL.PreviewSource: " .. src end
        elseif readfile then
            how = "file"
            local ok,r = pcall(readfile, src); if ok then body = r else return nil, "file not found: " .. src end
        end
    end
    if not body or body == "" then return nil, "empty source: " .. tostring(src) end
    body = body:gsub("^\239\187\191", "")
    local head = body:sub(1, 200):lower()
    if body:sub(1, 1) == "<" or head:match("^404") or head:match("not found") then
        return nil, "the server returned a web page / 404 instead of PreviewUI.lua. Check JL.PreviewSource: " .. tostring(src)
    end
    local fn,err = loadstring(body)
    if not fn then return nil, previewDiag(body, err) end
    local ok,mod = pcall(fn)
    if not ok or type(mod) ~= "table" then return nil, tostring(mod) end
    return mod
end
-- Заглушка: если Preview не загрузился, остальной скрипт продолжает работать (вызовы просто ничего не делают)
local function previewStub()
    local function ghost()
        local t = {}
        setmetatable(t, {__index = function() return ghost() end, __call = function() return ghost() end})
        return t
    end
    local stub = ghost()
    rawset(stub, "IsStub", true); rawset(stub, "alive", false)
    return stub
end
function JL:Preview(popts)
    popts = popts or {}
    if JL._preview and JL._preview.alive then return JL._preview end
    local mod,err = loadPreviewModule(popts.Source or JL.PreviewSource)
    if not mod or not mod.new then
        warn("[JustLib] Could not load PreviewUI: " .. tostring(err))
        JL:Notify({Title = "Preview UI", Desc = "Could not load PreviewUI: " .. tostring(err), Type = "Error", Duration = 9})
        return previewStub()
    end
    local ok,obj = pcall(mod.new, JL._bridge, popts)
    if not ok then
        warn("[JustLib] PreviewUI init failed: " .. tostring(obj))
        JL:Notify({Title = "Preview UI", Desc = "Init failed: " .. tostring(obj), Type = "Error", Duration = 9})
        return previewStub()
    end
    JL._preview = obj
    return obj
end
function JL:GetPreview() return JL._preview end
local function removeOrphanedHubGuis()
    local names = {JustLib = true, JLRemote = true}
    local containers = {}
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then containers[#containers + 1] = core end
    if PG then containers[#containers + 1] = PG end
    for _, container in ipairs(containers) do
        pcall(function()
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("ScreenGui") and names[child.Name] then
                    child:Destroy()
                end
            end
        end)
    end
end
function JL:Window(opts)
    opts = opts or {}
    _disposed = false
    JL._perfEnabled = opts.DebugPerformance == true
    local hubStartTick = tick()
    local windowBuildStarted = os.clock()
    local iconLoadStarted = os.clock()
    if not JL._iconPack and opts.LoadIcons ~= false then
        trackedSpawn(function()
            local ok = self:LoadIconPack(opts.IconPackURL)
            if JL._perfEnabled then
                warn("[JustLib Perf] Molto icon pack: " .. string.format("%.3f s", os.clock() - iconLoadStarted) .. " (loaded=" .. tostring(ok) .. ")")
            end
        end)
    end
    if shared._JLActive and shared._JLActive.alive then
        local active = shared._JLActive
        local restart = restartPrompt()
        if not restart then return nil end
        if type(active.destroy) == "function" then
            local ok, err = pcall(active.destroy)
            if not ok then warn("[JustLib] Previous hub cleanup failed: " .. tostring(err)) end
        end
    end
    -- Remove leftover UI roots if an older build stopped partway through cleanup.
    -- This also prevents orphaned Remote panels from stacking after Restart Hub.
    removeOrphanedHubGuis()
    if opts.Config then cfgLoad(opts.Config) end
    JL._activeCfgSet = cfgSet
    do -- активный стиль: сохранённый выбор > opts.Style > Old
        local want = tostring(cfgGet("_style", opts.Style or JL._userStyle or "Old"))
        if not JL._styles[want] and opts.StyleBase then
            JL:LoadStyle(want, (tostring(opts.StyleBase):gsub("/+$", "")) .. "/" .. want .. ".lua")
        end
        if not useStyle(want) then
            if want ~= "Old" then warn("[JustLib] Style '" .. want .. "' not found, using Old") end
            useStyle("Old")
        end
    end
    if type(opts.Backgrounds) == "table" then for k,v in pairs(opts.Backgrounds) do JL._bgs[k] = v end end
    if opts.Background ~= nil then JL._bgs.Window = opts.Background end
    do
        local savedTheme = tostring(cfgGet("_theme", (JL._userTheme ~= "Midnight" and JL._userTheme) or ST.defaultTheme or "Midnight"))
        local th = JL._themes[savedTheme]
        if th then
            for k,v in pairs(th) do if k ~= "accents" then C[k] = v end end
            if th.accents then for i,v in ipairs(th.accents) do ACCENTS[i] = v end end
            JL._currentTheme = savedTheme; JL._userTheme = savedTheme
        end
    end
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
            if not tostring(flag):match("^_") and not tostring(flag):match("^addon%.") and not JL._noSave[flag] then out[flag] = val end
        end
        for flag,val in pairs(_memData) do
            if not tostring(flag):match("^_") and not tostring(flag):match("^addon%.") and not JL._noSave[flag] then out[flag] = val end
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
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280,720)
    local labelsOn = cfgGet("_sidebar_labels", opts.SidebarLabels == true)
    if ST.forceLabels then labelsOn = true end
    local SBW, GAP, PADIN, COLGAP = (ST.sbw or (labelsOn and 64 or 42)), (ST.gap or 10), 8, (ST.colGap or 8)
    local OX, OY, OB = (ST.padX or 0), (ST.topH or 0), (ST.padB or 0) -- отступ по бокам, высота верхней панели, отступ снизу
    local TOPPAD = ST.contentTop or 36                                  -- место под кнопку поиска сверху вкладки
    local CWW = math.clamp(opts.Width or 640, 340, math.max(340, vp.X - SBW - GAP - 30 - 2 * OX))
    local WH  = math.clamp(opts.Height or 420, 240, math.max(240, vp.Y - 30 - OY - OB))
    local WW  = OX + SBW + GAP + CWW + OX
    local WINH = WH + OY + OB
    local IW  = CWW - 2 * PADIN
    local VIS = math.clamp(opts.Columns or 3, 1, 6)
    local usable = IW - 8
    while VIS > 1 and (usable - (VIS - 1) * COLGAP) / VIS < 150 do VIS = VIS - 1 end
    local colW = math.floor((usable - (VIS - 1) * COLGAP) / VIS)
    local listW = usable
    local animOn    = cfgGet("_anim", true)
    local userScale = (tonumber(cfgGet("_uiscale", 100)) or 100) / 100
    local blurPct   = tonumber(cfgGet("_blur", 0)) or 0
    local backdropV = tonumber(cfgGet("_backdrop", 65)) or 65
    local hotkey    = keyFromName(cfgGet("_hotkey", opts.Hotkey and opts.Hotkey.Name or "RightShift"))
    local showFps   = cfgGet("_showfps", true)
    local function measureTextW(text,size,font,maxW)
        local ok,b = pcall(function() return TextService:GetTextSize(tostring(text), size, font, Vector2.new(maxW, 30)) end)
        return ok and b.X or (#tostring(text) * (size * 0.6))
    end
    local badgeTitle = opts.Title or "JustLib"
    local badgeOffX = opts.Icon and 32 or 10
    local badgeTitleW = math.clamp(math.ceil(measureTextW(badgeTitle, 12, GB, 260)) + 10, 30, 220)
    local badgeFpsW = 46
    local badgeW = badgeOffX + badgeTitleW + 10 + 1 + 10 + badgeFpsW + 12
    local BPOS = {
        top    = UDim2.new(0.5,-badgeW / 2,0,14),
        center = UDim2.new(0.5,-badgeW / 2,0.5,-15),
        bottom = UDim2.new(0.5,-badgeW / 2,1,-44),
    }
    local badge2 = Instance.new("Frame"); badge2.Size = UDim2.new(0,badgeW,0,30); badge2.Position = BPOS[tostring(cfgGet("_badgepos","Top")):lower()] or BPOS.top
    badge2.BackgroundColor3 = C.badge; badge2.BorderSizePixel = 0; badge2.ZIndex = 60; badge2.Parent = sg; corner(8,badge2); stroke(C.border,1,badge2)
    BG.register("Badge", badge2, 8)
    JL._activeBadge = badge2
    if opts.Icon then local ic = mkIcon(badge2,opts.Icon,18,61); ic.Position = UDim2.new(0,8,0.5,-9) end
    local badgeTitleL = newTxt({Parent=badge2,Text=badgeTitle,Font=GB,Size=12,Sz=UDim2.new(0,badgeTitleW,1,0),Pos=UDim2.new(0,badgeOffX,0,0),Z=61})
    badgeTitleL.TextTruncate = Enum.TextTruncate.None
    local divF = Instance.new("Frame"); divF.Size = UDim2.new(0,1,0,16); divF.Position = UDim2.new(0,badgeOffX + badgeTitleW + 10,0.5,-8); divF.BackgroundColor3 = C.border; divF.BorderSizePixel = 0; divF.ZIndex = 61; divF.Parent = badge2
    local fpsL = newTxt({Parent=badge2,Text="60 FPS",Font=GB,Size=12,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,badgeFpsW,1,0),Pos=UDim2.new(0,badgeOffX + badgeTitleW + 20,0,0),Z=61})
    fpsL.Visible = showFps
    -- подгоняем ширину бейджа под реальный размер текста (TextService в некоторых клиентах занижает ширину)
    do
        local t0 = os.clock()
        local function fitBadge()
            local need = math.ceil(badgeTitleL.TextBounds.X) + 10
            if need <= badgeTitleW or need > 320 then return end
            badgeTitleW = need
            badgeW = badgeOffX + badgeTitleW + 10 + 1 + 10 + badgeFpsW + 12
            BPOS.top = UDim2.new(0.5,-badgeW / 2,0,14); BPOS.center = UDim2.new(0.5,-badgeW / 2,0.5,-15); BPOS.bottom = UDim2.new(0.5,-badgeW / 2,1,-44)
            badge2.Size = UDim2.new(0,badgeW,0,30)
            badgeTitleL.Size = UDim2.new(0,badgeTitleW,1,0)
            divF.Position = UDim2.new(0,badgeOffX + badgeTitleW + 10,0.5,-8)
            fpsL.Position = UDim2.new(0,badgeOffX + badgeTitleW + 20,0,0)
            if os.clock() - t0 < 2 then badge2.Position = BPOS[tostring(cfgGet("_badgepos","Top")):lower()] or BPOS.top end
        end
        fitBadge()
        badgeTitleL:GetPropertyChangedSignal("TextBounds"):Connect(fitBadge)
    end
    local homeFpsLabel
    local fpsConn
    do
        local _lt = tick(); local _fr = 0
        fpsConn = keep(RunSvc.Heartbeat:Connect(function()
            _fr = _fr + 1; local n = tick()
            if n - _lt >= 0.5 then
                local fps = math.round(_fr / (n - _lt)); fpsL.Text = fps .. " FPS"
                fpsL.TextColor3 = fps >= 50 and C.fpsGrn or (fps >= 30 and Color3.fromRGB(255,200,72) or Color3.fromRGB(255,82,82))
                if homeFpsLabel then homeFpsLabel.Text = tostring(fps) end
                _fr = 0; _lt = n
            end
        end))
    end
    local badgeTap = Instance.new("TextButton"); badgeTap.Size = UDim2.new(1,0,1,0); badgeTap.BackgroundTransparency = 1; badgeTap.Text = ""; badgeTap.ZIndex = 62; badgeTap.Parent = badge2
    local win = Instance.new("Frame"); win.Size = UDim2.new(0,WW,0,WINH); win.AnchorPoint = Vector2.new(0.5,0.5); win.Position = UDim2.new(0.5,0,0.5,0)
    win.BackgroundTransparency = 1; win.BorderSizePixel = 0; win.Visible = false; win.ClipsDescendants = false; win.Parent = sg
    JL._activeWin = win
    local winBg = Instance.new("Frame"); winBg.Name = "JLWindowBg"; winBg.Size = UDim2.new(1,0,1,0); winBg.BackgroundTransparency = 1; winBg.BorderSizePixel = 0; winBg.ZIndex = 0; winBg.Parent = win
    BG.register("Window", winBg, 12)
    if ST.windowCard then
        local okWC,errWC = pcall(ST.windowCard, {win = win, WW = WW, WINH = WINH, OX = OX, OY = OY}, UI())
        if not okWC then warn("[JustLib] Style windowCard failed: " .. tostring(errWC)) end
    end
    local uiScale = Instance.new("UIScale"); uiScale.Scale = userScale; uiScale.Parent = win
    local function unscaleWin(px)
        local s = uiScale.Scale; if not s or s <= 0 then s = 1 end
        return px / s
    end
    local backdrop = Instance.new("Frame"); backdrop.Size = UDim2.new(0,CWW,0,WH); backdrop.Position = UDim2.new(0,OX + SBW + GAP,0,OY)
    backdrop.BackgroundColor3 = C.backdrop; backdrop.BackgroundTransparency = (opts.Backdrop == false) and 1 or (1 - backdropV / 100); backdrop.BorderSizePixel = 0; backdrop.Parent = win
    corner(ST.cardCorner or 12,backdrop); local bdStroke = stroke(C.border,1,backdrop); bdStroke.Transparency = 0.35
    local SBMODE = (opts.SidebarOverflow == "Columns") and "Columns" or "Scroll"
    local SBMAX = math.max(1, math.floor(tonumber(opts.MaxTabsPerColumn) or 5))
    local COLSP = 6
    local sbCols = {}
    local sbBtns = {}
    local sbQueued = false
    local function sbPos(x,h)
        if ST.sbFull then return UDim2.new(0,OX + x,0,OY) end
        return UDim2.new(0,x,0.5,-h / 2)
    end
    local function placeCol(col,x,animate)
        local h = col.frame.Size.Y.Offset
        local target = sbPos(x,h)
        col.x = x
        if animate then tw(col.frame,{Position = target},.28,Enum.EasingStyle.Quart,Enum.EasingDirection.Out) else col.frame.Position = target end
    end
    local function newSbColumn()
        local isFirst = (#sbCols == 0)
        local f = Instance.new("Frame"); f.Size = UDim2.new(0,SBW,0,0); f.Position = UDim2.new(0,0,0.5,0); f.BackgroundColor3 = C.sidebar; f.BorderSizePixel = 0; f.Parent = win
        f.BackgroundTransparency = ST.sbTransp or 0
        corner(ST.sbCorner or 12,f); local sbStroke = stroke(C.border,1,f); sbStroke.Transparency = ST.sbStrokeT or 0
        BG.register("Sidebar", f, 12)
        local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,0,1,-((isFirst and ST.sbFooterH) or 0)); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0; sc.ScrollBarThickness = 0
        sc.ScrollingDirection = Enum.ScrollingDirection.Y; sc.CanvasSize = UDim2.new(0,0,0,0); sc.ClipsDescendants = true; sc.Parent = f
        local ls = Instance.new("UIListLayout"); ls.FillDirection = Enum.FillDirection.Vertical; ls.HorizontalAlignment = Enum.HorizontalAlignment.Center
        ls.VerticalAlignment = Enum.VerticalAlignment.Top; ls.Padding = UDim.new(0,ST.sbGap or 8); ls.SortOrder = Enum.SortOrder.LayoutOrder; ls.Parent = sc; pad(0,0,10,10,sc)
        local col = {frame = f, scroll = sc, list = ls, x = nil}
        if isFirst and ST.sbFooter then
            local okSF,errSF = pcall(ST.sbFooter, f, {Title = badgeTitle, Icon = opts.Icon, Version = opts.Version or JL.Version, Footer = opts.Footer, Tagline = opts.Tagline, SBW = SBW}, UI())
            if not okSF then warn("[JustLib] Style sbFooter failed: " .. tostring(errSF)) end
        end
        local function stepScroll(dir)
            local vh = unscaleWin(sc.AbsoluteWindowSize.Y)
            local maxY = math.max(0, unscaleWin(sc.AbsoluteCanvasSize.Y) - vh)
            local step = (labelsOn and 54 or 38) * 2
            local target = math.clamp(sc.CanvasPosition.Y + dir * step, 0, maxY)
            tw(sc,{CanvasPosition = Vector2.new(0,target)},.22)
        end
        local function mkArrow(up)
            local a = Instance.new("Frame"); a.Size = UDim2.new(1,-2,0,24); a.Position = up and UDim2.new(0,1,0,1) or UDim2.new(0,1,1,-25)
            a.BackgroundColor3 = C.sidebar; a.BorderSizePixel = 0; a.ZIndex = 20; a.Visible = false; a.Parent = f
            local g = Instance.new("UIGradient"); g.Rotation = 90
            g.Transparency = NumberSequence.new(up and {NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.6,0.15),NumberSequenceKeypoint.new(1,1)} or {NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.4,0.15),NumberSequenceKeypoint.new(1,0)})
            g.Parent = a; corner(11, a) -- те же скругления, что у рамки сайдбара
            local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,16); b.Position = up and UDim2.new(0,0,0,0) or UDim2.new(0,0,1,-16)
            b.BackgroundTransparency = 1; b.Text = ""; b.AutoButtonColor = false; b.ZIndex = 21; b.Parent = a
            local gi
            if JL._iconPack then
                gi = mkIcon(b, up and "chevron-up" or "chevron-down", 12, 22)
                if gi:IsA("TextLabel") then gi:Destroy(); gi = nil end
            end
            if gi then
                gi.ImageColor3 = C.dim; gi.AnchorPoint = Vector2.new(0.5,0.5); gi.Position = UDim2.new(0.5,0,0.5,0)
            else
                newTxt({Parent=b,Text = up and "^" or "v",Font=GB,Size=12,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=22})
            end
            b.MouseButton1Click:Connect(function() stepScroll(up and -1 or 1) end)
            return a
        end
        col.up = mkArrow(true); col.down = mkArrow(false)
        local function updArrows()
            -- стрелка показывается только если за краем есть вкладки (отступ 10px сверху и снизу не считается)
            local vh = unscaleWin(sc.AbsoluteWindowSize.Y); local y = sc.CanvasPosition.Y
            local bottom = unscaleWin(ls.AbsoluteContentSize.Y) + 10
            col.up.Visible = y > 10
            col.down.Visible = y + vh < bottom - 2
        end
        local function fit()
            local ch = unscaleWin(ls.AbsoluteContentSize.Y) + 20
            local h = ST.sbFull and WH or math.min(ch, WH)
            sc.CanvasSize = UDim2.new(0,0,0,ch)
            f.Size = UDim2.new(0,SBW,0,h)
            f.Position = sbPos(col.x or 0, h)
            updArrows()
        end
        ls:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
        sc:GetPropertyChangedSignal("CanvasPosition"):Connect(updArrows)
        sc:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updArrows)
        sc:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(updArrows)
        return col
    end
    local function relayoutSidebar()
        local vis = {}
        for id,b in pairs(sbBtns) do if b.Visible then vis[#vis + 1] = id end end
        table.sort(vis)
        local n = #vis
        local cap, ncol = math.huge, 1
        if SBMODE == "Columns" and n > 0 then
            local camV = workspace.CurrentCamera
            local vw = camV and camV.ViewportSize.X or 1280
            local leftRoom = (vw / math.max(userScale, 0.1) - WW) / 2 - 6
            local maxCols = math.max(1, 1 + math.floor(leftRoom / (SBW + COLSP)))
            cap = math.max(SBMAX, math.ceil(n / maxCols))
            ncol = math.max(1, math.ceil(n / cap))
        end
        while #sbCols < ncol do sbCols[#sbCols + 1] = newSbColumn() end
        for i,col in ipairs(sbCols) do
            col.frame.Visible = i <= ncol
            local x = -(ncol - i) * (SBW + COLSP)
            if col.x == nil then placeCol(col, x, false) elseif col.x ~= x then placeCol(col, x, true) end
        end
        for k,id in ipairs(vis) do
            local ci = (cap == math.huge) and 1 or math.ceil(k / cap)
            sbBtns[id].Parent = sbCols[ci].scroll
        end
    end
    local function queueSidebar()
        if sbQueued then return end
        sbQueued = true
        trackedDefer(function()
            sbQueued = false
            if not _dead then relayoutSidebar() end
        end)
    end
    local function revealTab(id)
        local b = sbBtns[id]; if not b then return end
        local sc = b.Parent; if not (sc and sc:IsA("ScrollingFrame")) then return end
        local rel = unscaleWin(b.AbsolutePosition.Y - sc.AbsolutePosition.Y)
        local bh = unscaleWin(b.AbsoluteSize.Y); local vh = unscaleWin(sc.AbsoluteWindowSize.Y)
        local y = sc.CanvasPosition.Y; local target = y
        if rel < 24 then target = y + rel - 24 elseif rel + bh > vh - 24 then target = y + rel + bh - vh + 24 end
        local maxY = math.max(0, unscaleWin(sc.AbsoluteCanvasSize.Y) - vh)
        target = math.clamp(target, 0, maxY)
        if math.abs(target - y) > 0.5 then tw(sc,{CanvasPosition = Vector2.new(0,target)},.2) end
    end
    relayoutSidebar()
    local content = Instance.new("Frame"); content.Size = UDim2.new(0,CWW,0,WH); content.Position = UDim2.new(0,OX + SBW + GAP,0,OY)
    content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = win
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
        else x = rel.X + osz.X + 8; y = rel.Y + osz.Y / 2 - h / 2 end
        tip.Size = UDim2.new(0,w,0,h); tip.Position = UDim2.new(0, x, 0, y); tipL.Text = text; tip.Visible = true
    end
    local function hideTip() tip.Visible = false end
    local function attachTip(guiObject,text)
        if not text or text == "" then return end
        guiObject.MouseEnter:Connect(function() showTip(guiObject, text) end)
        guiObject.MouseLeave:Connect(hideTip)
    end
    local TABPOS = UDim2.new(0,PADIN,0,PADIN + TOPPAD)
    local function offPos(dir) return UDim2.new(dir,PADIN,0,PADIN) end
    local tabFrames = {}; local tabUI = {}; local tabScrollers = {}; local activeTabId = nil; local _tabCount = 0
    local function styleTab(id,active)
        local u = tabUI[id]; if not u then return end
        local activeBg = (ST.tabActiveBgFn and ST.tabActiveBgFn(C,ACCENTS)) or ST.tabActiveBg or Color3.fromRGB(24,44,74)
        tw(u.btn,{BackgroundColor3 = active and activeBg or (ST.tabIdleBg or Color3.fromRGB(34,34,40)), BackgroundTransparency = active and (ST.tabActiveT or 0) or (ST.tabIdleT or 0)},.15)
        local col = active and (ST.tabActiveTextIsTxt and C.txt or ACCENTS[1]) or C.dim
        if u.icon:IsA("TextLabel") then u.icon.TextColor3 = col else u.icon.ImageColor3 = col end
        if u.label then u.label.TextColor3 = col end
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
                trackedDelay(.23, function() if activeTabId ~= tid then fr.Visible = false end end)
            else
                fr.Visible = false
            end
        end
        for tid in pairs(tabUI) do styleTab(tid, tid == id) end
        activeTabId = id
        revealTab(id)
    end
    JL._themeHooks = JL._themeHooks or {}
    table.insert(JL._themeHooks, function() for tid in pairs(tabUI) do styleTab(tid, tid == activeTabId) end end)
    local blurObj
    local function applyBlur()
        if blurPct > 0 and JL._winOpen then
            if not blurObj or not blurObj.Parent then blurObj = Instance.new("BlurEffect"); blurObj.Name = "JLBlur"; blurObj.Parent = game:GetService("Lighting") end
            blurObj.Size = math.round(blurPct * 56 / 100); blurObj.Enabled = true
        elseif blurObj then blurObj.Enabled = false end
    end
    local isOpen = false
    local function openW()
        if _dead then return end
        isOpen = true; JL._winOpen = true; win.Visible = true
        if animOn then uiScale.Scale = userScale * 0.88; tw(uiScale,{Scale = userScale},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out) else uiScale.Scale = userScale end
        tw(badge2,{BackgroundColor3 = C.badgeHi},.15); applyBlur()
    end
    local function closeW()
        if _dead then return end
        isOpen = false; JL._winOpen = false
        if animOn then
            tw(uiScale,{Scale = userScale * 0.88},.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In)
            trackedDelay(.19, function() if not isOpen then win.Visible = false end end)
        else win.Visible = false end
        tw(badge2,{BackgroundColor3 = C.badge},.15); applyBlur()
    end
    draggable(badgeTap, badge2, function() if isOpen then closeW() else openW() end end)
    keep(UIS.InputBegan:Connect(function(i,gp)
        if gp or JL._listening then return end
        if hotkey and i.KeyCode == hotkey then if isOpen then closeW() else openW() end end
    end))
    keep(UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseWheel or not JL._winOpen or not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then return end
        local t = tabScrollers[activeTabId]; if not t then return end
        local m = UIS:GetMouseLocation(); local ap,as = content.AbsolutePosition, content.AbsoluteSize
        if m.X < ap.X or m.X > ap.X + as.X or m.Y < ap.Y or m.Y > ap.Y + as.Y then return end
        t.go(t.cur() + (i.Position.Z > 0 and -1 or 1))
    end))
    local function destroyHub()
        if _dead then return end
        _dead = true; isOpen = false; JL._winOpen = false
        JL._searchRegister = nil
        if JL._searchEntries then for k in pairs(JL._searchEntries) do JL._searchEntries[k] = nil end end
        if JL._searchPageTargets then for k in pairs(JL._searchPageTargets) do JL._searchPageTargets[k] = nil end end
        _disposed = true
        if shared._JLActive then shared._JLActive.alive = false end
        pcall(function() fpsConn:Disconnect() end)
        for _,c in ipairs(_conns) do pcall(function() c:Disconnect() end) end
        _conns = {}
        -- Cleanup must never abort the final GUI destruction.
        pcall(cleanupResources)
        pcall(function() if blurObj then blurObj:Destroy() end end)
        local hooks = {}
        for k,fn in ipairs(JL._unloadHooks) do hooks[k] = fn end
        for k = #JL._unloadHooks, 1, -1 do JL._unloadHooks[k] = nil end
        for _,fn in ipairs(hooks) do pcall(fn) end
        for k = #JL._themeHooks, 1, -1 do JL._themeHooks[k] = nil end
        for k = #JL._extraRoots, 1, -1 do
            local root = JL._extraRoots[k]
            if root then pcall(cleanupResource, root) end
            JL._extraRoots[k] = nil
        end
        JL._preview = nil
        pcall(function() if sg and sg.Parent then sg:Destroy() end end)
        _cpSg = nil
        if JL._destroyActive == destroyHub then JL._destroyActive = nil end
        if JL._activeWin == win then JL._activeWin = nil end
        if JL._activeBadge == badge2 then JL._activeBadge = nil end
    end
    if ST.topBar then
        local okTB,errTB = pcall(ST.topBar, {
            win = win, sg = sg, WW = WW, OX = OX, OY = OY, Title = badgeTitle, Icon = opts.Icon,
            Tagline = opts.Tagline, Version = opts.Version or JL.Version,
            Open = openW, Close = closeW,
            Unload = function() trackedSpawn(function() if unloadDialog() then destroyHub() end end) end,
        }, UI())
        if not okTB then warn("[JustLib] Style topBar failed: " .. tostring(errTB)) end
    end
    local Win = {}
    function Win:Open() if not isOpen then openW() end end
    function Win:Close() if isOpen then closeW() end end
    function Win:Toggle() if isOpen then closeW() else openW() end end
    function Win:Destroy() destroyHub() end
    function Win:Unload() destroyHub() end
    function Win:IsOpen() return isOpen end
    function Win:Track(resource, cleanup) return JL:Track(resource, cleanup) end
    function Win:Connect(signal, callback) return JL:Connect(signal, callback) end
    function Win:Spawn(callback, ...) return JL:Spawn(callback, ...) end
    function Win:Delay(seconds, callback, ...) return JL:Delay(seconds, callback, ...) end
    function Win:Defer(callback, ...) return JL:Defer(callback, ...) end
    function Win:OnUnload(callback) return JL:OnUnload(callback) end
    function Win:IsAlive() return JL:IsAlive() end
    JL._win = Win
    JL._bridge.getWin = function() if _dead then return nil end return Win end
    JL._bridge.getScale = function() return uiScale.Scale end
    JL._bridge.getContentSize = function() return CWW - 2 * PADIN, WH - 2 * PADIN end
    function Win:Notify(c) return JL:Notify(c) end
    function Win:SetBackground(kind,cfg) JL:SetBackground(kind,cfg) end
    function Win:ClearBackground(kind) JL:SetBackground(kind,nil) end
    GUIDE.nav = function(row)
        if not (row and row.Parent) then return end
        if not isOpen then openW(); task.wait(.3) end
        local tabId, p = nil, row
        while p and p ~= win do
            for tid,fr in pairs(tabFrames) do if fr == p then tabId = tid end end
            if tabId then break end
            p = p.Parent
        end
        if tabId and tabId ~= activeTabId then switchToTab(tabId); task.wait(.35) end
        local q, expanded = row.Parent, false
        while q and q ~= win do
            local pageSelect = JL._searchPageTargets[q]
            if pageSelect and pageSelect() then expanded = true end
            local sec = JL._secPanels[q]
            if sec and sec:IsCollapsed() then sec:SetCollapsed(false); expanded = true end
            q = q.Parent
        end
        if expanded then task.wait(.35) end
        local sc, panel
        q = row.Parent
        while q and q ~= win do
            if not panel and JL._secPanels[q] then panel = q end
            if q:IsA("ScrollingFrame") then sc = q; break end
            q = q.Parent
        end
        if not sc then return end
        local scale = math.max(uiScale.Scale, 0.01)
        local rowTop = (row.AbsolutePosition.Y - sc.AbsolutePosition.Y) / scale
        local rowH = row.AbsoluteSize.Y / scale
        local viewH = sc.AbsoluteWindowSize.Y / scale
        local maxY = math.max(0, sc.AbsoluteCanvasSize.Y / scale - viewH)
        local ty = math.clamp(sc.CanvasPosition.Y + rowTop - (viewH - rowH) / 2, 0, maxY)
        local tx = sc.CanvasPosition.X
        if panel and sc.ScrollingDirection ~= Enum.ScrollingDirection.Y then
            local viewW = sc.AbsoluteWindowSize.X / scale
            local maxX = math.max(0, sc.AbsoluteCanvasSize.X / scale - viewW)
            tx = math.clamp(sc.CanvasPosition.X + (panel.AbsolutePosition.X - sc.AbsolutePosition.X) / scale, 0, maxX)
        end
        tw(sc,{CanvasPosition = Vector2.new(tx,ty)},.45)
        task.wait(.5)
    end
    local searchEntries = {}
    JL._searchEntries = searchEntries
    local searchButton = Instance.new("TextButton")
    searchButton.Name = "JLGlobalSearchButton"
    searchButton.Size = UDim2.new(0,36,0,30)
    searchButton.Position = ST.searchPos and ST.searchPos({WW = WW, OX = OX, OY = OY, PADIN = PADIN}) or UDim2.new(1,-(PADIN + 36),0,PADIN + 3)
    searchButton.BackgroundColor3 = C.panel
    searchButton.BorderSizePixel = 0
    searchButton.AutoButtonColor = false
    searchButton.Text = ""
    searchButton.Parent = win
    searchButton.ZIndex = 80
    corner(9,searchButton); stroke(C.border,1,searchButton)
    local searchButtonIcon = mkIcon(searchButton,"search",16,81)
    searchButtonIcon.AnchorPoint = Vector2.new(.5,.5)
    searchButtonIcon.Position = UDim2.new(.5,0,.5,0)
    searchButtonIcon.Size = UDim2.new(0,16,0,16)
    if searchButtonIcon:IsA("TextLabel") then searchButtonIcon.TextColor3 = C.txt end
    local searchWidth = math.max(180,CWW - 2 * PADIN)
    local searchPanel = Instance.new("Frame")
    searchPanel.Name = "JLGlobalSearchPanel"
    searchPanel.Size = UDim2.new(0,searchWidth,0,238)
    searchPanel.Position = UDim2.new(0,OX + SBW + GAP + PADIN,0,OY + PADIN + TOPPAD - 1)
    searchPanel.BackgroundColor3 = C.panel
    searchPanel.BorderSizePixel = 0
    searchPanel.Visible = false
    searchPanel.ClipsDescendants = true
    searchPanel.Parent = win
    searchPanel.ZIndex = 81
    corner(12,searchPanel); stroke(C.border,1,searchPanel)
    local searchHeader = Instance.new("Frame")
    searchHeader.Size = UDim2.new(1,0,0,42)
    searchHeader.BackgroundColor3 = C.pHdr
    searchHeader.BorderSizePixel = 0
    searchHeader.Parent = searchPanel
    searchHeader.ZIndex = 82
    corner(12,searchHeader)
    local searchHeaderFix = Instance.new("Frame")
    searchHeaderFix.Size = UDim2.new(1,0,0,12)
    searchHeaderFix.Position = UDim2.new(0,0,1,-12)
    searchHeaderFix.BackgroundColor3 = C.pHdr
    searchHeaderFix.BorderSizePixel = 0
    searchHeaderFix.Parent = searchHeader
    searchHeaderFix.ZIndex = 82
    newTxt({Parent=searchHeader,Text="Search",Font=GB,Size=13,Color=C.txt,Sz=UDim2.new(1,-58,1,0),Pos=UDim2.new(0,14,0,0),Z=83})
    local searchClose = Instance.new("TextButton")
    searchClose.Size = UDim2.new(0,26,0,26)
    searchClose.Position = UDim2.new(1,-34,0,8)
    searchClose.BackgroundColor3 = C.btnBg
    searchClose.BorderSizePixel = 0
    searchClose.Text = "×"
    searchClose.Font = GB
    searchClose.TextSize = 16
    searchClose.TextColor3 = C.dim
    searchClose.Parent = searchHeader
    searchClose.ZIndex = 84
    corner(7,searchClose)
    local searchInputFrame = Instance.new("Frame")
    searchInputFrame.Size = UDim2.new(1,-20,0,36)
    searchInputFrame.Position = UDim2.new(0,10,0,50)
    searchInputFrame.BackgroundColor3 = C.input
    searchInputFrame.BorderSizePixel = 0
    searchInputFrame.Parent = searchPanel
    searchInputFrame.ZIndex = 82
    corner(8,searchInputFrame); stroke(C.border,1,searchInputFrame)
    local searchInputIcon = mkIcon(searchInputFrame,"search",15,84)
    searchInputIcon.Position = UDim2.new(0,10,0.5,-7)
    searchInputIcon.Size = UDim2.new(0,15,0,15)
    if searchInputIcon:IsA("TextLabel") then searchInputIcon.TextColor3 = C.dim end
    local searchBox = Instance.new("TextBox")
    searchBox.Name = "JLGlobalSearchInput"
    searchBox.Size = UDim2.new(1,-42,1,0)
    searchBox.Position = UDim2.new(0,34,0,0)
    searchBox.BackgroundTransparency = 1
    searchBox.BorderSizePixel = 0
    searchBox.PlaceholderText = "Find a control..."
    searchBox.PlaceholderColor3 = C.dim
    searchBox.ClearTextOnFocus = false
    searchBox.Font = GB
    searchBox.TextSize = 12
    searchBox.TextColor3 = C.txt
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Text = ""
    searchBox.Parent = searchInputFrame
    searchBox.ZIndex = 84
    newTxt({Parent=searchPanel,Text="Search across tabs, sections and controls",Font=GM,Size=9,Color=C.dim,Sz=UDim2.new(1,-24,0,13),Pos=UDim2.new(0,12,0,91),Z=83})
    local searchResults = Instance.new("ScrollingFrame")
    searchResults.Name = "JLGlobalSearchResults"
    searchResults.Size = UDim2.new(1,-20,1,-116)
    searchResults.Position = UDim2.new(0,10,0,108)
    searchResults.BackgroundTransparency = 1
    searchResults.BorderSizePixel = 0
    searchResults.ScrollBarThickness = 3
    searchResults.ScrollBarImageColor3 = C.border
    searchResults.CanvasSize = UDim2.new(0,0,0,0)
    searchResults.Parent = searchPanel
    searchResults.ZIndex = 82
    local resultLayout = Instance.new("UIListLayout")
    resultLayout.Padding = UDim.new(0,4)
    resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
    resultLayout.Parent = searchResults
    resultLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        searchResults.CanvasSize = UDim2.new(0,0,0,resultLayout.AbsoluteContentSize.Y + 4)
    end)
    local function searchPath(row)
        local tabName, sectionName, pageName
        local p = row
        while p and p ~= win do
            local page = p:GetAttribute("JLSearchPage")
            if page then pageName = page end
            local section = p:GetAttribute("JLSearchSection")
            if section then sectionName = section end
            for id,frame in pairs(tabFrames) do
                if frame == p then
                    local ui = tabUI[id]
                    tabName = ui and ui.name or ("Tab " .. tostring(id))
                    break
                end
            end
            p = p.Parent
        end
        local parts = {}
        if tabName then parts[#parts + 1] = tabName end
        if sectionName then parts[#parts + 1] = sectionName end
        if pageName then parts[#parts + 1] = pageName end
        return table.concat(parts,"  ›  ")
    end
    local function addSearchEntry(entry)
        if not entry or not entry.Row then return end
        entry.Path = searchPath(entry.Row)
        entry.SearchText = (tostring(entry.Name or "") .. " " .. tostring(entry.Kind or "") .. " " .. tostring(entry.ParentName or "") .. " " .. tostring(entry.Path or "")):lower()
        searchEntries[#searchEntries + 1] = entry
        return entry
    end
    JL._searchRegister = addSearchEntry
    local function clearSearchResults()
        for _,child in ipairs(searchResults:GetChildren()) do
            if child ~= resultLayout then child:Destroy() end
        end
    end
    local function refreshSearch()
        clearSearchResults()
        local query = searchBox.Text:lower():gsub("^%s+",""):gsub("%s+$","")
        if query == "" then return end
        local matches = {}
        local indexedRows = {}
        for _,entry in ipairs(searchEntries) do
            local currentRow = entry.Control and entry.Control.Row or entry.Row
            if currentRow then indexedRows[currentRow] = true end
            if currentRow and currentRow.Parent and entry.SearchText:find(query,1,true) then
                entry.Row = currentRow
                matches[#matches + 1] = entry
            end
        end
        local function insideIndexedControl(object,tabFrame)
            local parent = object
            while parent and parent ~= tabFrame do
                if indexedRows[parent] then return true end
                parent = parent.Parent
            end
            return false
        end
        for _,tabFrame in pairs(tabFrames) do
            for _,object in ipairs(tabFrame:GetDescendants()) do
                if (object:IsA("TextButton") or object:IsA("TextBox")) and not insideIndexedControl(object,tabFrame) then
                    local label = object:IsA("TextBox") and object.PlaceholderText or object.Text
                    if not label or label == "" then
                        local childLabel = object:FindFirstChildWhichIsA("TextLabel",true)
                        label = childLabel and childLabel.Text or ""
                    end
                    label = tostring(label or "")
                    if label ~= "" then
                        local kind = object:IsA("TextBox") and "Input" or "Button"
                        local path = searchPath(object)
                        local searchText = (label .. " " .. kind .. " " .. path):lower()
                        if searchText:find(query,1,true) then
                            matches[#matches + 1] = {Name = label, Kind = kind, Path = path, SearchText = searchText, Row = object}
                        end
                    end
                end
            end
        end
        table.sort(matches,function(a,b)
            local an, bn = tostring(a.Name):lower(), tostring(b.Name):lower()
            if an ~= bn then return an < bn end
            return a.Path < b.Path
        end)
        for i = 1,math.min(#matches,60) do
            local entry = matches[i]
            local item = Instance.new("TextButton")
            item.Name = "JLSearchResult"
            item.Size = UDim2.new(1,-2,0,50)
            item.BackgroundColor3 = C.btnBg
            item.BorderSizePixel = 0
            item.AutoButtonColor = false
            item.Text = ""
            item.LayoutOrder = i
            item.Parent = searchResults
            item.ZIndex = 83
            corner(8,item); stroke(C.border,1,item)
            local resultDot = Instance.new("Frame")
            resultDot.Size = UDim2.new(0,3,0,24)
            resultDot.Position = UDim2.new(0,0,0.5,-12)
            resultDot.BackgroundColor3 = ACCENTS[1]
            resultDot.BorderSizePixel = 0
            resultDot.Parent = item
            resultDot.ZIndex = 84
            corner(2,resultDot)
            newTxt({Parent=item,Text=tostring(entry.Name),Font=GB,Size=12,Color=C.txt,Sz=UDim2.new(1,-28,0,17),Pos=UDim2.new(0,12,0,6),Z=84})
            newTxt({Parent=item,Text=(entry.Path ~= "" and entry.Path or "General") .. (entry.ParentName and ("  ›  " .. entry.ParentName) or "") .. "   ·   " .. tostring(entry.Kind),Font=GM,Size=9,Color=C.dim,Sz=UDim2.new(1,-28,0,14),Pos=UDim2.new(0,12,0,27),Z=84})
            item.MouseEnter:Connect(function() if not touchLast() then tw(item,{BackgroundColor3=C.btnHov},.1) end end)
            item.MouseLeave:Connect(function() tw(item,{BackgroundColor3=C.btnBg},.1) end)
            item.MouseButton1Click:Connect(function()
                searchPanel.Visible = false
                searchButton.Visible = true
                entry.Row = entry.Control and entry.Control.Row or entry.Row
                if entry.OpenValue and entry.Control and entry.Control.OpenValue then
                    pcall(entry.Control.OpenValue,entry.Control,entry.OpenValue)
                elseif entry.Control and entry.Control.Open then
                    pcall(entry.Control.Open,entry.Control)
                end
                trackedSpawn(function()
                    task.wait(.28)
                    local navRow = entry.Control and entry.Control.Row or entry.Row
                    if navRow and navRow.Parent then
                        GUIDE.nav(navRow)
                        local pulseRow = entry.TargetResolver and entry.TargetResolver() or entry.TargetRow
                        if entry.NestedIndex then
                            if pulseRow and pulseRow.Parent then GUIDE.pulse(pulseRow,2.6) end
                        else
                            GUIDE.pulse(pulseRow and pulseRow.Parent and pulseRow or navRow,2.6)
                        end
                    end
                end)
            end)
        end
        if #matches == 0 then
            newTxt({Parent=searchResults,Text="No matching controls",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-12,0,24),Pos=UDim2.new(0,6,0,6),Z=84})
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(refreshSearch)
    local function openSearch()
        searchPanel.Visible = true
        searchPanel.Size = UDim2.new(0,searchWidth,0,0)
        tw(searchPanel,{Size = UDim2.new(0,searchWidth,0,238)},.18)
        searchButton.Visible = false
        refreshSearch()
        trackedDefer(function() pcall(function() searchBox:CaptureFocus() end) end)
    end
    local function closeSearch()
        searchButton.Visible = true
        tw(searchPanel,{Size = UDim2.new(0,searchWidth,0,0)},.16)
        trackedDelay(.17,function() if searchPanel and searchPanel.Parent then searchPanel.Visible = false end end)
    end
    searchButton.MouseButton1Click:Connect(openSearch)
    searchClose.MouseButton1Click:Connect(closeSearch)
    function Win:Search(query)
        openSearch()
        if query ~= nil then searchBox.Text = tostring(query) end
        return true
    end
    function Win:GoTo(target)
        local el = type(target) == "string" and JL._registry[target] or target
        local row = (typeof(target) == "Instance") and target or (type(el) == "table" and el.Row)
        if not row then return false end
        trackedSpawn(function() GUIDE.nav(row); GUIDE.pulse(row, 2.4) end)
        return true
    end
    function Win:Tab(topts)
        topts = topts or {}; local typ = topts.Type or "Grid"; _tabCount = _tabCount + 1; local id = _tabCount
        local btn = Instance.new("TextButton"); btn.Size = labelsOn and UDim2.new(0,SBW - (ST.tabInset or 12),0,ST.tabH or 46) or UDim2.new(0,30,0,30); btn.BackgroundColor3 = ST.tabIdleBg or Color3.fromRGB(34,34,40); btn.Text = ""; btn.AutoButtonColor = false
        btn.BorderSizePixel = 0; btn.BackgroundTransparency = ST.tabIdleT or 0; btn.LayoutOrder = id; btn.Parent = sbCols[1].scroll; corner(ST.tabCorner or 8,btn)
        sbBtns[id] = btn; btn:GetPropertyChangedSignal("Visible"):Connect(queueSidebar); queueSidebar()
        local ic = mkIcon(btn, topts.Icon or "◼", 16, 14); ic.Position = labelsOn and (ST.tabRow and UDim2.new(0,14,0.5,-8) or UDim2.new(0.5,-8,0,8)) or UDim2.new(0.5,-8,0.5,-8); ic.Size = UDim2.new(0,16,0,16)
        local tabLabel
        if labelsOn then
            tabLabel = newTxt(ST.tabRow
                and {Parent=btn,Text=topts.Name or "",Font=GM,Size=13,Color=C.dim,XAlign=Enum.TextXAlignment.Left,Sz=UDim2.new(1,-48,1,0),Pos=UDim2.new(0,44,0,0),Z=14}
                or {Parent=btn,Text=topts.Name or "",Font=GB,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-4,0,12),Pos=UDim2.new(0,2,0,28),Z=14})
        end
        if ic:IsA("TextLabel") then ic.TextColor3 = C.dim else ic.ImageColor3 = C.dim end
        local ind = Instance.new("Frame"); ind.Size = UDim2.new(0,3,0,14); ind.Position = ST.tabIndPos or UDim2.new(0,-5,0.5,-7); ind.BackgroundColor3 = ACCENTS[1]; ind.BorderSizePixel = 0; ind.Visible = false; ind.Parent = btn; corner(2,ind)
        tabUI[id] = {btn = btn, icon = ic, ind = ind, label = tabLabel, name = topts.Name or ("Tab " .. tostring(id))}
        attachTip(btn, topts.Tooltip or topts.Name)
        local tabLock = attachLockHidden(btn, {Locked = topts.Locked, Hidden = topts.Hidden, LockedMessage = topts.LockedMessage, LockedTitle = topts.LockedTitle, Requires = topts.Requires, HiddenUntil = topts.HiddenUntil, OpenStore = topts.OpenStore})
        local tabFrame = Instance.new("Frame"); tabFrame.Size = UDim2.new(1,-2 * PADIN,1,-2 * PADIN - TOPPAD); tabFrame.Position = TABPOS
        tabFrame.BackgroundTransparency = 1; tabFrame.Visible = false; tabFrame.Parent = content
        tabFrames[id] = tabFrame
        btn.MouseButton1Click:Connect(function() switchToTab(id) end)
        if not activeTabId and not topts.Hidden then activeTabId = id; tabFrame.Visible = true; styleTab(id,true) end
        local Tab = {Frame = tabFrame, Id = id}
        function Tab:SetLocked(v) tabLock.SetLocked(nil, v) end
        function Tab:SetHidden(v)
            tabLock.SetHidden(nil, v)
            if v and activeTabId == id then
                for otherId,fr in pairs(tabFrames) do
                    if otherId ~= id and tabUI[otherId] and tabUI[otherId].btn.Visible then switchToTab(otherId); break end
                end
            end
        end
        function Tab:IsLocked() return tabLock.IsLocked() end
        function Tab:IsHidden() return tabLock.IsHidden() end
        function Tab:ToggleLocked() return tabLock.ToggleLocked() end
        function Tab:ToggleHidden() local v = not tabLock.IsHidden(); self:SetHidden(v); return v end
        -- вкладку можно выбрать и удалить из кода (Preview UI использует это: крестик удаляет вкладку)
        function Tab:Select() if tabFrames[id] then switchToTab(id) end end
        function Tab:IsRemoved() return Tab._removed == true end
        function Tab:Remove()
            if Tab._removed then return end
            Tab._removed = true
            local wasActive = (activeTabId == id)
            tabFrames[id] = nil; tabUI[id] = nil; tabScrollers[id] = nil; sbBtns[id] = nil
            pcall(hideTip)
            pcall(function() btn:Destroy() end)
            pcall(function() tabFrame:Destroy() end)
            queueSidebar()
            if wasActive then
                activeTabId = nil
                local pick
                for oid,u in pairs(tabUI) do
                    if u.btn.Visible and oid < id and (not pick or oid > pick) then pick = oid end
                end
                if not pick then
                    for oid,u in pairs(tabUI) do
                        if u.btn.Visible and (not pick or oid < pick) then pick = oid end
                    end
                end
                if pick then switchToTab(pick) end
            end
            if topts.OnClose then pcall(topts.OnClose, Tab) end
        end
        local function mkScroll(dir)
            local sc = Instance.new("ScrollingFrame"); sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1; sc.BorderSizePixel = 0
            sc.ScrollBarThickness = 4; sc.ScrollBarImageColor3 = ACCENTS[1]; sc.CanvasSize = UDim2.new(0,0,0,0); sc.ScrollingDirection = dir; sc.Parent = tabFrame
            return sc
        end
        if typ == "Grid" then
            local scroll = mkScroll(Enum.ScrollingDirection.XY)
            local colCon = Instance.new("Frame"); colCon.Size = UDim2.new(0,0,0,0); colCon.Position = UDim2.new(0,3,0,3); colCon.BackgroundTransparency = 1; colCon.Parent = scroll
            local cols = {}; local ncols = 0; local secCount = {}
            local pager = Instance.new("Frame"); pager.Size = UDim2.new(1,0,0,24); pager.Position = UDim2.new(0,0,1,-24); pager.BackgroundTransparency = 1; pager.Visible = false; pager.Parent = tabFrame
            local pl = Instance.new("UIListLayout"); pl.FillDirection = Enum.FillDirection.Horizontal; pl.HorizontalAlignment = Enum.HorizontalAlignment.Center
            pl.VerticalAlignment = Enum.VerticalAlignment.Center; pl.Padding = UDim.new(0,4); pl.SortOrder = Enum.SortOrder.LayoutOrder; pl.Parent = pager
            local chips = {}
            local function curCol() return math.floor(scroll.CanvasPosition.X / (colW + COLGAP) + 0.5) + 1 end
            local function curPage() return math.floor((curCol() - 1) / VIS) + 1 end
            local function numPages() return math.max(1, math.ceil(ncols / VIS)) end
            local function goCol(i)
                i = math.clamp(i, 1, math.max(1, ncols - VIS + 1))
                createTween(scroll, TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new((i - 1) * (colW + COLGAP), scroll.CanvasPosition.Y)}):Play()
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
                scroll.CanvasSize = UDim2.new(0, (ncols > VIS) and (total + 8) or 0, 0, mH + 14)
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
                local best,bc = 1,math.huge
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
        else
            local scroll = mkScroll(Enum.ScrollingDirection.Y)
            local listCon = Instance.new("Frame"); listCon.Size = UDim2.new(0,listW,0,0); listCon.Position = UDim2.new(0,3,0,3); listCon.BackgroundTransparency = 1; listCon.Parent = scroll
            local listL = Instance.new("UIListLayout"); listL.FillDirection = Enum.FillDirection.Vertical; listL.Padding = UDim.new(0,8); listL.SortOrder = Enum.SortOrder.LayoutOrder; listL.Parent = listCon
            listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                local h = listL.AbsoluteContentSize.Y
                listCon.Size = UDim2.new(0,listW,0,h); scroll.CanvasSize = UDim2.new(0,0,0,h + 14)
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
    -- ===== Addons: файлы .lua / .txt из папки. Секции и контролы создаются автоматически по пометкам в комментариях =====
    local AM = {list = {}, tab = nil, building = false, booted = false}
    AM.dir = opts.AddonsFolder or "JustLib/Addons"
    local ADDON_EXT = {lua = true, txt = true, luau = true}
    local WARN_COL = Color3.fromRGB(255,190,80)
    local ERR_COL = Color3.fromRGB(255,82,82)
    local function amWarnOn() return cfgGet("_addons_warn", true) ~= false end
    local function amFsOK() return readfile and listfiles and isfolder and makefolder end
    local function amEnsureDir()
        if not (isfolder and makefolder) then return false end
        local path = ""
        for part in string.gmatch(AM.dir, "[^/\\]+") do
            path = (path == "") and part or (path .. "/" .. part)
            local ok,ex = pcall(isfolder, path)
            if ok and not ex then pcall(makefolder, path) end
        end
        local ok,ex = pcall(isfolder, AM.dir)
        return ok and ex == true
    end
    local function amTrim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
    local function amCoerce(v)
        if v == "true" then return true elseif v == "false" then return false end
        return tonumber(v) or v
    end
    local function amVerParts(s)
        local t = {}
        for n in tostring(s or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
        return t
    end
    local function amVerCmp(a, b) -- >0: a новее b
        local x, y = amVerParts(a), amVerParts(b)
        for i = 1, 2 do -- сравниваем только major.minor: патч-версия (4.0.1) не считается новой
            local p, q = x[i] or 0, y[i] or 0
            if p ~= q then return p > q and 1 or -1 end
        end
        return 0
    end
    local function amShowVer(s) return "v" .. (tostring(s):gsub("^[vV]%s*", "")) end
    -- "Имя" tip="..." notify="..." default=true  /  Имя key=value
    local function amArgs(s)
        s = amTrim(s)
        local o, name = {}, nil
        local q, rest = s:match('^"([^"]*)"%s*(.*)$')
        if not q then q, rest = s:match("^'([^']*)'%s*(.*)$") end
        if q then name = q; s = rest
        elseif s:match("^[%w_]+%s*=") then name = nil
        else
            local pos = s:find("%s[%w_]+%s*=")
            if pos then name = s:sub(1, pos - 1); s = s:sub(pos + 1) else name = s; s = "" end
        end
        s = s:gsub('([%w_]+)%s*=%s*"([^"]*)"', function(k, v) o[k:lower()] = v; return "" end)
        s = s:gsub("([%w_]+)%s*=%s*'([^']*)'", function(k, v) o[k:lower()] = v; return "" end)
        for k, v in s:gmatch("([%w_]+)%s*=%s*([^%s]+)") do o[k:lower()] = amCoerce(v) end
        if name and name ~= "" then o.name = amTrim(name) end
        return o
    end
    local CTRL_KINDS = {toggle = true, button = true, slider = true, dropdown = true, input = true, label = true, divider = true}
    local NUMERIC_MODS = {default = true, min = true, max = true, step = true}
    local function amParse(src)
        local meta, ctrls, notes = {}, {}, {}
        local pending, libLine
        local n = 0
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            line = line:gsub("\r$", "")
            local key, rest = line:match("^%s*%-%-@([%w_]+)%s*(.-)%s*$")
            if key then
                key = key:lower()
                if key == "name" then meta.name = rest
                elseif key == "author" then meta.author = rest
                elseif key == "version" then meta.version = rest
                elseif key == "lib" or key == "requires" or key == "target" or key == "jl" then meta.lib = rest
                elseif key == "description" or key == "desc" then meta.desc = rest
                elseif CTRL_KINDS[key] then
                    if pending then notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " has no function below it"; pending = nil end
                    local isStatic = (key == "label" or key == "divider")
                    local c = {kind = key, o = isStatic and {name = rest} or amArgs(rest), line = n}
                    if isStatic then ctrls[#ctrls + 1] = c else pending = c end
                elseif pending then
                    if key == "tooltip" then key = "tip" end
                    if NUMERIC_MODS[key] then pending.o[key] = amCoerce(rest) else pending.o[key] = rest end
                end
            else
                local v = line:match('^%s*local%s+Version%s*=%s*["\']([^"\']+)["\']') or line:match('^%s*Version%s*=%s*["\']([^"\']+)["\']')
                if v and not libLine then libLine = v end
                if pending then
                    local fname = line:match("^%s*local%s+function%s+([%w_]+)") or line:match("^%s*function%s+([%w_]+)%s*%(")
                        or line:match("^%s*local%s+([%w_]+)%s*=%s*function") or line:match("^%s*([%w_]+)%s*=%s*function")
                    if fname then
                        pending.fn = fname
                        if not pending.o.name then pending.o.name = fname end
                        ctrls[#ctrls + 1] = pending; pending = nil
                    elseif line:match("%S") and not line:match("^%s*%-%-") then
                        notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " must be followed by a function"
                        pending = nil
                    end
                end
            end
        end
        if pending then notes[#notes + 1] = "line " .. pending.line .. ": --@" .. pending.kind .. " has no function below it" end
        meta.lib = (meta.lib and meta.lib ~= "") and meta.lib or libLine
        return meta, ctrls, notes
    end
    -- добавляем в конец файла строки, которые отдают отмеченные функции библиотеке (работает и для local function)
    local function amBuildCode(src, ctrls)
        local names, seen = {}, {}
        for _, c in ipairs(ctrls) do
            if c.fn and not seen[c.fn] then seen[c.fn] = true; names[#names + 1] = string.format("__JLA.fn[%q] = %s", c.fn, c.fn) end
        end
        local body = src
        if #names > 0 then
            local lines = {}
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
            local at
            for i = #lines, 1, -1 do
                local l = lines[i]
                if l:match("%S") and not l:match("^%s*%-%-") then
                    if l:match("^%s*return[%s%(%{\"'%[]") or l:match("^%s*return%s*$") then at = i end
                    break
                end
            end
            local footer = table.concat(names, "\n")
            if at then table.insert(lines, at, footer); body = table.concat(lines, "\n")
            else body = src .. "\n" .. footer .. "\n" end
        end
        return "local Addon, __JLA = ...; " .. body
    end

    function AM.scan()
        AM.list = {}; AM.fsNote = nil
        if not amFsOK() then AM.fsNote = "Your executor does not support the file functions needed for Addons"; return end
        if not amEnsureDir() then AM.fsNote = "Could not open the folder " .. AM.dir; return end
        local ok,files = pcall(listfiles, AM.dir)
        if not ok or type(files) ~= "table" then AM.fsNote = "Could not read the folder " .. AM.dir; return end
        table.sort(files, function(x, y) return tostring(x):lower() < tostring(y):lower() end)
        local used = {}
        for _, p in ipairs(files) do
            local base, ext = tostring(p):match("([^\\/]+)%.(%w+)$")
            if base and ext and ADDON_EXT[ext:lower()] then
                local okr, src = pcall(readfile, p)
                if okr and type(src) == "string" and #src > 0 and #src < 600000 then
                    local id = base:lower():gsub("[^%w]+", "_")
                    local baseId, k = id, 1
                    while used[id] do k = k + 1; id = baseId .. k end
                    used[id] = true
                    src = src:gsub("^\239\187\191", "")
                    local meta, ctrls, notes = amParse(src)
                    if not meta.name or meta.name == "" then meta.name = base end
                    local a = {id = id, file = base .. "." .. ext, src = src, meta = meta, ctrls = ctrls, notes = notes, loaded = false, keeps = {}, unload = {}}
                    if meta.lib and meta.lib ~= "" then
                        local cmp = amVerCmp(JL.Version, meta.lib)
                        a.outdated = cmp > 0; a.needsNewer = cmp < 0
                    end
                    AM.list[#AM.list + 1] = a
                end
            end
        end
    end

    local function amSetErr(a, msg)
        a.err = msg
        JL:Notify({Title = a.meta.name, Desc = msg, Type = "Error", Duration = 5})
        if a.sec then
            pcall(function()
                if not a.errCtl then a.errCtl = a.sec:Label({Text = "", Color = ERR_COL}) end
                a.errCtl:Set("⚠ " .. msg); a.errCtl:SetHidden(false)
            end)
        end
    end
    local function amClearErr(a)
        a.err = nil
        if a.errCtl then pcall(function() a.errCtl:SetHidden(true) end) end
    end
    local function amFire(a, c, value)
        local n = c.o.notify
        if n == nil or n == false or c.kind == "slider" then return end
        local text
        if n == true then
            text = (c.kind == "toggle") and (c.name .. (value and " enabled" or " disabled")) or c.name
        else
            text = tostring(n)
            text = text:gsub("{state}", function() return value and "On" or "Off" end)
            text = text:gsub("{value}", function() return tostring(value) end)
            text = text:gsub("{name}", function() return c.name end)
        end
        local t = tostring(c.o.ntype or "Info"); t = t:sub(1, 1):upper() .. t:sub(2):lower()
        if t ~= "Success" and t ~= "Warn" and t ~= "Error" then t = "Info" end
        JL:Notify({Title = a.meta.name, Desc = text, Type = t, Duration = 3})
    end
    local function amCall(a, c, ...)
        local f = a.store and a.store.fn and a.store.fn[c.fn]
        if type(f) ~= "function" then
            amSetErr(a, "Function '" .. tostring(c.fn) .. "' was not found (define it at the top level of the file)")
            return false
        end
        local ok, err = pcall(f, ...)
        if not ok then amSetErr(a, tostring(c.name) .. ": " .. tostring(err)); return false end
        return true
    end
    local function amClean(a)
        for i = #a.keeps, 1, -1 do
            local x = a.keeps[i]
            pcall(function()
                local t = typeof(x)
                if t == "RBXScriptConnection" then x:Disconnect()
                elseif t == "Instance" then x:Destroy()
                elseif t == "function" then x()
                elseif t == "thread" then pcall(task.cancel, x)
                elseif t == "table" then
                    if x.Destroy then x:Destroy() elseif x.Disconnect then x:Disconnect() end
                end
            end)
        end
        a.keeps = {}
    end
    -- объект Addon, доступный коду аддона
    local function amApi(a)
        local api = {Name = a.meta.name, Id = a.id, Library = JL, LibVersion = JL.Version, Window = Win}
        local function dual(f) return function(x, ...) if x == api then return f(...) end return f(x, ...) end end
        api.Notify = dual(function(msg, typ, title)
            if type(msg) == "table" then JL:Notify(msg)
            else JL:Notify({Title = title or a.meta.name, Desc = tostring(msg), Type = typ or "Info", Duration = 3}) end
        end)
        api.Keep = dual(function(x) a.keeps[#a.keeps + 1] = x; return x end)
        api.OnUnload = dual(function(fn) if type(fn) == "function" then a.unload[#a.unload + 1] = fn end end)
        api.Save = dual(function(k, v) cfgSet("addon." .. a.id .. ".data." .. tostring(k), v) end)
        api.Load = dual(function(k, d) return cfgGet("addon." .. a.id .. ".data." .. tostring(k), d) end)
        return api
    end

    function AM.enable(a)
        if a.loaded then return true end
        local fn, err = loadstring(amBuildCode(a.src, a.ctrls), "=Addon_" .. a.id)
        if not fn then amSetErr(a, "Syntax error: " .. tostring(err)); return false end
        amClearErr(a)
        a.keeps = {}; a.unload = {}; a.store = {fn = {}}
        local api = amApi(a)
        local runErr
        a.thread = trackedSpawn(function()
            local ok, e = pcall(fn, api, a.store)
            if not ok then runErr = tostring(e) end
        end)
        if runErr then
            amClean(a); a.store = nil; a.thread = nil
            amSetErr(a, runErr)
            return false
        end
        a.loaded = true
        for _, c in ipairs(a.ctrls) do
            if c.ui and c.ui.SetLocked then pcall(function() c.ui:SetLocked(false) end) end
        end
        -- применяем текущие значения (включённые тоглы, слайдеры, списки)
        for _, c in ipairs(a.ctrls) do
            if c.fn then
                if c.kind == "toggle" then if c.state then amCall(a, c, true) end
                elseif c.kind == "slider" or c.kind == "dropdown" then if c.state ~= nil then amCall(a, c, c.state) end
                elseif c.kind == "input" then if c.state and c.state ~= "" then amCall(a, c, c.state) end end
            end
        end
        if amWarnOn() and (a.outdated or a.needsNewer) then
            local msg = a.outdated
                and ("Made for JustLib " .. amShowVer(a.meta.lib) .. ", you have " .. amShowVer(JL.Version) .. ". It may not work correctly.")
                or ("Needs JustLib " .. amShowVer(a.meta.lib) .. " or newer, you have " .. amShowVer(JL.Version) .. ". It may not work correctly.")
            JL:Notify({Title = a.meta.name, Desc = msg, Type = "Warn", Duration = 5})
        end
        return true
    end

    function AM.disable(a, skipUI)
        if not a.loaded then return end
        a.loaded = false
        for _, c in ipairs(a.ctrls) do
            if c.fn and c.kind == "toggle" and c.state then
                local f = a.store and a.store.fn and a.store.fn[c.fn]
                if type(f) == "function" then pcall(f, false) end
            end
        end
        for i = #a.unload, 1, -1 do pcall(a.unload[i]) end
        a.unload = {}
        amClean(a)
        if a.thread then pcall(task.cancel, a.thread); a.thread = nil end
        a.store = nil
        if skipUI then return end
        for _, c in ipairs(a.ctrls) do
            pcall(function()
                if c.kind == "toggle" and c.ui and c.state then c.ui:Set(false); c.state = false end
                if c.ui and c.ui.SetLocked then c.ui:SetLocked(true) end
            end)
        end
    end

    function AM.disableAll(skipUI)
        for _, a in ipairs(AM.list) do
            if a.loaded then
                if a.enableCtl and not skipUI then pcall(function() a.enableCtl:Set(false) end) end
                AM.disable(a, skipUI)
            end
        end
    end

    local function amBuildControl(a, sec, c)
        local o = c.o
        local nm = tostring(o.name or c.fn or c.kind)
        c.name = nm
        if c.kind == "label" then c.ui = sec:Label({Text = nm, Tooltip = o.tip and tostring(o.tip) or nil}); return end
        if c.kind == "divider" then c.ui = sec:Divider({Label = (nm ~= "" and nm or nil)}); return end
        local flag = "addon." .. a.id .. "." .. tostring(c.fn or (c.kind .. c.line))
        local b = {
            Name = nm, Tooltip = o.tip and tostring(o.tip) or nil, NoSave = true,
            Locked = true, LockedTitle = a.meta.name, LockedMessage = "Enable the addon first",
        }
        if o.icon then b.Icon = tostring(o.icon) end
        local function run(...)
            if AM.building or not a.loaded then return false end
            return amCall(a, c, ...)
        end
        if c.kind == "toggle" then
            b.Flag = flag; b.Default = (o.default == true)
            c.state = cfgGet(flag, b.Default) == true
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Toggle(b)
        elseif c.kind == "button" then
            b.Callback = function() if run() then amFire(a, c, true) end end
            c.ui = sec:Button(b)
        elseif c.kind == "slider" then
            b.Flag = flag
            b.Min = tonumber(o.min) or 0; b.Max = tonumber(o.max) or 100; b.Step = tonumber(o.step) or 1
            b.Default = tonumber(o.default) or b.Min
            if o.suffix then b.Suffix = tostring(o.suffix) end
            c.state = tonumber(cfgGet(flag, b.Default)) or b.Default
            b.Callback = function(v) c.state = v; run(v) end
            c.ui = sec:Slider(b)
        elseif c.kind == "dropdown" then
            local list = {}
            for part in tostring(o.options or ""):gmatch("[^,]+") do list[#list + 1] = amTrim(part) end
            b.Flag = flag; b.Options = list; b.MultiSelect = (o.multi == true)
            if o.default ~= nil then b.Default = tostring(o.default) end
            c.state = cfgGet(flag, b.Default)
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Dropdown(b)
        elseif c.kind == "input" then
            b.Flag = flag
            if o.placeholder then b.Placeholder = tostring(o.placeholder) end
            c.state = tostring(cfgGet(flag, o.default ~= nil and tostring(o.default) or "") or "")
            b.Callback = function(v) c.state = v; if run(v) then amFire(a, c, v) end end
            c.ui = sec:Input(b)
        end
    end

    local function amBuildSection(a)
        local sec = AM.tab:Section({Title = a.meta.name})
        a.sec = sec
        a.enableCtl = sec:Toggle({
            Name = "Enabled", Flag = "addon." .. a.id .. ".enabled", Default = false, NoSave = true, Tooltip = a.meta.desc,
            Callback = function(v)
                if AM.building then return end
                if v then if not AM.enable(a) then pcall(function() a.enableCtl:Set(false) end) end
                else AM.disable(a) end
            end,
        })
        local sub = {}
        if a.meta.author and a.meta.author ~= "" then sub[#sub + 1] = "by " .. a.meta.author end
        if a.meta.version and a.meta.version ~= "" then sub[#sub + 1] = amShowVer(a.meta.version) end
        sub[#sub + 1] = a.file
        sec:Label({Text = table.concat(sub, "  ·  ")})
        if a.meta.desc and a.meta.desc ~= "" then sec:Label({Text = a.meta.desc, Color = C.txt}) end
        if amWarnOn() then
            if a.outdated then
                sec:Label({Text = "⚠ Made for JustLib " .. amShowVer(a.meta.lib) .. " (you have " .. amShowVer(JL.Version) .. "). It may not work correctly.", Color = WARN_COL})
            elseif a.needsNewer then
                sec:Label({Text = "⚠ Needs JustLib " .. amShowVer(a.meta.lib) .. " or newer (you have " .. amShowVer(JL.Version) .. ").", Color = WARN_COL})
            end
        end
        for _, note in ipairs(a.notes) do sec:Label({Text = "⚠ " .. note, Color = WARN_COL}) end
        local hasCtl = false
        for _, c in ipairs(a.ctrls) do if c.kind ~= "label" and c.kind ~= "divider" then hasCtl = true end end
        if hasCtl then sec:Divider({Label = "Controls"}) end
        for _, c in ipairs(a.ctrls) do
            local ok, e = pcall(amBuildControl, a, sec, c)
            if not ok then sec:Label({Text = "⚠ " .. tostring(c.o.name or c.fn) .. ": " .. tostring(e), Color = ERR_COL}) end
        end
    end

    function AM.buildTab()
        if AM.tab then return end
        AM.building = true
        AM.tab = Win:Tab({Name = "Addons", Icon = "◈", Type = "Grid", Tooltip = "Addons"})
        local top = AM.tab:Section({Title = "Addons", Column = 1})
        top:Label({Text = "Folder: " .. AM.dir .. "  ·  .lua .txt .luau"})
        top:Label({Text = "⚠ Addons are code with full access. Only enable addons you trust.", Color = WARN_COL})
        if AM.fsNote then top:Label({Text = AM.fsNote, Color = ERR_COL}) end
        top:Toggle({
            Name = "Auto Save", Flag = "_addons_autosave", Default = false,
            Tooltip = "Off (default): addons and their toggles start disabled every launch. On: they are remembered and restored.",
            Callback = function(v)
                JL._addonAutoSave = v
                if AM.building then return end
                if v and JL._cfgFlush then JL._cfgFlush() end
                JL:Notify({Title = "Addons", Desc = v and "Auto Save on: enabled addons will be restored next launch" or "Auto Save off: addons start disabled next launch", Type = "Info", Duration = 3})
            end,
        })
        top:Button({Name = "Reload Addons", Tooltip = "Re-reads the folder. Running addons are restarted", Callback = function() AM.refresh() end})
        top:Button({Name = "Disable All", Tooltip = "Turns off every running addon", Callback = function() AM.disableAll() end})
        if #AM.list == 0 and not AM.fsNote then
            top:Label({Text = "No addon files found yet. Put .lua or .txt files into the folder and press Reload Addons."})
        end
        for _, a in ipairs(AM.list) do
            local ok, e = pcall(amBuildSection, a)
            if not ok then warn("[JustLib] addon '" .. tostring(a.file) .. "' UI failed: " .. tostring(e)) end
        end
        AM.building = false
        -- Auto Save включён: поднимаем аддоны, которые были включены в прошлый раз
        for _, a in ipairs(AM.list) do
            if a.enableCtl and cfgGet("addon." .. a.id .. ".enabled", false) == true then
                if not AM.enable(a) then pcall(function() a.enableCtl:Set(false) end) end
            end
        end
    end

    function AM.removeTab()
        if AM.tab then
            local t = AM.tab; AM.tab = nil
            pcall(function() t:Remove() end)
        end
    end

    function AM.refresh()
        if not AM.tab then return end
        local keep = {}
        for _, a in ipairs(AM.list) do if a.loaded then keep[a.id] = true end end
        AM.disableAll()
        AM.removeTab()
        AM.scan()
        AM.buildTab()
        for _, a in ipairs(AM.list) do
            if keep[a.id] and not a.loaded then
                if AM.enable(a) then pcall(function() a.enableCtl:Set(true) end) end
            end
        end
        if AM.tab and AM.tab.Select then AM.tab:Select() end
    end

    function AM.setEnabled(on)
        if on then
            if not AM.tab then AM.scan(); AM.buildTab() end
        else
            AM.disableAll()
            AM.removeTab()
        end
    end
    function AM.boot()
        if AM.booted then return end
        AM.booted = true
        if cfgGet("_addons_on", false) == true then AM.setEnabled(true) end
    end
    table.insert(JL._unloadHooks, function() AM.disableAll(true) end)
    function Win:Addons() AM.boot(); return AM end
    JL._addons = AM
    -- ===== Remote: плавающая панель быстрого доступа (тоглы, кнопки и кейбинды под рукой; удобно на телефоне) =====
    -- Игрок сам выбирает, какие разрешённые разработчиком Toggle / Button / Keybind закреплять в Remote UI.
    local RM = {items = {}, available = {}, built = false, open = false, editMode = false, opts = {}, idCounts = {}}
    local RM_W, RM_HDR, RM_ROW, RM_GAP, RM_MAXROWS, RM_PILL = 208, 36, 32, 4, 7, 46
    local RM_KEYS = {LeftShift="LShift",RightShift="RShift",LeftControl="LCtrl",RightControl="RCtrl",LeftAlt="LAlt",RightAlt="RAlt",
        Return="Enter",Backspace="Back",Escape="Esc",Space="Space",Tab="Tab",CapsLock="Caps",Insert="Ins",Delete="Del",
        PageUp="PgUp",PageDown="PgDn",MouseButton1="LMB",MouseButton2="RMB",MouseButton3="MMB"}
    local function rmKeyName(k)
        if not k then return "None" end
        local n = (typeof(k) == "EnumItem") and k.Name or tostring(k)
        return RM_KEYS[n] or n
    end
    local function rmViewport()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(1280,720)
    end
    function RM.fit()
        local v = rmViewport()
        local base = math.clamp(math.min(v.X / 900, v.Y / 520), 0.8, 1.15)
        return base * (tonumber(cfgGet("_remote_scale", 100)) or 100) / 100
    end
    function RM.clamp()
        if not RM.holder then return end
        local v = rmViewport()
        local sz = RM.holder.Size
        local x = math.clamp(RM.px or 0, 0, math.max(0, v.X - sz.X.Offset))
        local y = math.clamp(RM.py or 0, 0, math.max(0, v.Y - sz.Y.Offset))
        RM.px, RM.py = x, y
        RM.holder.Position = UDim2.new(0,x,0,y)
    end
    function RM.savePos()
        local v = rmViewport()
        cfgSet("_remote_x", (RM.px or 0) / math.max(v.X, 1)); cfgSet("_remote_y", (RM.py or 0) / math.max(v.Y, 1))
    end
    function RM.restorePos()
        local v = rmViewport()
        RM.px = (tonumber(cfgGet("_remote_x", 0.012)) or 0.012) * v.X
        RM.py = (tonumber(cfgGet("_remote_y", 0.30)) or 0.30) * v.Y
        RM.clamp()
    end
    function RM.setLogical(lw, lh)
        RM.lw, RM.lh = lw, lh
        local s = RM.s or 1
        RM.canvas.Size = UDim2.new(0,lw,0,lh)
        RM.holder.Size = UDim2.new(0,lw * s,0,lh * s)
        RM.clamp()
    end
    function RM.applyScale()
        if not RM.built then return end
        RM.s = RM.fit(); RM.scale.Scale = RM.s
        RM.setLogical(RM.lw or RM_PILL, RM.lh or RM_PILL)
    end
    function RM.applyOpacity()
        if not RM.built then return end
        local t = 1 - (tonumber(cfgGet("_remote_opacity", 94)) or 94) / 100
        RM.panel.BackgroundTransparency = t; RM.hdr.BackgroundTransparency = t; RM.hdrFix.BackgroundTransparency = t; RM.pill.BackgroundTransparency = t
    end
    local function rmCount()
        local n = 0
        for _,it in ipairs(RM.items) do
            if it.kind == "toggle" then local ok,v = pcall(it.ret.Get, it.ret); if ok and v then n = n + 1 end end
        end
        return n
    end
    function RM.updateBadge()
        if not RM.built then return end
        local n = rmCount()
        RM.hdrBadge.Visible = n > 0; RM.hdrBadgeTxt.Text = n .. " on"
        RM.pillBadge.Visible = n > 0; RM.pillBadgeTxt.Text = tostring(n)
    end
    function RM.layout(animate)
        if not RM.built then return end
        local n = #RM.items
        local shown = math.min(n, RM_MAXROWS)
        local bodyH = (n == 0) and 36 or (shown * (RM_ROW + RM_GAP) - RM_GAP)
        RM.panelH = RM_HDR + 6 + bodyH + 8
        RM.list.Position = UDim2.new(0,6,0,RM_HDR + 6); RM.list.Size = UDim2.new(1,-12,0,bodyH)
        RM.list.CanvasSize = UDim2.new(0,0,0,n * (RM_ROW + RM_GAP))
        RM.empty.Visible = (n == 0)
        if RM.open then
            RM.setLogical(RM_W, RM.panelH)
            if animate then tw(RM.panel,{Size = UDim2.new(1,0,0,RM.panelH)},.3,Enum.EasingStyle.Quint)
            else RM.panel.Size = UDim2.new(1,0,0,RM.panelH) end
        end
    end
    function RM.setOpen(open, instant)
        open = open and true or false
        RM.open = open; cfgSet("_remote_open", open)
        if not RM.built then return end
        local anim = (not instant) and cfgGet("_anim", true) ~= false
        RM.tok = (RM.tok or 0) + 1; local tok = RM.tok
        if open then
            RM.setLogical(RM_W, RM.panelH)
            RM.panel.Visible = true
            if anim then
                RM.panel.Size = UDim2.new(1,0,0,RM_PILL)
                tw(RM.panel,{Size = UDim2.new(1,0,0,RM.panelH)},.36,Enum.EasingStyle.Quint)
                tw(RM.pillScale,{Scale = 0},.14)
                trackedDelay(.15, function() if RM.tok == tok and RM.pill then RM.pill.Visible = false end end)
            else
                RM.panel.Size = UDim2.new(1,0,0,RM.panelH); RM.pill.Visible = false
            end
        else
            if anim then
                tw(RM.panel,{Size = UDim2.new(1,0,0,RM_PILL)},.26,Enum.EasingStyle.Quint)
                trackedDelay(.27, function()
                    if RM.tok ~= tok or not RM.pill then return end
                    RM.panel.Visible = false; RM.setLogical(RM_PILL, RM_PILL)
                    RM.pill.Visible = true; RM.pillScale.Scale = 0.5
                    tw(RM.pillScale,{Scale = 1},.32,Enum.EasingStyle.Back)
                end)
            else
                RM.panel.Visible = false; RM.setLogical(RM_PILL, RM_PILL); RM.pill.Visible = true; RM.pillScale.Scale = 1
            end
        end
        RM.updateBadge()
    end
    -- перетаскивание: за шапку или за кружок; короткое касание без движения считается нажатием
    local function rmDrag(handle, onTap)
        handle.InputBegan:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
            local startIn = Vector2.new(i.Position.X, i.Position.Y)
            local sx, sy = RM.px or 0, RM.py or 0
            local moved = false
            local c1, c2
            c1 = keep(UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    local d = Vector2.new(m.Position.X, m.Position.Y) - startIn
                    if not moved and d.Magnitude > 6 then moved = true end
                    if moved then RM.px, RM.py = sx + d.X, sy + d.Y; RM.clamp() end
                end
            end))
            c2 = keep(UIS.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then
                    c1:Disconnect(); c2:Disconnect()
                    if moved then RM.savePos() elseif onTap then onTap() end
                end
            end))
        end)
    end
    local function rmFlash(row, strokeObj)
        tw(row,{BackgroundColor3 = ACCENTS[1]},.07)
        tw(strokeObj,{Color = ACCENTS[1]},.07)
        trackedDelay(.16, function()
            if row.Parent then
                local on = row:GetAttribute("on")
                tw(row,{BackgroundColor3 = on and C.badgeHi or C.btnBg},.24); tw(strokeObj,{Color = C.border},.24)
            end
        end)
    end
    local function rmMakeRow(item)
        local row = Instance.new("TextButton"); row.Size = UDim2.new(0,RM_W - 16 - 4,0,RM_ROW); row.BackgroundColor3 = C.btnBg; row.BorderSizePixel = 0
        row.AutoButtonColor = false; row.Text = ""; row.LayoutOrder = item.order; row.Parent = RM.list
        corner(8, row); local st = stroke(C.border, 1, row)
        local label = newTxt({Parent=row,Text=item.name,Font=GB,Size=11,Sz=UDim2.new(1,-66,1,0),Pos=UDim2.new(0,10,0,0),Z=3})
        item.row = row
        local function pressFx() rmFlash(row, st) end
        if item.kind == "toggle" then
            local sw = mkSwitch(row, UDim2.new(1,-44,0.5,-9), item.ret:Get() and true or false, ACCENTS[1])
            item.refresh = function()
                local on = item.ret:Get() and true or false
                row:SetAttribute("on", on); sw.Set(on)
                tw(row,{BackgroundColor3 = on and C.badgeHi or C.btnBg},.2)
                tw(label,{TextColor3 = on and C.txt or C.dim},.2)
            end
            item.refresh()
            item.ret:Watch(function() item.refresh(); RM.updateBadge() end)
            row.MouseButton1Click:Connect(function() item.ret:Click() end)
        elseif item.kind == "button" then
            local ch = spChev(row, "right", C.dim, 4); ch.Position = UDim2.new(1,-16,0.5,0)
            row.MouseButton1Click:Connect(function() pressFx(); item.ret:Click() end)
        elseif item.kind == "keybind" then
            local chip = Instance.new("Frame"); chip.Size = UDim2.new(0,48,0,20); chip.AnchorPoint = Vector2.new(1,0.5); chip.Position = UDim2.new(1,-8,0.5,0)
            chip.BackgroundColor3 = C.input; chip.BorderSizePixel = 0; chip.Parent = row; corner(6, chip); stroke(C.border, 1, chip)
            local kt = newTxt({Parent=chip,Text=rmKeyName(item.ret:Get()),Font=GB,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=4})
            item.ret:Watch(function(k) kt.Text = rmKeyName(k) end)
            if item.ret.OnPulse then item.ret:OnPulse(pressFx) end
            row.MouseButton1Click:Connect(function() pressFx(); item.ret:Press() end)
        end
        row.MouseEnter:Connect(function()
            if touchLast() then return end
            if not row:GetAttribute("on") then tw(row,{BackgroundColor3 = C.btnHov},.12) end
        end)
        row.MouseLeave:Connect(function()
            tw(row,{BackgroundColor3 = row:GetAttribute("on") and C.badgeHi or C.btnBg},.12)
        end)
        -- появление строки
        row.BackgroundTransparency = 1; label.TextTransparency = 1
        tw(row,{BackgroundTransparency = 0},.25); tw(label,{TextTransparency = 0},.25)
    end

    function RM.build()
        if RM.built then return end
        RM.built = true
        local gui = Instance.new("ScreenGui"); gui.Name = "JLRemote"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 998
        local okp = pcall(function() gui.Parent = game:GetService("CoreGui") end); if not okp or not gui.Parent then gui.Parent = PG end
        RM.gui = gui
        table.insert(JL._extraRoots, gui)
        -- holder: размер в пикселях (его двигаем), canvas: логический размер + UIScale
        local holder = Instance.new("Frame"); holder.BackgroundTransparency = 1; holder.BorderSizePixel = 0; holder.Size = UDim2.new(0,RM_PILL,0,RM_PILL); holder.Parent = gui
        local canvas = Instance.new("Frame"); canvas.BackgroundTransparency = 1; canvas.BorderSizePixel = 0; canvas.Size = UDim2.new(0,RM_PILL,0,RM_PILL); canvas.Parent = holder
        local sc = Instance.new("UIScale"); sc.Parent = canvas
        RM.holder, RM.canvas, RM.scale = holder, canvas, sc

        -- развёрнутая панель
        local panel = Instance.new("Frame"); panel.Size = UDim2.new(1,0,0,RM_HDR); panel.BackgroundColor3 = C.panel; panel.BorderSizePixel = 0
        panel.ClipsDescendants = true; panel.Visible = false; panel.Parent = canvas; corner(12, panel); stroke(C.border, 1, panel)
        RM.panel = panel
        local hdr = Instance.new("Frame"); hdr.Size = UDim2.new(1,0,0,RM_HDR); hdr.BackgroundColor3 = C.pHdr; hdr.BorderSizePixel = 0; hdr.Parent = panel; corner(12, hdr)
        local hfix = Instance.new("Frame"); hfix.Size = UDim2.new(1,0,0,12); hfix.Position = UDim2.new(0,0,1,-12); hfix.BackgroundColor3 = C.pHdr; hfix.BorderSizePixel = 0; hfix.Parent = hdr
        local hline = Instance.new("Frame"); hline.Size = UDim2.new(1,0,0,1); hline.Position = UDim2.new(0,0,1,0); hline.BackgroundColor3 = C.divLine; hline.BorderSizePixel = 0; hline.Parent = hdr
        RM.hdr, RM.hdrFix = hdr, hfix
        for i = 0,2 do -- «ручка» для перетаскивания
            local d = Instance.new("Frame"); d.Size = UDim2.new(0,3,0,3); d.Position = UDim2.new(0,10 + i * 5,0.5,-1); d.BackgroundColor3 = C.dim; d.BorderSizePixel = 0; d.ZIndex = 3; d.Parent = hdr; corner(2, d)
        end
        local title = newTxt({Parent=hdr,Text=RM.opts.Title or "Remote",Font=GB,Size=12,Sz=UDim2.new(0,70,1,0),Pos=UDim2.new(0,30,0,0),Z=3})
        RM.title = title
        local bdg = Instance.new("Frame"); bdg.Size = UDim2.new(0,40,0,16); bdg.Position = UDim2.new(0,92,0.5,-8); bdg.BackgroundColor3 = ACCENTS[1]; bdg.BackgroundTransparency = 0.8; bdg.BorderSizePixel = 0
        bdg.Visible = false; bdg.ZIndex = 3; bdg.Parent = hdr; corner(8, bdg)
        RM.hdrBadge = bdg
        RM.hdrBadgeTxt = newTxt({Parent=bdg,Text="0 on",Font=GB,Size=10,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Center,Z=4})
        local drag = Instance.new("TextButton"); drag.Size = UDim2.new(1,-70,1,0); drag.BackgroundTransparency = 1; drag.Text = ""; drag.AutoButtonColor = false; drag.ZIndex = 2; drag.Parent = hdr
        rmDrag(drag, nil)
        local function hdrBtn(x, kind, fn)
            local b = Instance.new("TextButton"); b.Size = UDim2.new(0,26,0,26); b.Position = UDim2.new(1,x,0.5,-13); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.Text = ""
            b.AutoButtonColor = false; b.ZIndex = 4; b.Parent = hdr; corner(7, b); stroke(C.border, 1, b)
            local ic = spIcon(kind, b, 14, C.dim, 5); ic.Position = UDim2.new(0.5,-7,0.5,-7)
            b.MouseEnter:Connect(function() if not touchLast() then tw(b,{BackgroundColor3 = C.btnHov},.12) end end)
            b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.12) end)
            b.MouseButton1Click:Connect(fn)
            return b
        end
        hdrBtn(-62, "window", function() Win:Toggle() end)
        hdrBtn(-32, "minus", function() RM.setOpen(false) end)

        local list = Instance.new("ScrollingFrame"); list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.ScrollBarThickness = 2; list.ScrollBarImageColor3 = ACCENTS[1]
        list.CanvasSize = UDim2.new(0,0,0,0); list.Parent = panel
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,RM_GAP); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = list
        RM.list = list
        RM.empty = newTxt({Parent=panel,Text="Use Edit Remote Items to choose toggles, buttons and keybinds",Font=GM,Size=10,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-24,0,30),Pos=UDim2.new(0,12,0,RM_HDR + 10)})

        -- свёрнутая «таблетка»
        local pill = Instance.new("TextButton"); pill.Size = UDim2.new(0,RM_PILL,0,RM_PILL); pill.BackgroundColor3 = C.panel; pill.BorderSizePixel = 0; pill.Text = ""
        pill.AutoButtonColor = false; pill.Parent = canvas; corner(RM_PILL / 2, pill); stroke(ACCENTS[1], 1.5, pill)
        RM.pill = pill
        RM.pillScale = Instance.new("UIScale"); RM.pillScale.Parent = pill
        local mi = spIcon("menu", pill, 20, ACCENTS[1], 3); mi.Position = UDim2.new(0.5,-10,0.5,-10)
        local pb = Instance.new("Frame"); pb.Size = UDim2.new(0,18,0,18); pb.Position = UDim2.new(1,-16,0,-2); pb.BackgroundColor3 = C.togOn; pb.BorderSizePixel = 0
        pb.Visible = false; pb.ZIndex = 6; pb.Parent = pill; corner(9, pb)
        RM.pillBadge = pb
        RM.pillBadgeTxt = newTxt({Parent=pb,Text="0",Font=GB,Size=10,Color=Color3.new(1,1,1),XAlign=Enum.TextXAlignment.Center,Z=7})
        rmDrag(pill, function() RM.setOpen(true) end)

        RM.s = RM.fit(); sc.Scale = RM.s
        RM.restorePos()
        RM.applyOpacity()
        for _,it in ipairs(RM.items) do rmMakeRow(it) end
        RM.layout(false)
        RM.open = cfgGet("_remote_open", not touchLast()) == true
        RM.setLogical(RM_PILL, RM_PILL)
        RM.setOpen(RM.open, true)
        keep(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() RM.applyScale(); RM.restorePos() end))
    end

    local function rmPinnedMap()
        local map = cfgGet("_remote_pins", {})
        return type(map) == "table" and map or {}
    end
    function RM.isPinned(id)
        return rmPinnedMap()[id] == true
    end
    function RM.savePins(map)
        cfgSet("_remote_pins", map)
    end
    function RM.findItem(id)
        for i,item in ipairs(RM.items) do if item.id == id then return i,item end end
    end
    function RM.removeItem(id)
        local index = RM.findItem(id)
        if not index then return end
        table.remove(RM.items, index)
        for i,item in ipairs(RM.items) do item.order = i end
        if RM.built then RM.layout(true); RM.updateBadge() end
        RM.refresh()
    end
    function RM.refresh()
        local on = cfgGet("_remote_on", true) ~= false
        if on and #RM.items > 0 then
            RM.build()
            if RM.gui then RM.gui.Enabled = true end
        elseif RM.gui then
            RM.gui:Destroy()
            RM.gui, RM.built = nil, false
        end
    end
    function RM.addItem(item)
        if item.id then
            local _,existing = RM.findItem(item.id)
            if existing then existing.ret = item.ret; existing.name = item.name; return existing end
        end
        item.order = #RM.items + 1
        RM.items[#RM.items + 1] = item
        if RM.built then
            rmMakeRow(item); RM.layout(true); RM.updateBadge()
        end
        RM.refresh()
        return item
    end
    function RM.setEditMode(enabled)
        RM.editMode = enabled == true
        JL._remoteEditActive = RM.editMode
        for _,button in ipairs(JL._metaButtons or {}) do
            if button and button.Parent then button.Visible = not RM.editMode end
        end
        for _,entry in ipairs(RM.available) do
            if entry.setEditLayout then entry.setEditLayout(RM.editMode) end
            if entry.pinButton then
                entry.pinButton.Visible = RM.editMode
                entry.pinButton.Text = RM.isPinned(entry.id) and "✓" or "+"
                entry.pinButton.BackgroundColor3 = RM.isPinned(entry.id) and ACCENTS[1] or C.btnBg
            end
        end
        if RM.editMode then
            JL:Notify({Title = "Remote Edit Mode", Desc = "Browse the tabs and tap + beside a supported control to pin it. Tap ✓ to remove it.", Type = "Info", Duration = 5})
        else
            JL:Notify({Title = "Remote Edit Mode", Desc = "Editing finished.", Type = "Success", Duration = 2})
        end
        return RM.editMode
    end
    function RM.togglePin(entry)
        local map = {}; for id,value in pairs(rmPinnedMap()) do map[id] = value end
        if map[entry.id] then
            map[entry.id] = nil
            RM.savePins(map)
            RM.removeItem(entry.id)
        else
            map[entry.id] = true
            RM.savePins(map)
            RM.addItem({id = entry.id, kind = entry.kind, name = entry.name, ret = entry.ret})
        end
        if entry.pinButton then
            entry.pinButton.Text = RM.isPinned(entry.id) and "✓" or "+"
            entry.pinButton.BackgroundColor3 = RM.isPinned(entry.id) and ACCENTS[1] or C.btnBg
        end
        return RM.isPinned(entry.id)
    end
    function RM.clearPins()
        RM.savePins({})
        RM.items = {}
        for _,entry in ipairs(RM.available) do
            if entry.pinButton then
                entry.pinButton.Text = "+"
                entry.pinButton.BackgroundColor3 = C.btnBg
            end
        end
        RM.refresh()
    end
    function RM.destroy()
        if RM.gui then pcall(function() RM.gui:Destroy() end) end
        for _,entry in ipairs(RM.available) do
            if entry.pinButton then pcall(function() entry.pinButton:Destroy() end) end
        end
        RM.gui, RM.built, RM.items, RM.available = nil, false, {}, {}
        RM.editMode = false
        JL._remoteEditActive = false
        for _,button in ipairs(JL._metaButtons or {}) do
            if button and button.Parent then button.Visible = true end
        end
        JL._remote = nil
    end
    -- Remote = true разрешает игроку закреплять функцию, но не добавляет её автоматически.
    JL._remoteAttach = function(kind, o, ret)
        if not o or not o.Remote or type(ret) ~= "table" or not ret.Row then return end
        local nm = (type(o.Remote) == "table" and o.Remote.Name) or o.Name or kind
        local baseId = tostring(o.Flag or (kind:lower() .. ":" .. tostring(nm)))
        RM.idCounts[baseId] = (RM.idCounts[baseId] or 0) + 1
        local id = baseId .. ":" .. tostring(RM.idCounts[baseId])
        local entry = {id = id, kind = kind:lower(), name = tostring(nm), ret = ret}
        -- Toggle owns its layout closure; this keeps the label and switch in sync.
        if entry.kind == "toggle" and type(ret._remoteEditLayout) == "function" then
            entry.setEditLayout = ret._remoteEditLayout
        end
        local pin = Instance.new("TextButton")
        pin.Name = "JLRemotePin"; pin.Size = UDim2.new(0,22,0,22); pin.AnchorPoint = Vector2.new(1,0.5)
        pin.Position = UDim2.new(1,-4,0.5,0); pin.BackgroundColor3 = C.btnBg; pin.BorderSizePixel = 0
        pin.AutoButtonColor = false; pin.Text = RM.isPinned(id) and "✓" or "+"; pin.Font = GB; pin.TextSize = 15
        pin.TextColor3 = Color3.new(1,1,1); pin.Visible = RM.editMode; pin.ZIndex = 20; pin.Parent = ret.Row
        if entry.setEditLayout then entry.setEditLayout(RM.editMode) end
        corner(6,pin); stroke(C.border,1,pin)
        pin.MouseButton1Click:Connect(function()
            if RM.editMode then RM.togglePin(entry) end
        end)
        entry.pinButton = pin
        RM.available[#RM.available + 1] = entry
        if RM.isPinned(id) then RM.addItem({id=id,kind=entry.kind,name=entry.name,ret=ret}) end
    end

    -- публичный объект: Win:Remote(...)
    local RemoteAPI = {}
    function RemoteAPI:Toggle(o)
        o = o or {}
        local state = cfgGet(o.Flag, o.Default or false) == true
        local watchers, ret = {}, {}
        local function fire(v) for _,w in ipairs(watchers) do pcall(w, v) end end
        ret.Get = function() return state end
        ret.Click = function()
            state = not state; cfgSet(o.Flag, state)
            if o.Callback then pcall(o.Callback, state) end
            fire(state)
        end
        ret.Set = function(_, v) state = v and true or false; cfgSet(o.Flag, state); fire(state) end
        ret.Watch = function(_, fn) watchers[#watchers + 1] = fn end
        if o.Key then keep(UIS.InputBegan:Connect(function(i,gp) if not gp and not JL._listening and i.KeyCode == o.Key then ret.Click() end end)) end
        RM.addItem({kind = "toggle", name = o.Name or "Toggle", ret = ret})
        return ret
    end
    function RemoteAPI:Button(o)
        o = o or {}
        local ret = {Click = function() if o.Callback then pcall(o.Callback) end end}
        if o.Key then keep(UIS.InputBegan:Connect(function(i,gp) if not gp and not JL._listening and i.KeyCode == o.Key then ret.Click() end end)) end
        RM.addItem({kind = "button", name = o.Name or "Button", ret = ret})
        return ret
    end
    function RemoteAPI:Keybind(o)
        o = o or {}
        local key = o.Key or o.Default
        local pulses, ret = {}, {}
        local function run() if o.Callback then pcall(o.Callback) end end
        ret.Get = function() return key end
        ret.Press = function() run() end
        ret.Watch = function() end
        ret.OnPulse = function(_, fn) pulses[#pulses + 1] = fn end
        if key then keep(UIS.InputBegan:Connect(function(i,gp)
            if not gp and not JL._listening and i.KeyCode == key then run(); for _,p in ipairs(pulses) do pcall(p) end end
        end)) end
        RM.addItem({kind = "keybind", name = o.Name or "Keybind", ret = ret})
        return ret
    end
    function RemoteAPI:Show() cfgSet("_remote_on", true); RM.refresh() end
    function RemoteAPI:Hide() if RM.gui then RM.gui.Enabled = false end end
    function RemoteAPI:SetOpen(v) RM.refresh(); if RM.built then RM.setOpen(v) end end
    function RemoteAPI:Edit(enabled)
        if enabled == nil then enabled = not RM.editMode end
        return RM.setEditMode(enabled)
    end
    function RemoteAPI:IsOpen() return RM.open end
    function RemoteAPI:SetPosition(ud)
        RM.refresh()
        if RM.built and ud then
            local v = rmViewport()
            RM.px = ud.X.Scale * v.X + ud.X.Offset; RM.py = ud.Y.Scale * v.Y + ud.Y.Offset
            RM.clamp(); RM.savePos()
        end
    end
    function RemoteAPI:Destroy() RM.destroy() end
    function RM.resetPos() cfgSet("_remote_x", 0.012); cfgSet("_remote_y", 0.30); RM.restorePos() end
    function Win:Remote(ropts)
        RM.opts = ropts or RM.opts or {}
        if RM.title and RM.opts.Title then RM.title.Text = RM.opts.Title end
        if RM.opts.Open ~= nil and not cfgHas("_remote_open") then cfgSet("_remote_open", RM.opts.Open) end
        if RM.opts.Key then
            keep(UIS.InputBegan:Connect(function(i,gp)
                if gp or JL._listening then return end
                if i.KeyCode == RM.opts.Key and RM.built then RM.setOpen(not RM.open) end
            end))
        end
        RM.refresh()
        JL._remote = RemoteAPI
        return RemoteAPI
    end
    table.insert(JL._unloadHooks, function() RM.destroy() end)
    table.insert(JL._themeHooks, function()
        if RM.built then
            pcall(function() RM.list.ScrollBarImageColor3 = ACCENTS[1] end)
            pcall(function() RM.hdrBadge.BackgroundColor3 = ACCENTS[1]; RM.hdrBadgeTxt.TextColor3 = ACCENTS[1] end)
        end
    end)
    function Win:Settings()
        if opts.Settings == false then return nil end
        local sTab = self:Tab({Icon = "settings", Type = "Custom", Name = "Settings"})
        local root = sTab.Frame
        local ACC = ACCENTS[1]
        local navW = 146
        local PW = IW - navW - 8
        local nav = Instance.new("Frame"); nav.Size = UDim2.new(0,navW,1,0); nav.BackgroundColor3 = C.panel; nav.BorderSizePixel = 0; nav.Parent = root; corner(10,nav); stroke(C.border,1,nav)
        newTxt({Parent=nav,Text=opts.Title or "JustLib",Font=GB,Size=15,Sz=UDim2.new(1,-28,0,20),Pos=UDim2.new(0,14,0,14)})
        newTxt({Parent=nav,Text="Settings · v" .. JL.Version,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-28,0,14),Pos=UDim2.new(0,14,0,35)})
        local nl = Instance.new("Frame"); nl.Size = UDim2.new(1,-28,0,1); nl.Position = UDim2.new(0,14,0,58); nl.BackgroundColor3 = C.divLine; nl.BackgroundTransparency = 0.4; nl.BorderSizePixel = 0; nl.Parent = nav
        local navList = Instance.new("ScrollingFrame"); navList.Name = "SettingsNavigation"; navList.Size = UDim2.new(1,-16,1,-74); navList.Position = UDim2.new(0,8,0,68)
        navList.BackgroundTransparency = 1; navList.BorderSizePixel = 0; navList.ClipsDescendants = true
        navList.ScrollBarThickness = 3; navList.ScrollBarImageColor3 = ACC; navList.ScrollingDirection = Enum.ScrollingDirection.Y
        navList.CanvasSize = UDim2.new(0,0,0,0); navList.AutomaticCanvasSize = Enum.AutomaticSize.None; navList.Parent = nav
        local nlay = Instance.new("UIListLayout"); nlay.Padding = UDim.new(0,4); nlay.SortOrder = Enum.SortOrder.LayoutOrder; nlay.Parent = navList
        nlay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            navList.CanvasSize = UDim2.new(0,0,0,nlay.AbsoluteContentSize.Y + 8)
        end)
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
            local sf = Instance.new("ScrollingFrame"); sf.Name = "JLSettingsPage_" .. tostring(name); sf:SetAttribute("JLSearchPage", tostring(name)); sf.Size = UDim2.new(1,0,1,0); sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.ScrollBarThickness = 3
            sf.ScrollBarImageColor3 = ACC; sf.CanvasSize = UDim2.new(0,0,0,0); sf.Visible = false; sf.Parent = holder
            local L = Instance.new("UIListLayout"); L.SortOrder = Enum.SortOrder.LayoutOrder; L.Parent = sf; pad(3,5,3,0,sf)
            L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0,0,0,unscaleWin(L.AbsoluteContentSize.Y) + 8) end)
            local nb = Instance.new("TextButton"); nb.Size = UDim2.new(1,0,0,32); nb.BackgroundColor3 = ACC; nb.BackgroundTransparency = 1; nb.BorderSizePixel = 0; nb.AutoButtonColor = false
            nb.Text = ""; nb.LayoutOrder = pOrd; nb.Parent = navList; corner(7,nb)
            local lbl = newTxt({Parent=nb,Text=name,Font=GB,Size=12,Color=C.dim,Sz=UDim2.new(1,-20,1,0),Pos=UDim2.new(0,14,0,0)})
            local bar = Instance.new("Frame"); bar.Size = UDim2.new(0,3,0,16); bar.Position = UDim2.new(0,0,0.5,-8); bar.BackgroundColor3 = ACC; bar.BorderSizePixel = 0; bar.Visible = false; bar.Parent = nb; corner(2,bar)
            pages[name] = {sf = sf, btn = nb, lbl = lbl, bar = bar, sub = sub}
            JL._searchPageTargets[sf] = function()
                if pages[name].sf.Visible then return false end
                showPage(name)
                return true
            end
            nb.MouseButton1Click:Connect(function() showPage(name) end)
            return sf
        end
        local rowOrd = 0
        local function mkRow(sf,title,desc,ctrlW)
            rowOrd = rowOrd + 1
            local labW = PW - 32 - ctrlW - 14
            local th = fitH(title, 13, GB, labW, 0, 0); local dh = desc and fitH(desc, 10, GM, labW, 0, 0) or 0
            local h = math.max(48, th + dh + (desc and 24 or 22))
            local row = Instance.new("Frame"); row.Name = "JLSettingsRow"; row:SetAttribute("JLSearchSection", tostring(title)); row.Size = UDim2.new(1,0,0,h); row.BackgroundTransparency = 1; row.BorderSizePixel = 0; row.LayoutOrder = rowOrd; row.Parent = sf
            if JL._searchRegister then JL._searchRegister({Name = title, Kind = "Settings", Row = row}) end
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
        local pA = newPage("Interface", "Appearance, themes and interface controls")
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
        addSwitch(pA, "Sidebar Labels", "Tab names under the sidebar icons. Takes effect the next time the hub starts", "_sidebar_labels", opts.SidebarLabels == true, function()
            JL:Notify({Title = "Sidebar", Desc = "Restart the hub to apply", Type = "Info", Duration = 3})
        end)
        local pT = pA
        rowOrd = rowOrd + 1
        local themeIntro = Instance.new("Frame"); themeIntro.Size = UDim2.new(1,0,0,26); themeIntro.BackgroundTransparency = 1; themeIntro.LayoutOrder = rowOrd; themeIntro.Parent = pT
        newTxt({Parent=themeIntro,Text="Pick a palette — everything on screen repaints live",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-32,1,0),Pos=UDim2.new(0,16,0,0)})
        rowOrd = rowOrd + 1
        local themeGrid = Instance.new("Frame"); themeGrid.Size = UDim2.new(1,-32,0,0); themeGrid.Position = UDim2.new(0,16,0,0); themeGrid.BackgroundTransparency = 1; themeGrid.LayoutOrder = rowOrd; themeGrid.Parent = pT
        local tgl = Instance.new("UIGridLayout"); tgl.CellSize = UDim2.new(0,128,0,74); tgl.CellPadding = UDim2.new(0,8,0,8); tgl.SortOrder = Enum.SortOrder.LayoutOrder; tgl.Parent = themeGrid
        tgl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() themeGrid.Size = UDim2.new(1,-32,0,tgl.AbsoluteContentSize.Y) end)
        table.insert(JL._noRepaintRoots, themeGrid)
        local themeCards = {}
        local function paintCards()
            for nm,ref in pairs(themeCards) do
                local on = (nm == JL._currentTheme)
                ref.sub.Text = on and "Active" or ""
                ref.ring.Thickness = on and 2 or 1
            end
        end
        for i,nm in ipairs(JL._themeOrder) do
            local th = JL._themes[nm]
            local card = Instance.new("Frame"); card.Size = UDim2.new(0,128,0,74); card.BackgroundColor3 = th.panel; card.BorderSizePixel = 0; card.LayoutOrder = i; card.Parent = themeGrid
            corner(9,card); local ring = stroke(th.accents[1],1,card)
            local prevBar = Instance.new("Frame"); prevBar.Size = UDim2.new(1,-12,0,28); prevBar.Position = UDim2.new(0,6,0,6); prevBar.BackgroundColor3 = th.pHdr; prevBar.BorderSizePixel = 0; prevBar.Parent = card; corner(6,prevBar)
            local dotsHolder = Instance.new("Frame"); dotsHolder.Size = UDim2.new(0,0,0,10); dotsHolder.Position = UDim2.new(0.5,0,0.5,-5); dotsHolder.AnchorPoint = Vector2.new(0.5,0); dotsHolder.BackgroundTransparency = 1; dotsHolder.Parent = prevBar
            local dl = Instance.new("UIListLayout"); dl.FillDirection = Enum.FillDirection.Horizontal; dl.Padding = UDim.new(0,4); dl.SortOrder = Enum.SortOrder.LayoutOrder; dl.Parent = dotsHolder
            dl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() dotsHolder.Size = UDim2.new(0,dl.AbsoluteContentSize.X,0,10) end)
            for k = 1,4 do
                local dot = Instance.new("Frame"); dot.Size = UDim2.new(0,10,0,10); dot.BackgroundColor3 = th.accents[k] or th.accents[1]; dot.BorderSizePixel = 0; dot.LayoutOrder = k; dot.Parent = dotsHolder; corner(5,dot)
            end
            newTxt({Parent=card,Text=nm,Font=GB,Size=12,Color=th.txt,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-8,0,16),Pos=UDim2.new(0,4,0,40)})
            local sub = newTxt({Parent=card,Text="",Font=GM,Size=9,Color=th.accents[1],XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-8,0,12),Pos=UDim2.new(0,4,0,57)})
            local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.Parent = card
            themeCards[nm] = {card = card, ring = ring, sub = sub}
            btn.MouseButton1Click:Connect(function() JL:SetTheme(nm); paintCards() end)
        end
        paintCards()
        local pI = pA
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
        local pPrivacy = newPage("Privacy", "Hide your identity on your screen while recording")
        addSwitch(pPrivacy, "Streamer Mode", "Locally masks your username and display name in visible UI text, including the hub, player list and overhead labels", "_streamer_mode", false, function(v)
            JL:SetStreamerMode(v)
        end)
        JL:SetStreamerMode(cfgGet("_streamer_mode", false) == true)
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
        local pV = newPage("Preview UI", "Settings for the Preview tab")
        local function pvApply() if JL._preview and JL._preview.ApplySettings then JL._preview:ApplySettings() end end
        addSwitch(pV, "Auto Rotate", "Spins the model on the Preview page. Drag to rotate by hand, scroll or pinch to zoom", "_pv_autorotate", true, function() pvApply() end)
        addSlider(pV, "Rotate Speed", "Degrees per second for Auto Rotate", "_pv_rotspeed", 40, 5, 180, 5, "°/s", function() pvApply() end)
        addSlider(pV, "Card Size", "Minimum width of the cards in the grid", "_pv_card", 140, 100, 240, 10, "px", function() pvApply() end)
        addSwitch(pV, "Animations", "Slide-out panel and card animations", "_pv_anim", true, function() end)
        addSwitch(pV, "Remember Last Tab", "Reopens the Preview tab on the tab and page you used last", "_pv_remember", true, function() end)
        addButton(pV, "Open Preview", "Creates the Preview tab if it does not exist and switches to it", "Open", false, function()
            if JL._preview then JL._preview:Open() else JL:Notify({Title = "Preview UI", Desc = "No Preview created. Use JL:Preview()", Type = "Warn", Duration = 3}) end
        end)
        local pD = newPage("Addons", "Extensions loaded from the Addons folder")
        addSwitch(pD, "Enable Addons", "Shows the Addons tab and lets you load addon files. Addons are code with full access: only use ones you trust", "_addons_on", false, function(v) AM.setEnabled(v) end)
        addSwitch(pD, "Version Warnings", "Warns when an addon was made for a different JustLib version", "_addons_warn", true, function() end)
        addButton(pD, "Reload Addons", "Re-reads the folder and restarts running addons", "Reload", false, function()
            if AM.tab then AM.refresh() else JL:Notify({Title = "Addons", Desc = "Turn on Enable Addons first", Type = "Warn", Duration = 3}) end
        end)
        addValue(pD, "Folder", "Put .lua / .txt files here. Mark functions with --@toggle / --@button / --@slider / --@dropdown above them", AM.dir)
        local pR = newPage("Remote", "Floating quick-access panel for toggles, buttons and keybinds")
        addButton(pR, "Edit Remote Items", "Enter edit mode, browse your tabs and pin supported controls with the + button beside them", "Edit", false, function()
            RM.setEditMode(not RM.editMode)
        end)
        addButton(pR, "Clear All Pins", "Removes every function from Remote UI", "Clear", false, function()
            if confirmDialog("Clear Remote UI", "Remove all pinned functions from Remote UI?", {Danger = true, ConfirmText = "Clear"}) then
                RM.clearPins()
            end
        end)
        addSwitch(pR, "Show Remote", "Shows the floating panel only when at least one function is pinned", "_remote_on", true, function() RM.refresh() end)
        addSlider(pR, "Remote Scale", "Size of the floating panel", "_remote_scale", 100, 70, 150, 5, "%", function() RM.applyScale() end)
        addSlider(pR, "Remote Opacity", "How solid the panel and its button are", "_remote_opacity", 94, 40, 100, 2, "%", function() RM.applyOpacity() end)
        addButton(pR, "Expand / Collapse", "Opens the panel or folds it into a small button", "Toggle", false, function()
            RM.refresh(); if RM.built then RM.setOpen(not RM.open) end
        end)
        addButton(pR, "Reset Position", "Moves the panel back to its default place", "Reset", false, function() RM.resetPos() end)
        local pP = newPage("Presets", "Save and load snapshots of your enabled features")
        addSwitch(pP, "Auto Save", "Remembers your toggles and values between launches. Turn it off to start clean every time (interface settings are always saved). Use a preset to keep a setup", "_autosave", true, function(v)
            JL._autoSave = v
            if v and JL._cfgFlush then JL._cfgFlush() end
        end)
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
            trackedDelay(.16, function() if not open2 then list2.Visible = false end end)
        end
        local function refreshProfiles()
            for _,c in ipairs(list2:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            local names = listProfiles()
            if selectedProfile and not table.find(names, selectedProfile) then selectedProfile = nil end
            selLbl.Text = selectedProfile or "— none —"
            for i,nm in ipairs(names) do
                local b = Instance.new("TextButton"); b.Size = UDim2.new(1,0,0,24); b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = nm; b.Font = GB; b.TextSize = 11; b.TextColor3 = (nm == selectedProfile) and ACC or C.txt; b.LayoutOrder = i; b.Parent = list2; corner(5,b)
                b.MouseEnter:Connect(function() if touchLast() then return end tw(b,{BackgroundColor3 = C.btnHov},.1) end)
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
        addValue(pP, "Config File", "Interface settings always save. Toggles and values save while Auto Save is on", _cfgFile or "not set (nothing is saved)")
        addButton(pP, "Copy Config", "Copies the whole saved config (interface + toggles) as JSON to the clipboard", "Copy", false, function()
            if setclipboard then
                setclipboard(HTTP:JSONEncode(_cfgData)); JL:Notify({Title = "Config", Desc = "Copied to clipboard", Type = "Success", Duration = 3})
            else JL:Notify({Title = "Config", Desc = "Clipboard is not supported by your executor", Type = "Error", Duration = 4}) end
        end)
        local importBox
        do
            rowOrd = rowOrd + 1
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,72); row.BackgroundTransparency = 1; row.LayoutOrder = rowOrd; row.Parent = pP
            newTxt({Parent=row,Text="Import Config",Font=GB,Size=13,Sz=UDim2.new(1,-32,0,16),Pos=UDim2.new(0,16,0,8)})
            newTxt({Parent=row,Text="Paste a copied config below, then Import",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-32,0,12),Pos=UDim2.new(0,16,0,24)})
            local pasteBg = Instance.new("Frame"); pasteBg.Size = UDim2.new(1,-32,0,28); pasteBg.Position = UDim2.new(0,16,0,40); pasteBg.BackgroundColor3 = C.pHdr; pasteBg.BorderSizePixel = 0; pasteBg.Parent = row; corner(6,pasteBg); stroke(C.border,1,pasteBg)
            importBox = Instance.new("TextBox"); importBox.Size = UDim2.new(1,-16,1,0); importBox.Position = UDim2.new(0,8,0,0); importBox.BackgroundTransparency = 1
            importBox.PlaceholderText = "Paste JSON here..."; importBox.PlaceholderColor3 = C.dim; importBox.Font = GB; importBox.TextSize = 11; importBox.TextColor3 = C.txt
            importBox.ClearTextOnFocus = false; importBox.Text = ""; importBox.Parent = pasteBg
            local sep = Instance.new("Frame"); sep.Size = UDim2.new(1,-32,0,1); sep.Position = UDim2.new(0,16,1,-1); sep.BackgroundColor3 = C.divLine; sep.BackgroundTransparency = 0.6; sep.BorderSizePixel = 0; sep.Parent = row
        end
        addButton(pP, "Import Pasted Config", "Applies any matching feature toggles found in the pasted text above", "Import", false, function()
            local raw = importBox.Text
            if not raw or raw:gsub("%s","") == "" then JL:Notify({Title = "Presets", Desc = "Paste a config first", Type = "Warn", Duration = 3}); return end
            local ok,data = pcall(HTTP.JSONDecode, HTTP, raw)
            if not ok or type(data) ~= "table" then JL:Notify({Title = "Presets", Desc = "That doesn't look like valid config JSON", Type = "Error", Duration = 4}); return end
            local applied = 0
            for flag,val in pairs(data) do
                local ctrl = JL._registry[flag]
                if ctrl and ctrl.Set then pcall(function() ctrl:Set(val) end); applied = applied + 1 end
            end
            JL:Notify({Title = "Config Imported", Desc = applied .. " setting(s) applied", Type = (applied > 0) and "Success" or "Warn", Duration = 4})
        end)
        local pC = newPage("Backup", "Restore interface defaults")
        addButton(pC, "Reset interface", "Restores every setting on the Interface page", "Reset", true, function()
            if confirmDialog("Reset Settings", "Restore all interface settings to their defaults?", {Danger = true, ConfirmText = "Reset"}) then
                for _,fn in ipairs(resetters) do pcall(fn) end
            end
        end)
        local pB = newPage("About", "JustLib")
        addValue(pB, "Version", nil, "JustLib v" .. JL.Version)
        addValue(pB, "Tabs loaded", nil, tostring(_tabCount))
        addValue(pB, "Columns", "Visible at once. Left Shift + wheel scrolls sideways", tostring(VIS))
        addButton(pB, "Close Hub", "Fully unloads the hub", "Unload", true, function()
            if unloadDialog() then destroyHub() end
        end)
        showPage("Interface")
        AM.boot()
        RM.refresh()
        return sTab
    end
    trackedDefer(function()
        if _dead then return end
        if cfgGet("_autoload", false) then
            local nm = cfgGet("_autoload_name", "")
            if nm and nm ~= "" then pcall(loadProfile, nm) end
        end
    end)
    function Win:HomeTab(hopts)
        hopts = hopts or {}
        local T = self:Tab({Name = hopts.Name or "Home", Icon = hopts.Icon or "house", Tooltip = hopts.Tooltip, Type = "Custom"})
        local id = T.Id
        if tabUI[id] then tabUI[id].btn.LayoutOrder = -1000 end
        switchToTab(id)
        local root = T.Frame
        local scroll = Instance.new("ScrollingFrame"); scroll.Size = UDim2.new(1,0,1,0); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4; scroll.ScrollBarImageColor3 = ACCENTS[1]; scroll.CanvasSize = UDim2.new(0,0,0,0); scroll.Parent = root
        local listCon = Instance.new("Frame"); listCon.Size = UDim2.new(1,-6,0,0); listCon.Position = UDim2.new(0,3,0,3); listCon.BackgroundTransparency = 1; listCon.Parent = scroll
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0,10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = listCon
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h = unscaleWin(list.AbsoluteContentSize.Y)
            listCon.Size = UDim2.new(1,-6,0,h); scroll.CanvasSize = UDim2.new(0,0,0,h + 14)
        end)
        local ord = 0
        local function newCard(h)
            ord = ord + 1
            local c = Instance.new("Frame"); c.Size = UDim2.new(1,0,0,h); c.BackgroundColor3 = C.panel; c.BorderSizePixel = 0; c.LayoutOrder = ord; c.Parent = listCon
            corner(10,c); stroke(C.border,1,c)
            return c
        end
        do
            ord = ord + 1
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,0,0,26); row.BackgroundTransparency = 1; row.LayoutOrder = ord; row.Parent = listCon
            newTxt({Parent=row,Text="Welcome to " .. (hopts.WelcomeTitle or opts.Title or "the Hub") .. "!",Font=GB,Size=17,Sz=UDim2.new(1,0,1,0),Pos=UDim2.new(0,2,0,0)})
        end
        do
            local h = 180
            local card = newCard(h)
            card.BackgroundTransparency = 1
            for _,child in ipairs(card:GetChildren()) do
                if child:IsA("UIStroke") then child.Transparency = 1 end
            end

            local playerCard = Instance.new("Frame")
            playerCard.Name = "PlayerCard"
            playerCard.Size = UDim2.new(1,-194,0,180)
            playerCard.Position = UDim2.new(0,0,0,0)
            playerCard.BackgroundColor3 = C.panel
            playerCard.BorderSizePixel = 0
            playerCard.ClipsDescendants = true
            playerCard.Parent = card
            corner(10,playerCard)
            stroke(C.border,1,playerCard)

            local profileAccent = Instance.new("Frame")
            profileAccent.Size = UDim2.new(0,3,1,-20)
            profileAccent.Position = UDim2.new(0,0,0,10)
            profileAccent.BackgroundColor3 = ACCENTS[1]
            profileAccent.BorderSizePixel = 0
            profileAccent.Parent = playerCard
            corner(2,profileAccent)

            newTxt({Parent=playerCard,Text="PLAYER PROFILE",Font=GB,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,14),Pos=UDim2.new(0,14,0,10)})

            local statusChip = Instance.new("Frame")
            statusChip.Name = "PlayerStatus"
            statusChip.Size = UDim2.new(0,78,0,22)
            statusChip.Position = UDim2.new(1,-90,0,7)
            statusChip.BackgroundColor3 = C.pHdr
            statusChip.BorderSizePixel = 0
            statusChip.Parent = playerCard
            corner(7,statusChip)
            local statusDot = Instance.new("Frame")
            statusDot.Size = UDim2.new(0,6,0,6)
            statusDot.Position = UDim2.new(0,8,0.5,-3)
            statusDot.BackgroundColor3 = C.fpsGrn
            statusDot.BorderSizePixel = 0
            statusDot.Parent = statusChip
            corner(3,statusDot)
            newTxt({Parent=statusChip,Text="ONLINE",Font=GB,Size=9,Color=C.fpsGrn,Sz=UDim2.new(1,-20,1,0),Pos=UDim2.new(0,18,0,0)})

            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0,64,0,64)
            avatar.Position = UDim2.new(0,14,0,48)
            avatar.BackgroundColor3 = C.pHdr
            avatar.BorderSizePixel = 0
            avatar.Parent = playerCard
            avatar:SetAttribute("JLNoRepaint", true)
            corner(32,avatar)
            trackedSpawn(function()
                local ok,content = pcall(function()
                    return game:GetService("Players"):GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                end)
                if ok then avatar.Image = content end
            end)

            newTxt({Parent=playerCard,Text="Welcome back,",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,13),Pos=UDim2.new(0,90,0,48)})
            newTxt({Parent=playerCard,Text=LP.DisplayName,Font=GB,Size=16,Sz=UDim2.new(1,-104,0,22),Pos=UDim2.new(0,90,0,63)})
            newTxt({Parent=playerCard,Text="@" .. LP.Name,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-104,0,14),Pos=UDim2.new(0,90,0,86)})

            local profileDivider = Instance.new("Frame")
            profileDivider.Size = UDim2.new(1,-28,0,1)
            profileDivider.Position = UDim2.new(0,14,0,122)
            profileDivider.BackgroundColor3 = C.border
            profileDivider.BorderSizePixel = 0
            profileDivider.Parent = playerCard

            local execName,execVer = detectExecutor()
            local executorText = execName or "Unknown"
            if execVer and execVer ~= "" then executorText = executorText .. " " .. tostring(execVer) end
            newTxt({Parent=playerCard,Text="EXECUTOR",Font=GB,Size=9,Color=C.dim,Sz=UDim2.new(0.48,-18,0,12),Pos=UDim2.new(0,14,0,132)})
            newTxt({Parent=playerCard,Text=executorText,Font=GB,Size=11,Color=execName and C.txt or C.dim,Sz=UDim2.new(0.48,-18,0,16),Pos=UDim2.new(0,14,0,148)})
            newTxt({Parent=playerCard,Text="ACCOUNT AGE",Font=GB,Size=9,Color=C.dim,Sz=UDim2.new(0.48,-18,0,12),Pos=UDim2.new(0.52,4,0,132)})
            newTxt({Parent=playerCard,Text=tostring(LP.AccountAge) .. " days",Font=GB,Size=11,Sz=UDim2.new(0.48,-18,0,16),Pos=UDim2.new(0.52,4,0,148)})

            local changelogFrame = Instance.new("Frame")
            changelogFrame.Name = "ChangelogFrame"
            changelogFrame.Size = UDim2.new(0,180,0,180)
            changelogFrame.Position = UDim2.new(1,-180,0,0)
            changelogFrame.BackgroundColor3 = C.panel
            changelogFrame.BorderSizePixel = 0
            changelogFrame.ClipsDescendants = true
            changelogFrame.Parent = card
            corner(9,changelogFrame)
            stroke(C.border,1,changelogFrame)

            local changelogAccent = Instance.new("Frame")
            changelogAccent.Size = UDim2.new(1,-20,0,2)
            changelogAccent.Position = UDim2.new(0,10,0,0)
            changelogAccent.BackgroundColor3 = ACCENTS[1]
            changelogAccent.BorderSizePixel = 0
            changelogAccent.Parent = changelogFrame
            corner(1,changelogAccent)

            newTxt({Parent=changelogFrame,Text="WHAT'S NEW",Font=GB,Size=10,Sz=UDim2.new(1,-72,0,14),Pos=UDim2.new(0,10,0,8)})
            local changelogCount = # (type(hopts.Changelog) == "table" and hopts.Changelog or {})
            newTxt({Parent=changelogFrame,Text=tostring(changelogCount) .. " updates",Font=GM,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,64,0,14),Pos=UDim2.new(1,-74,0,8)})

            local changelogScroll = Instance.new("ScrollingFrame")
            changelogScroll.Name = "ChangelogList"
            changelogScroll.Size = UDim2.new(1,-12,1,-38)
            changelogScroll.Position = UDim2.new(0,6,0,32)
            changelogScroll.BackgroundTransparency = 1
            changelogScroll.BorderSizePixel = 0
            changelogScroll.ScrollBarThickness = 2
            changelogScroll.ScrollBarImageColor3 = ACCENTS[1]
            changelogScroll.ScrollingDirection = Enum.ScrollingDirection.Y
            changelogScroll.CanvasSize = UDim2.new(0,0,0,0)
            changelogScroll.Parent = changelogFrame

            changelogScroll.Active = true
            local changelogLayout = Instance.new("UIListLayout")
            changelogLayout.Padding = UDim.new(0,5)
            changelogLayout.SortOrder = Enum.SortOrder.LayoutOrder
            changelogLayout.Parent = changelogScroll

            local function refreshChangelogCanvas()
                changelogScroll.CanvasSize = UDim2.new(0,0,0,changelogLayout.AbsoluteContentSize.Y + 6)
            end
            changelogLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshChangelogCanvas)

            local entries = type(hopts.Changelog) == "table" and hopts.Changelog or {}
            local entryCount = 0
            local function showChangelogDetails(heading,description)
                local existing = root:FindFirstChild("ChangelogDetailOverlay")
                if existing then existing:Destroy() end

                local overlay = Instance.new("Frame")
                overlay.Name = "ChangelogDetailOverlay"
                overlay.Size = UDim2.new(1,0,1,0)
                overlay.BackgroundColor3 = Color3.new(0,0,0)
                overlay.BackgroundTransparency = 0.35
                overlay.BorderSizePixel = 0
                overlay.ZIndex = 80
                overlay.Parent = root

                local panel = Instance.new("Frame")
                panel.Name = "ChangelogDetailPanel"
                panel.Size = UDim2.new(0.82,0,0.78,0)
                panel.Position = UDim2.new(0.5,0,0.5,0)
                panel.AnchorPoint = Vector2.new(0.5,0.5)
                panel.BackgroundColor3 = C.panel
                panel.BorderSizePixel = 0
                panel.ClipsDescendants = true
                panel.ZIndex = 81
                panel.Parent = overlay
                corner(10,panel)
                stroke(C.border,1,panel)

                local accent = Instance.new("Frame")
                accent.Size = UDim2.new(1,-24,0,2)
                accent.Position = UDim2.new(0,12,0,0)
                accent.BackgroundColor3 = ACCENTS[1]
                accent.BorderSizePixel = 0
                accent.ZIndex = 82
                accent.Parent = panel
                corner(1,accent)

                newTxt({Parent=panel,Text="CHANGELOG",Font=GB,Size=10,Color=C.dim,Sz=UDim2.new(1,-64,0,14),Pos=UDim2.new(0,14,0,12)})
                local close = Instance.new("TextButton")
                close.Name = "CloseChangelog"
                close.Size = UDim2.new(0,28,0,28)
                close.Position = UDim2.new(1,-40,0,7)
                close.BackgroundColor3 = C.pHdr
                close.BorderSizePixel = 0
                close.AutoButtonColor = false
                close.Text = "×"
                close.Font = GB
                close.TextSize = 20
                close.TextColor3 = C.txt
                close.ZIndex = 83
                close.Parent = panel
                corner(7,close)
                close.MouseButton1Click:Connect(function() overlay:Destroy() end)

                local title = newTxt({Parent=panel,Text=heading,Font=GB,Size=16,Sz=UDim2.new(1,-28,0,24),Pos=UDim2.new(0,14,0,38)})
                title.ZIndex = 82
                local divider = Instance.new("Frame")
                divider.Size = UDim2.new(1,-28,0,1)
                divider.Position = UDim2.new(0,14,0,70)
                divider.BackgroundColor3 = C.border
                divider.BorderSizePixel = 0
                divider.ZIndex = 82
                divider.Parent = panel

                local detailScroll = Instance.new("ScrollingFrame")
                detailScroll.Name = "ChangelogFullText"
                detailScroll.Size = UDim2.new(1,-28,1,-88)
                detailScroll.Position = UDim2.new(0,14,0,80)
                detailScroll.BackgroundTransparency = 1
                detailScroll.BorderSizePixel = 0
                detailScroll.ScrollBarThickness = 3
                detailScroll.ScrollBarImageColor3 = ACCENTS[1]
                detailScroll.ScrollingDirection = Enum.ScrollingDirection.Y
                detailScroll.Active = true
                detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
                detailScroll.CanvasSize = UDim2.new(0,0,0,0)
                detailScroll.ZIndex = 82
                detailScroll.Parent = panel

                local fullDescription = description ~= "" and description or "No description provided."
                local fullText = newTxt({Parent=detailScroll,Text=fullDescription,Font=GM,Size=12,Color=C.txt,Wrap=true,Sz=UDim2.new(1,-8,0,0),Pos=UDim2.new(0,4,0,2)})
                fullText.AutomaticSize = Enum.AutomaticSize.Y
                fullText.TextYAlignment = Enum.TextYAlignment.Top
                fullText.ZIndex = 83
            end

            for index,entry in ipairs(entries) do
                local heading,description
                if type(entry) == "table" then
                    heading = entry.Title or entry.Version or entry.Name
                    description = entry.Description or entry.Desc or entry.Text
                else
                    description = entry
                end
                heading = heading ~= nil and tostring(heading) or nil
                description = description ~= nil and tostring(description) or ""
                if (heading and heading ~= "") or description ~= "" then
                    entryCount = entryCount + 1
                    local titleText = heading and heading ~= "" and heading or "UPDATE"
                    local item = Instance.new("Frame")
                    item.Name = "ChangelogEntry"
                    item.Size = UDim2.new(1,-4,0,34)
                    item.BackgroundColor3 = C.pHdr
                    item.BorderSizePixel = 0
                    item.LayoutOrder = index
                    item.Parent = changelogScroll
                    corner(6,item)

                    local marker = Instance.new("Frame")
                    marker.Size = UDim2.new(0,2,1,-10)
                    marker.Position = UDim2.new(0,0,0,5)
                    marker.BackgroundColor3 = ACCENTS[1]
                    marker.BorderSizePixel = 0
                    marker.Parent = item
                    corner(1,marker)

                    newTxt({Parent=item,Text=titleText,Font=GB,Size=9,Color=ACCENTS[1],Sz=UDim2.new(1,-28,0,12),Pos=UDim2.new(0,8,0,4)})
                    local descHeight = description ~= "" and fitH(description,9,GM,146,11,2) or 0
                    local preview = description
                    if #preview > 78 then preview = preview:sub(1,75) .. "..." end
                    local desc = newTxt({Parent=item,Text=preview,Font=GM,Size=9,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-28,0,descHeight),Pos=UDim2.new(0,8,0,17)})
                    desc.TextYAlignment = Enum.TextYAlignment.Top

                    local openHint = newTxt({Parent=item,Text="›",Font=GB,Size=18,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(0,16,1,0),Pos=UDim2.new(1,-20,0,0)})
                    openHint.ZIndex = 2
                    local click = Instance.new("TextButton")
                    click.Name = "OpenChangelogEntry"
                    click.Size = UDim2.new(1,0,1,0)
                    click.BackgroundTransparency = 1
                    click.BorderSizePixel = 0
                    click.AutoButtonColor = false
                    click.Text = ""
                    click.ZIndex = 5
                    click.Parent = item
                    click.MouseButton1Click:Connect(function()
                        showChangelogDetails(titleText,description)
                    end)
                    item.Size = UDim2.new(1,-4,0,math.max(34,17 + math.min(descHeight,22) + 5))
                end
            end
            if entryCount == 0 then
                newTxt({Parent=changelogScroll,Text="No updates yet.",Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-8,0,18),Pos=UDim2.new(0,4,0,4)})
            end
            refreshChangelogCanvas()

            if hopts.Tier or #SUB.order > 0 then
                local chip = Instance.new("TextButton")
                chip.AutoButtonColor = false
                chip.Text = ""
                chip.BackgroundColor3 = C.badgeHi
                chip.BorderSizePixel = 0
                chip.Parent = changelogFrame
                corner(7,chip)
                local chipStroke = stroke(ACCENTS[1],1,chip)
                local chipTxt = newTxt({Parent=chip,Text="",Font=GB,Size=10,Color=ACCENTS[1],XAlign=Enum.TextXAlignment.Center})
                local timeTxt = newTxt({Parent=changelogFrame,Text="",Font=GM,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,86,0,10),Pos=UDim2.new(1,-94,0,25)})
                changelogScroll.Position = UDim2.new(0,6,0,48)
                changelogScroll.Size = UDim2.new(1,-12,1,-54)
                local function refreshChip()
                    local info = JL:GetSubscriptionInfo()
                    local label = info.Subscribed and info.Name or (hopts.Tier or info.Name)
                    local custom = info.Tier and info.Tier.Color
                    local col = custom or ACCENTS[1]
                    local w = math.max(58, math.min(86, math.floor(TextService:GetTextSize(label, 10, GB, Vector2.new(120,20)).X) + 18))
                    chip.Size = UDim2.new(0,w,0,18)
                    chip.Position = UDim2.new(0,8,0,25)
                    chipTxt.Text = label
                    chipTxt.TextColor3 = col
                    chipStroke.Color = col
                    chipTxt:SetAttribute("JLNoRepaint", custom ~= nil)
                    chipStroke:SetAttribute("JLNoRepaint", custom ~= nil)
                    timeTxt.Text = info.TimeText or ""
                end
                refreshChip()
                JL:OnTierChanged(refreshChip)
                chip.MouseButton1Click:Connect(function()
                    if #SUB.order > 0 then JL:OpenSubscriptions() end
                end)
            end
        end
        do
            local h = 60
            local card = newCard(h)
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,-16,1,-16); row.Position = UDim2.new(0,8,0,8); row.BackgroundTransparency = 1; row.Parent = card
            local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6); rl.SortOrder = Enum.SortOrder.LayoutOrder; rl.Parent = row
            local statW = 96
            local function stat(order,label,initial)
                local box = Instance.new("Frame"); box.Size = UDim2.new(0,statW,1,0); box.BackgroundTransparency = 1; box.LayoutOrder = order; box.Parent = row
                newTxt({Parent=box,Text=label,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14),Pos=UDim2.new(0,0,0,2)})
                local v = newTxt({Parent=box,Text=initial,Font=GB,Size=16,Sz=UDim2.new(1,0,0,22),Pos=UDim2.new(0,0,0,18)})
                return v
            end
            local playersV = stat(1, "Players", "0/0")
            local fpsV = stat(2, "FPS", "60")
            homeFpsLabel = fpsV
            local pingV = stat(3, "Ping", "0ms")
            local sessV = stat(4, "Session", "0m 0s")
            local execV, friendsV
            if hopts.GetExecs then execV = stat(5, "Execs", "0") end
            if hopts.ShowFriends then friendsV = stat(hopts.GetExecs and 6 or 5, "Friends", "...") end
            local function refreshPlayers()
                local max = game.Players.MaxPlayers
                playersV.Text = #game.Players:GetPlayers() .. "/" .. max
            end
            refreshPlayers()
            keep(game.Players.PlayerAdded:Connect(refreshPlayers)); keep(game.Players.PlayerRemoving:Connect(refreshPlayers))
            trackedSpawn(function()
                while root.Parent do
                    local ok,ping = pcall(function() return LP:GetNetworkPing() end)
                    if ok then pingV.Text = math.round(ping * 1000) .. "ms" end
                    local secs = math.floor(tick() - hubStartTick)
                    sessV.Text = math.floor(secs / 60) .. "m " .. (secs % 60) .. "s"
                    if execV and hopts.GetExecs then local ok2,n = pcall(hopts.GetExecs); if ok2 and n then execV.Text = tostring(n) end end
                    task.wait(1)
                end
            end)
            if friendsV then
                trackedSpawn(function()
                    local ok,list2 = pcall(function()
                        local pages = LP:GetFriendsOnline(50)
                        return pages:GetCurrentPage()
                    end)
                    friendsV.Text = (ok and list2) and tostring(#list2) or "0"
                end)
            end
        end
        do
            local h = 164
            local card = newCard(h)
            local icon = Instance.new("ImageLabel"); icon.Size = UDim2.new(0,56,0,56); icon.Position = UDim2.new(0,12,0,12); icon.BackgroundColor3 = C.pHdr; icon.BorderSizePixel = 0; icon.Parent = card; corner(10,icon)
            icon:SetAttribute("JLNoRepaint", true)
            local nameL = newTxt({Parent=card,Text="Loading...",Font=GB,Size=14,Sz=UDim2.new(1,-84,0,18),Pos=UDim2.new(0,78,0,12)})
            local byL = newTxt({Parent=card,Text="",Font=GM,Size=11,Color=C.dim,Sz=UDim2.new(1,-84,0,14),Pos=UDim2.new(0,78,0,32)})
            trackedSpawn(function()
                local ok,info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId, Enum.InfoType.Asset) end)
                if ok and info then
                    nameL.Text = info.Name or "Unknown"
                    byL.Text = "by " .. ((info.Creator and info.Creator.Name) or "Unknown")
                    if info.IconImageAssetId and info.IconImageAssetId ~= 0 then icon.Image = "rbxassetid://" .. info.IconImageAssetId end
                end
            end)
            newTxt({Parent=card,Text="Job ID  " .. game.JobId,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-84,0,14),Pos=UDim2.new(0,78,0,50)})
            newTxt({Parent=card,Text="Place " .. game.PlaceId .. "   Universe " .. game.GameId,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-24,0,14),Pos=UDim2.new(0,12,0,74)})
            local function mkBtnRow(y)
                local row = Instance.new("Frame"); row.Size = UDim2.new(1,-24,0,26); row.Position = UDim2.new(0,12,0,y); row.BackgroundTransparency = 1; row.Parent = card
                local rl = Instance.new("UIListLayout"); rl.FillDirection = Enum.FillDirection.Horizontal; rl.Padding = UDim.new(0,6); rl.SortOrder = Enum.SortOrder.LayoutOrder; rl.Parent = row
                return row
            end
            local btnRow1, btnRow2 = mkBtnRow(98), mkBtnRow(130)
            local function actBtn(parentRow,order2,label,w,cb)
                local b = Instance.new("TextButton"); b.Size = UDim2.new(0,w,0,26); b.LayoutOrder = order2; b.BackgroundColor3 = C.btnBg; b.BorderSizePixel = 0; b.AutoButtonColor = false
                b.Text = label; b.Font = GB; b.TextSize = 11; b.TextColor3 = C.txt; b.Parent = parentRow; corner(6,b); stroke(C.border,1,b)
                b.MouseEnter:Connect(function() if touchLast() then return end tw(b,{BackgroundColor3 = C.btnHov},.1) end)
                b.MouseLeave:Connect(function() tw(b,{BackgroundColor3 = C.btnBg},.1) end)
                b.MouseButton1Click:Connect(cb)
                return b
            end
            actBtn(btnRow1,1,"Rejoin",70,function() pcall(function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end) end)
            actBtn(btnRow1,2,"Server Hop",90,function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end) end)
            actBtn(btnRow1,3,"Copy Job ID",96,function()
                if setclipboard then setclipboard(game.JobId); JL:Notify({Title="Copied",Desc="Job ID copied",Type="Success",Duration=3})
                else JL:Notify({Title="Copy",Desc="Clipboard unsupported",Type="Error",Duration=3}) end
            end)
            actBtn(btnRow1,4,"Copy Universe",108,function()
                if setclipboard then setclipboard(tostring(game.GameId)); JL:Notify({Title="Copied",Desc="Universe ID copied",Type="Success",Duration=3})
                else JL:Notify({Title="Copy",Desc="Clipboard unsupported",Type="Error",Duration=3}) end
            end)
            actBtn(btnRow2,1,"Join Lowest Server",132,function()
                joinLowestServer(game.PlaceId, function(msg) JL:Notify({Title="Server Hop",Desc=msg,Type="Error",Duration=4}) end)
            end)
            actBtn(btnRow2,2,"Sub-Places",100,function()
                openSubPlaces(game.GameId)
            end)
        end
        if hopts.DiscordInvite or hopts.Website then
            local h = 60
            local card = newCard(h)
            local half = hopts.DiscordInvite and hopts.Website
            if hopts.DiscordInvite then
                local w = half and 0.5 or 1
                local box = Instance.new("Frame"); box.Size = UDim2.new(w,half and -20 or -16,1,-16); box.Position = UDim2.new(0,8,0,8); box.BackgroundTransparency = 1; box.Parent = card
                mkIcon(box, "message-circle", 20, 5).Position = UDim2.new(0,0,0,2)
                newTxt({Parent=box,Text="Join the community",Font=GB,Size=12,Sz=UDim2.new(1,-30,0,16),Pos=UDim2.new(0,28,0,0)})
                local sub = newTxt({Parent=box,Text=hopts.DiscordInvite,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-30,0,14),Pos=UDim2.new(0,28,0,18)})
                fetchDiscordInfo(hopts.DiscordInvite, function(info)
                    local bits = {}
                    if info.members then bits[#bits+1] = info.members .. " members" end
                    if info.online then bits[#bits+1] = info.online .. " online" end
                    if #bits > 0 then sub.Text = table.concat(bits, " · ") end
                end)
                local cbtn = Instance.new("TextButton"); cbtn.Size = UDim2.new(0,70,0,24); cbtn.Position = UDim2.new(1,-70,0,4); cbtn.BackgroundColor3 = C.btnBg; cbtn.BorderSizePixel = 0; cbtn.Text = "Copy"; cbtn.Font = GB; cbtn.TextSize = 11; cbtn.TextColor3 = C.txt; cbtn.Parent = box; corner(6,cbtn); stroke(C.border,1,cbtn)
                cbtn.MouseButton1Click:Connect(function()
                    if setclipboard then setclipboard(hopts.DiscordInvite); JL:Notify({Title="Copied",Desc="Invite link copied",Type="Success",Duration=3}) end
                end)
            end
            if hopts.Website then
                local box = Instance.new("Frame"); box.Size = UDim2.new(half and 0.5 or 1,half and -20 or -16,1,-16); box.Position = UDim2.new(half and 0.5 or 0,half and 12 or 8,0,8); box.BackgroundTransparency = 1; box.Parent = card
                mkIcon(box, "globe", 20, 5).Position = UDim2.new(0,0,0,2)
                newTxt({Parent=box,Text="Website",Font=GB,Size=12,Sz=UDim2.new(1,-30,0,16),Pos=UDim2.new(0,28,0,0)})
                newTxt({Parent=box,Text=hopts.Website,Font=GM,Size=10,Color=C.dim,Sz=UDim2.new(1,-30,0,14),Pos=UDim2.new(0,28,0,18)})
                local cbtn = Instance.new("TextButton"); cbtn.Size = UDim2.new(0,70,0,24); cbtn.Position = UDim2.new(1,-70,0,4); cbtn.BackgroundColor3 = C.btnBg; cbtn.BorderSizePixel = 0; cbtn.Text = "Copy"; cbtn.Font = GB; cbtn.TextSize = 11; cbtn.TextColor3 = C.txt; cbtn.Parent = box; corner(6,cbtn); stroke(C.border,1,cbtn)
                cbtn.MouseButton1Click:Connect(function()
                    if setclipboard then setclipboard(hopts.Website); JL:Notify({Title="Copied",Desc="Website link copied",Type="Success",Duration=3}) end
                end)
            end
        end
        if hopts.Announcement then
            local h = fitH(hopts.Announcement, 11, GM, IW - 48, 40, 16)
            local card = newCard(h)
            newTxt({Parent=card,Text=hopts.Announcement,Font=GM,Size=11,Color=C.dim,Wrap=true,Sz=UDim2.new(1,-24,1,-16),Pos=UDim2.new(0,12,0,8)})
        end
        return T
    end
    shared._JLActive = {alive = true, destroy = destroyHub}
    JL._destroyActive = destroyHub
    if JL._perfEnabled then
        warn("[JustLib Perf] Window build: " .. string.format("%.3f s", os.clock() - windowBuildStarted))
    end
    return Win
end
function JL:Unload()
    if self._destroyActive then self._destroyActive()
    else
        _disposed = true
        cleanupResources()
        for i = #_conns, 1, -1 do pcall(function() _conns[i]:Disconnect() end); _conns[i] = nil end
        local hooks = {}
        for i,fn in ipairs(self._unloadHooks or {}) do hooks[i] = fn end
        for i = #(self._unloadHooks or {}), 1, -1 do self._unloadHooks[i] = nil end
        for _,fn in ipairs(hooks) do pcall(fn) end
    end
end
function JL:Cleanup() return self:Unload() end
return JL
