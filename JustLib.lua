-- ══════════════════════════════════════════════════════════
--  JustLib  v1.0  ·  by Just Neos
--  loadstring(game:HttpGet("url"))()
-- ══════════════════════════════════════════════════════════
local JL = {}; JL.Flags = {}
local TS=game:GetService("TweenService"); local UIS=game:GetService("UserInputService")
local HTTP=game:GetService("HttpService"); local LP=game:GetService("Players").LocalPlayer
local PG=LP:WaitForChild("PlayerGui"); local RunSvc=game:GetService("RunService")

-- ── Palette ───────────────────────────────────────────────
local C={
    panel=Color3.fromRGB(17,17,23), pHdr=Color3.fromRGB(23,23,31),
    border=Color3.fromRGB(42,42,58), txt=Color3.fromRGB(222,222,235),
    dim=Color3.fromRGB(108,108,132), togOn=Color3.fromRGB(72,198,112),
    togOff=Color3.fromRGB(48,48,66), slTrack=Color3.fromRGB(36,36,50),
    btnBg=Color3.fromRGB(26,26,38), btnHov=Color3.fromRGB(40,40,56),
    sidebar=Color3.fromRGB(12,12,17), fpsGrn=Color3.fromRGB(72,214,92),
    badge=Color3.fromRGB(14,14,20), badgeHi=Color3.fromRGB(18,28,50),
    chkBg=Color3.fromRGB(36,36,50), divLine=Color3.fromRGB(42,42,58),
    input=Color3.fromRGB(20,20,30),
}
local ACCENTS={
    Color3.fromRGB(82,152,255), Color3.fromRGB(148,92,255),
    Color3.fromRGB(72,198,138), Color3.fromRGB(255,132,72),
    Color3.fromRGB(255,72,108), Color3.fromRGB(72,208,208),
}
local _ai=0; local function nxAc() _ai=_ai+1; return ACCENTS[((_ai-1)%#ACCENTS)+1] end

-- ── Helpers ───────────────────────────────────────────────
local function tw(o,p,t,s,d) TS:Create(o,TweenInfo.new(t or .2,s or Enum.EasingStyle.Quart,d or Enum.EasingDirection.Out),p):Play() end
local function corner(r,p) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=p end
local function stroke(col,t,p) local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=t; s.Parent=p; return s end
local function pad(l,r,t,b,p) local u=Instance.new("UIPadding"); u.PaddingLeft=UDim.new(0,l); u.PaddingRight=UDim.new(0,r); u.PaddingTop=UDim.new(0,t); u.PaddingBottom=UDim.new(0,b); u.Parent=p end
local function kp(p) if p<=0 then return UDim2.new(0,0,0.5,-4) elseif p>=1 then return UDim2.new(1,-8,0.5,-4) else return UDim2.new(p,-4,0.5,-4) end end
local function newTxt(props)
    local l=Instance.new("TextLabel"); l.BackgroundTransparency=1
    l.Font=props.Font or Enum.Font.Gotham; l.TextSize=props.Size or 11
    l.TextColor3=props.Color or C.txt; l.Text=props.Text or ""
    l.TextXAlignment=props.XAlign or Enum.TextXAlignment.Left
    l.TextTruncate=Enum.TextTruncate.AtEnd; l.ZIndex=props.Z or 17
    if props.Wrap then l.TextWrapped=true; l.TextTruncate=Enum.TextTruncate.None end
    l.Size=props.Sz or UDim2.new(1,0,1,0); l.Position=props.Pos or UDim2.new(0,0,0,0)
    l.Parent=props.Parent; return l
end
local function draggable(handle,frame,onTap)
    local down,moved,ds,sp=false,false,nil,nil
    handle.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then down=true; moved=false; ds=Vector2.new(i.Position.X,i.Position.Y); sp=frame.Position end end)
    UIS.InputChanged:Connect(function(i) if not down then return end; if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end; local d=Vector2.new(i.Position.X,i.Position.Y)-ds; if d.Magnitude>8 then moved=true end; if moved then frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if not down then return end; if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then down=false; if not moved and onTap then onTap() end end end)
end
local function mkIcon(parent,icon,sz,z)
    sz=sz or 20; z=z or 13; local s=tostring(icon)
    if s:match("^rbxassetid://") or s:match("^%d+$") then
        local img=Instance.new("ImageLabel"); img.Size=UDim2.new(0,sz,0,sz); img.BackgroundTransparency=1
        img.Image=s:match("^%d+$") and ("rbxassetid://"..s) or s; img.ZIndex=z; img.Parent=parent; return img
    else
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(0,sz,0,sz); l.BackgroundTransparency=1
        l.Text=s; l.TextScaled=true; l.Font=Enum.Font.GothamBold; l.TextColor3=C.txt; l.ZIndex=z; l.Parent=parent; return l
    end
end

-- ── Config ────────────────────────────────────────────────
local _cfgFile=nil; local _cfgData={}
local function cfgLoad(name)
    _cfgFile=name..".json"
    if readfile then local ok,r=pcall(readfile,_cfgFile); if ok and r and r~="" then local ok2,d=pcall(HTTP.JSONDecode,HTTP,r); if ok2 and type(d)=="table" then _cfgData=d end end end
end
local function cfgSave()
    if _cfgFile and writefile then pcall(writefile,_cfgFile,HTTP:JSONEncode(_cfgData)) end
end
local function cfgSet(flag,val) if flag and _cfgFile then _cfgData[flag]=val; JL.Flags[flag]=val; cfgSave() end end
local function cfgGet(flag,default) if flag and _cfgData[flag]~=nil then JL.Flags[flag]=_cfgData[flag]; return _cfgData[flag] end; if flag then JL.Flags[flag]=default end; return default end

-- ── Notifications (NoyaUI embedded) ──────────────────────
do
    local CoreGui=game:GetService("CoreGui")
    shared._JLNotifs=shared._JLNotifs or {}
    local active=shared._JLNotifs
    local function updPos()
        for i,n in ipairs(active) do if n and n.f then tw(n.f,{Position=UDim2.new(0,550,0,165-((#active-i)*72.5))},.6,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut) end end
    end
    function JL:Notify(cfg2)
        local title=cfg2.Title or "JustLib"; local desc=cfg2.Desc or ""; local dur=cfg2.Duration or 5; local typ=cfg2.Type or "Info"
        local col=Color3.fromRGB(158,198,255); local ico="rbxassetid://70718918423383"
        if typ=="Error" then col=Color3.fromRGB(255,82,82); ico="rbxassetid://113114601887005"
        elseif typ=="Success" then col=Color3.fromRGB(145,255,128); ico="rbxassetid://18567015051"
        elseif typ=="Warn" then col=Color3.fromRGB(255,225,117); ico="rbxassetid://14863060512" end
        local sg2=Instance.new("ScreenGui"); sg2.Name="JLNotif"; sg2.Parent=CoreGui; sg2.ClipToDeviceSafeArea=false; sg2.ResetOnSpawn=false
        local f=Instance.new("Frame"); f.BorderSizePixel=0; f.BackgroundColor3=Color3.fromRGB(0,0,0); f.Size=UDim2.new(0,200,0,55); f.Position=UDim2.new(1,50,0,165); f.Parent=sg2; corner(8,f)
        local te=Instance.new("Frame"); te.ZIndex=0; te.BorderSizePixel=0; te.BackgroundColor3=col; te.Size=UDim2.new(0,20,0,55); te.Position=UDim2.new(0,-3,0,0); te.Parent=f; corner(8,te)
        local ti=Instance.new("ImageLabel"); ti.BorderSizePixel=0; ti.BackgroundTransparency=1; ti.ImageColor3=col; ti.Image=ico; ti.Size=UDim2.new(0,15,0,15); ti.Position=UDim2.new(0,3,0,3); ti.Parent=f
        newTxt({Parent=f,Text=title,Font=Enum.Font.GothamBold,Size=14,Color=Color3.new(1,1,1),Sz=UDim2.new(0,170,0,20),Pos=UDim2.new(0,22,0,2),Z=5})
        local td=newTxt({Parent=f,Text=desc,Size=10,Color=Color3.new(1,1,1),Sz=UDim2.new(0,180,0,28),Pos=UDim2.new(0,10,0,22),Z=5,Wrap=true}); td.TextTransparency=0.25
        local db=Instance.new("Frame"); db.BorderSizePixel=0; db.BackgroundColor3=col; db.Size=UDim2.new(0,180,0,3); db.Position=UDim2.new(0,10,0,50); db.BackgroundTransparency=0.2; db.Parent=f; corner(2,db)
        local cb=Instance.new("TextButton"); cb.BorderSizePixel=0; cb.BackgroundTransparency=1; cb.TextSize=14; cb.Font=Enum.Font.GothamBold; cb.TextColor3=Color3.new(1,1,1); cb.Size=UDim2.new(0,20,0,20); cb.Position=UDim2.new(1,-22,0,2); cb.Text="x"; cb.Parent=f
        local nd={f=f,g=sg2}; table.insert(active,nd); local closing=false
        local barTw=TS:Create(db,TweenInfo.new(dur,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,0,3)})
        local function close() if closing then return end; closing=true; if barTw.PlaybackState==Enum.PlaybackState.Playing then barTw:Cancel() end; for i,v in ipairs(active) do if v==nd then table.remove(active,i); break end end; updPos(); if f and f.Parent then local t2=TS:Create(f,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position=UDim2.new(1,50,0,f.Position.Y.Offset)}); t2:Play(); t2.Completed:Connect(function() sg2:Destroy() end) end end
        cb.MouseButton1Click:Connect(close)
        local tY=165-((#active-1)*72.5); local tIn=TS:Create(f,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{Position=UDim2.new(0,550,0,tY)}); tIn:Play(); updPos()
        tIn.Completed:Connect(function() if not closing then barTw:Play() end end); barTw.Completed:Connect(function() if not closing then close() end end)
    end
end

-- ── Color Picker modal ────────────────────────────────────
local _cpSg=nil  -- shared ScreenGui for color picker
local function ensureCpSg(sg)
    if not _cpSg then
        _cpSg=Instance.new("Frame"); _cpSg.Size=UDim2.new(1,0,1,0); _cpSg.BackgroundColor3=Color3.new(0,0,0)
        _cpSg.BackgroundTransparency=0.5; _cpSg.ZIndex=200; _cpSg.Visible=false; _cpSg.Parent=sg
    end
    return _cpSg
end

local function openColorPicker(sg,currentColor,callback)
    local bd=ensureCpSg(sg); bd.Visible=true
    local h,s,v=Color3.toHSV(currentColor)
    -- Clear old card
    for _,c in ipairs(bd:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local card=Instance.new("Frame"); card.Size=UDim2.new(0,240,0,280); card.Position=UDim2.new(0.5,-120,0.5,-140)
    card.BackgroundColor3=C.panel; card.BorderSizePixel=0; card.ZIndex=201; card.Parent=bd; corner(12,card); stroke(C.border,1,card)
    -- Header
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,34); hdr.BackgroundColor3=C.pHdr; hdr.BorderSizePixel=0; hdr.ZIndex=202; hdr.Parent=card; corner(12,hdr)
    local hdrFix=Instance.new("Frame"); hdrFix.Size=UDim2.new(1,0,0.5,0); hdrFix.Position=UDim2.new(0,0,0.5,0); hdrFix.BackgroundColor3=C.pHdr; hdrFix.BorderSizePixel=0; hdrFix.ZIndex=202; hdrFix.Parent=hdr
    newTxt({Parent=hdr,Text="Color Picker",Font=Enum.Font.GothamBold,Size=13,Color=C.txt,Sz=UDim2.new(1,-44,1,0),Pos=UDim2.new(0,12,0,0),Z=203})
    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,24,0,24); closeBtn.Position=UDim2.new(1,-30,0.5,-12); closeBtn.BackgroundColor3=Color3.fromRGB(215,70,70); closeBtn.Text="✕"; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=12; closeBtn.TextColor3=Color3.new(1,1,1); closeBtn.ZIndex=203; closeBtn.Parent=hdr; corner(7,closeBtn)
    closeBtn.MouseButton1Click:Connect(function() bd.Visible=false end)
    draggable(hdr,card)
    -- Preview
    local preview=Instance.new("Frame"); preview.Size=UDim2.new(0,28,0,20); preview.Position=UDim2.new(1,-66,0.5,-10); preview.BackgroundColor3=currentColor; preview.BorderSizePixel=0; preview.ZIndex=203; preview.Parent=hdr; corner(5,preview); stroke(C.border,1,preview)
    local function refreshPreview() preview.BackgroundColor3=Color3.fromHSV(h,s,v) end
    -- SV square (140x120)
    local svBg=Instance.new("Frame"); svBg.Size=UDim2.new(1,-20,0,120); svBg.Position=UDim2.new(0,10,0,44); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); svBg.BorderSizePixel=0; svBg.ZIndex=202; svBg.ClipsDescendants=true; svBg.Parent=card; corner(4,svBg)
    -- White→transparent (saturation)
    local svSat=Instance.new("Frame"); svSat.Size=UDim2.new(1,0,1,0); svSat.BackgroundColor3=Color3.new(1,1,1); svSat.BorderSizePixel=0; svSat.ZIndex=203; svSat.Parent=svBg; corner(4,svSat)
    local svSatG=Instance.new("UIGradient"); svSatG.Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(1,1,1)); svSatG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); svSatG.Rotation=0; svSatG.Parent=svSat
    -- Transparent→black (value)
    local svVal=Instance.new("Frame"); svVal.Size=UDim2.new(1,0,1,0); svVal.BackgroundColor3=Color3.new(0,0,0); svVal.BorderSizePixel=0; svVal.ZIndex=204; svVal.Parent=svBg; corner(4,svVal)
    local svValG=Instance.new("UIGradient"); svValG.Color=ColorSequence.new(Color3.new(0,0,0),Color3.new(0,0,0)); svValG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); svValG.Rotation=90; svValG.Parent=svVal
    -- SV cursor
    local svCursor=Instance.new("Frame"); svCursor.Size=UDim2.new(0,10,0,10); svCursor.BackgroundColor3=Color3.new(1,1,1); svCursor.BorderSizePixel=0; svCursor.ZIndex=205; corner(5,svCursor)
    -- No UIStroke — it caused a static corner artifact that didn't update color
    local function updateSvCursor() svCursor.Position=UDim2.new(s,-5,1-v,-5); svCursor.Parent=svBg end
    updateSvCursor()
    -- SV drag
    local svHit=Instance.new("TextButton"); svHit.Size=UDim2.new(1,0,1,0); svHit.BackgroundTransparency=1; svHit.Text=""; svHit.ZIndex=206; svHit.Parent=svBg
    local svDragging=false
    local function updateSV(inp) local ap=svBg.AbsolutePosition; local as=svBg.AbsoluteSize; s=math.clamp((inp.Position.X-ap.X)/as.X,0,1); v=math.clamp(1-(inp.Position.Y-ap.Y)/as.Y,0,1); updateSvCursor(); refreshPreview(); if callback then callback(Color3.fromHSV(h,s,v)) end end
    svHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=true; updateSV(i) end end)
    UIS.InputChanged:Connect(function(i) if svDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then updateSV(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=false end end)
    -- Hue bar
    local hueBar=Instance.new("Frame"); hueBar.Size=UDim2.new(1,-20,0,12); hueBar.Position=UDim2.new(0,10,0,172); hueBar.BackgroundColor3=Color3.new(1,1,1); hueBar.BorderSizePixel=0; hueBar.ZIndex=202; hueBar.Parent=card; corner(4,hueBar)
    local hueG=Instance.new("UIGradient"); hueG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}); hueG.Parent=hueBar
    local hueCursor=Instance.new("Frame"); hueCursor.Size=UDim2.new(0,8,1,4); hueCursor.Position=UDim2.new(h,-4,0,-2); hueCursor.BackgroundColor3=Color3.new(1,1,1); hueCursor.BorderSizePixel=0; hueCursor.ZIndex=203; hueCursor.Parent=hueBar; corner(2,hueCursor); stroke(Color3.new(0,0,0),1,hueCursor)
    local hueHit=Instance.new("TextButton"); hueHit.Size=UDim2.new(1,0,1,0); hueHit.BackgroundTransparency=1; hueHit.Text=""; hueHit.ZIndex=204; hueHit.Parent=hueBar
    local hueDragging=false
    local function updateHue(inp) local ap=hueBar.AbsolutePosition; local as=hueBar.AbsoluteSize; h=math.clamp((inp.Position.X-ap.X)/as.X,0,1); hueCursor.Position=UDim2.new(h,-4,0,-2); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); refreshPreview(); if callback then callback(Color3.fromHSV(h,s,v)) end end
    hueHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDragging=true; updateHue(i) end end)
    UIS.InputChanged:Connect(function(i) if hueDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then updateHue(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDragging=false end end)
    -- RGB sliders
    local function mkRgbSlider(label2,yPos,getVal,setVal)
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,-20,0,22); row.Position=UDim2.new(0,10,0,yPos); row.BackgroundTransparency=1; row.ZIndex=202; row.Parent=card
        newTxt({Parent=row,Text=label2,Size=10,Color=C.dim,Sz=UDim2.new(0,12,1,0),Pos=UDim2.new(0,0,0,0),Z=203})
        local valLbl=newTxt({Parent=row,Text=tostring(math.round(getVal()*255)),Font=Enum.Font.GothamBold,Size=10,Color=C.txt,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,26,1,0),Pos=UDim2.new(1,-26,0,0),Z=203})
        local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(1,-44,0,6); tBg.Position=UDim2.new(0,16,0.5,-3); tBg.BackgroundColor3=C.slTrack; tBg.BorderSizePixel=0; tBg.ZIndex=203; tBg.Parent=row; corner(3,tBg)
        local curVal=getVal(); local fill=Instance.new("Frame"); fill.Size=UDim2.new(curVal,0,1,0); fill.BackgroundColor3=C.txt; fill.BorderSizePixel=0; fill.ZIndex=204; fill.Parent=tBg; corner(3,fill)
        local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,8,0,8); kn.Position=kp(curVal); kn.BackgroundColor3=Color3.new(1,1,1); kn.BorderSizePixel=0; kn.ZIndex=205; kn.Parent=tBg; corner(4,kn)
        local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,0,18); hit.Position=UDim2.new(0,0,0.5,-9); hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=206; hit.Parent=tBg
        local sliding=false
        hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
        UIS.InputChanged:Connect(function(i) if not sliding then return end; if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end; local ap=tBg.AbsolutePosition; local as=tBg.AbsoluteSize; local p=math.clamp((i.Position.X-ap.X)/as.X,0,1); setVal(p); fill.Size=UDim2.new(p,0,1,0); kn.Position=kp(p); valLbl.Text=tostring(math.round(p*255)); local col2=Color3.fromHSV(h,s,v); h,s,v=Color3.toHSV(Color3.fromRGB(Color3.fromHSV(h,s,v).R*255,Color3.fromHSV(h,s,v).G*255,Color3.fromHSV(h,s,v).B*255)); refreshPreview(); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); updateSvCursor(); if callback then callback(Color3.fromHSV(h,s,v)) end end)
        return function(newP) fill.Size=UDim2.new(newP,0,1,0); kn.Position=kp(newP); valLbl.Text=tostring(math.round(newP*255)) end
    end
    local r2,g2,b2=Color3.fromHSV(h,s,v).R,Color3.fromHSV(h,s,v).G,Color3.fromHSV(h,s,v).B
    mkRgbSlider("R",194,function() return r2 end,function(p) r2=p end)
    mkRgbSlider("G",218,function() return g2 end,function(p) g2=p end)
    mkRgbSlider("B",242,function() return b2 end,function(p) b2=p end)
    -- close on backdrop click
    bd.InputBegan:Connect(function(i) if (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then local pos=Vector2.new(i.Position.X,i.Position.Y); local cp=card.AbsolutePosition; local cs=card.AbsoluteSize; if pos.X<cp.X or pos.X>cp.X+cs.X or pos.Y<cp.Y or pos.Y>cp.Y+cs.Y then bd.Visible=false end end end)
end

-- ── Section builder ───────────────────────────────────────
local function makeSection(parentFrame,title,parentSg,layoutOrder)
    local ac=nxAc()
    local panel=Instance.new("Frame"); panel.Size=UDim2.new(1,0,0,36); panel.BackgroundColor3=C.panel; panel.BorderSizePixel=0; panel.ZIndex=13; panel.LayoutOrder=layoutOrder or 1; panel.ClipsDescendants=true; panel.Parent=parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    -- Accent strip
    local ast=Instance.new("Frame"); ast.Size=UDim2.new(0,3,1,-20); ast.Position=UDim2.new(0,0,0,10); ast.BackgroundColor3=ac; ast.BorderSizePixel=0; ast.ZIndex=14; ast.Parent=panel; corner(2,ast)
    -- Header
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,34); hdr.BackgroundColor3=C.pHdr; hdr.BorderSizePixel=0; hdr.ZIndex=14; hdr.Parent=panel; corner(10,hdr)
    local hdrFix=Instance.new("Frame"); hdrFix.Size=UDim2.new(1,0,0.5,0); hdrFix.Position=UDim2.new(0,0,0.5,0); hdrFix.BackgroundColor3=C.pHdr; hdrFix.BorderSizePixel=0; hdrFix.ZIndex=14; hdrFix.Parent=hdr
    local cb=Instance.new("TextButton"); cb.Size=UDim2.new(0,22,0,22); cb.Position=UDim2.new(1,-28,0.5,-11); cb.BackgroundColor3=Color3.fromRGB(32,32,46); cb.Text="↓"; cb.Font=Enum.Font.GothamBold; cb.TextSize=11; cb.TextColor3=C.dim; cb.ZIndex=15; cb.Parent=hdr; corner(6,cb)
    newTxt({Parent=hdr,Text=title,Font=Enum.Font.GothamBold,Size=12,Color=C.txt,Sz=UDim2.new(1,-36,1,0),Pos=UDim2.new(0,10,0,0),Z=15})
    -- Items container (auto-height)
    local content=Instance.new("Frame"); content.Size=UDim2.new(1,-6,0,0); content.Position=UDim2.new(0,3,0,36); content.BackgroundTransparency=1; content.ZIndex=14; content.ClipsDescendants=true; content.Parent=panel
    local list=Instance.new("UIListLayout"); list.FillDirection=Enum.FillDirection.Vertical; list.Padding=UDim.new(0,4); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=content; pad(3,3,4,4,content)
    local collapsed=false; local storedH=0
    local function resizePanel()
        local h=list.AbsoluteContentSize.Y+14
        content.Size=UDim2.new(1,-6,0,h); panel.Size=UDim2.new(1,0,0,36+h)
        if not collapsed then storedH=h end
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
    -- Collapse
    cb.MouseButton1Click:Connect(function()
        collapsed=not collapsed; cb.Text=collapsed and "↑" or "↓"
        if collapsed then
            tw(panel,{Size=UDim2.new(1,0,0,38)},.18)
            task.delay(.19,function() if collapsed then content.Visible=false end end)
        else
            content.Visible=true
            tw(panel,{Size=UDim2.new(1,0,0,36+storedH)},.18)
        end
    end)
    local iOrd=0
    local Sec={}
    local function newRow(h2) iOrd=iOrd+1; local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,h2); r.BackgroundTransparency=1; r.ZIndex=16; r.LayoutOrder=iOrd; r.Parent=content; return r end
    -- Toggle
    function Sec:Toggle(opts)
        local state=cfgGet(opts.Flag,opts.Default or false)
        local row=newRow(28)
        newTxt({Parent=row,Text=opts.Name or "Toggle",Sz=UDim2.new(1,-42,1,0),Z=17})
        local track=Instance.new("Frame"); track.Size=UDim2.new(0,34,0,18); track.Position=UDim2.new(1,-36,0.5,-9); track.BackgroundColor3=state and C.togOn or C.togOff; track.BorderSizePixel=0; track.ZIndex=17; track.Parent=row; corner(9,track)
        local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.Position=UDim2.new(0,state and 18 or 2,0.5,-7); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; knob.ZIndex=18; knob.Parent=track; corner(7,knob)
        local tb=Instance.new("TextButton"); tb.Size=UDim2.new(1,0,1,0); tb.BackgroundTransparency=1; tb.Text=""; tb.ZIndex=19; tb.Parent=track
        tb.MouseButton1Click:Connect(function() state=not state; tw(track,{BackgroundColor3=state and C.togOn or C.togOff},.15); tw(knob,{Position=UDim2.new(0,state and 18 or 2,0.5,-7)},.15); cfgSet(opts.Flag,state); if opts.Callback then pcall(opts.Callback,state) end end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,state) end
        return {Set=function(_,v) state=v; track.BackgroundColor3=v and C.togOn or C.togOff; knob.Position=UDim2.new(0,v and 18 or 2,0.5,-7); cfgSet(opts.Flag,v) end, Get=function() return state end}
    end
    -- Slider
    function Sec:Slider(opts)
        local val=cfgGet(opts.Flag,opts.Default or opts.Min or 0); local vmin=opts.Min or 0; local vmax=opts.Max or 100
        local row=newRow(40)
        local top=Instance.new("Frame"); top.Size=UDim2.new(1,0,0,16); top.BackgroundTransparency=1; top.ZIndex=17; top.Parent=row
        newTxt({Parent=top,Text=opts.Name or "Slider",Sz=UDim2.new(0.62,0,1,0),Z=17})
        local valLbl=newTxt({Parent=top,Text=tostring(val),Font=Enum.Font.GothamBold,Color=ac,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.38,0,1,0),Pos=UDim2.new(0.62,0,0,0),Z=17})
        local tBg=Instance.new("Frame"); tBg.Size=UDim2.new(1,0,0,6); tBg.Position=UDim2.new(0,0,0,22); tBg.BackgroundColor3=C.slTrack; tBg.BorderSizePixel=0; tBg.ZIndex=17; tBg.Parent=row; corner(3,tBg)
        local pct=(val-vmin)/(vmax-vmin)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=ac; fill.BorderSizePixel=0; fill.ZIndex=18; fill.Parent=tBg; corner(3,fill)
        local kn=Instance.new("Frame"); kn.Size=UDim2.new(0,10,0,10); kn.Position=kp(pct); kn.BackgroundColor3=Color3.new(1,1,1); kn.BorderSizePixel=0; kn.ZIndex=19; kn.Parent=tBg; corner(5,kn)
        local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,0,22); hit.Position=UDim2.new(0,0,0.5,-11); hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=20; hit.Parent=tBg
        local sliding=false
        hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
        UIS.InputChanged:Connect(function(i) if not sliding then return end; if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end; local ap=tBg.AbsolutePosition; local as=tBg.AbsoluteSize; local p=math.clamp((i.Position.X-ap.X)/as.X,0,1); val=math.round(vmin+p*(vmax-vmin)); valLbl.Text=tostring(val); fill.Size=UDim2.new(p,0,1,0); kn.Position=kp(p); cfgSet(opts.Flag,val); if opts.Callback then pcall(opts.Callback,val) end end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,val) end
        return {Set=function(_,v) val=v; local p=(v-vmin)/(vmax-vmin); fill.Size=UDim2.new(p,0,1,0); kn.Position=kp(p); valLbl.Text=tostring(v); cfgSet(opts.Flag,v) end, Get=function() return val end}
    end
    -- Button
    function Sec:Button(opts)
        local row=newRow(28)
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,-2,1,-4); btn.Position=UDim2.new(0,1,0,2); btn.BackgroundColor3=C.btnBg; btn.Text=opts.Name or "Button"; btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.TextColor3=C.txt; btn.TextTruncate=Enum.TextTruncate.AtEnd; btn.ZIndex=17; btn.Parent=row; corner(7,btn); stroke(C.border,1,btn)
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.btnHov},.1) end); btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.btnBg},.1) end)
        btn.MouseButton1Click:Connect(function() tw(btn,{BackgroundColor3=ac},.06); task.delay(.14,function() tw(btn,{BackgroundColor3=C.btnBg},.12) end); if opts.Callback then pcall(opts.Callback) end end)
        return btn
    end
    -- Input
    function Sec:Input(opts)
        local h2=opts.MultiLine and 58 or 34; local row=newRow(h2)
        newTxt({Parent=row,Text=opts.Name or "Input",Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14),Z=17})
        local boxH=h2-18
        local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-2,0,boxH); box.Position=UDim2.new(0,1,0,16); box.BackgroundColor3=C.input; box.PlaceholderText=opts.Placeholder or ""; box.Text=cfgGet(opts.Flag,"") or ""; box.Font=Enum.Font.Gotham; box.TextSize=11; box.TextColor3=C.txt; box.ClearTextOnFocus=false; box.MultiLine=opts.MultiLine or false; box.TextWrapped=opts.MultiLine or false; box.ZIndex=17; box.Parent=row; corner(6,box); pad(6,6,opts.MultiLine and 3 or 0,opts.MultiLine and 3 or 0,box)
        box.FocusLost:Connect(function(enter) if enter or opts.OnChange then cfgSet(opts.Flag,box.Text); if opts.Callback then pcall(opts.Callback,box.Text) end end end)
        if opts.OnChange then box:GetPropertyChangedSignal("Text"):Connect(function() cfgSet(opts.Flag,box.Text); if opts.Callback then pcall(opts.Callback,box.Text) end end) end
        return {Get=function() return box.Text end, Set=function(_,v) box.Text=v end}
    end
    -- Dropdown
    function Sec:Dropdown(opts)
        local options=opts.Options or {}; local multi=opts.MultiSelect; local maxSel=opts.MaxSelect or 1
        local selected={}
        local saved=cfgGet(opts.Flag,opts.Default)
        if saved then if type(saved)=="table" then for _,v in ipairs(saved) do selected[v]=true end elseif saved~="" then selected[saved]=true end end
        local HDR=28; local OPT=26; local TOTAL=#options*OPT; local expanded=false
        local dRow=newRow(HDR)
        -- ClipsDescendants OFF so expanded list isn't clipped by panel
        local dw=Instance.new("Frame"); dw.Size=UDim2.new(1,0,0,HDR); dw.BackgroundColor3=C.btnBg; dw.BorderSizePixel=0; dw.ZIndex=17; dw.ClipsDescendants=false; dw.Parent=dRow; corner(7,dw); stroke(C.border,1,dw)
        -- Inner clip frame for header only (so border/bg looks right)
        local hBtn=Instance.new("TextButton"); hBtn.Size=UDim2.new(1,0,0,HDR); hBtn.BackgroundTransparency=1; hBtn.Text=""; hBtn.ZIndex=18; hBtn.Parent=dw
        local hLbl=newTxt({Parent=dw,Text="▾  "..(opts.Name or "Dropdown"),Font=Enum.Font.GothamBold,Color=C.txt,Sz=UDim2.new(1,-8,0,HDR),Pos=UDim2.new(0,8,0,0),Z=19}); hLbl.TextYAlignment=Enum.TextYAlignment.Center
        -- Options frame (bg panel so it draws on top of sibling sections)
        local oFr=Instance.new("Frame"); oFr.Size=UDim2.new(1,0,0,TOTAL); oFr.Position=UDim2.new(0,0,0,HDR); oFr.BackgroundColor3=C.panel; oFr.BorderSizePixel=0; oFr.ZIndex=80; oFr.Visible=false; oFr.Parent=dw; corner(7,oFr); stroke(C.border,1,oFr)
        -- Stores per-option refs for safe clearing
        local optRefs={}
        for i,optName in ipairs(options) do
            local oRow=Instance.new("Frame"); oRow.Size=UDim2.new(1,0,0,OPT); oRow.Position=UDim2.new(0,0,0,(i-1)*OPT); oRow.BackgroundTransparency=1; oRow.ZIndex=81; oRow.Parent=oFr
            local chk=Instance.new("Frame"); chk.Size=UDim2.new(0,13,0,13); chk.Position=UDim2.new(0,8,0.5,-6); chk.BackgroundColor3=selected[optName] and C.togOn or C.chkBg; chk.BorderSizePixel=0; chk.ZIndex=82; chk.Parent=oRow; corner(3,chk)
            -- FIX: center checkmark text
            local chkM=Instance.new("TextLabel"); chkM.Size=UDim2.new(1,0,1,0); chkM.BackgroundTransparency=1; chkM.Text=selected[optName] and "✓" or ""; chkM.Font=Enum.Font.GothamBold; chkM.TextSize=9; chkM.TextColor3=Color3.new(1,1,1); chkM.TextXAlignment=Enum.TextXAlignment.Center; chkM.TextYAlignment=Enum.TextYAlignment.Center; chkM.ZIndex=83; chkM.Parent=chk
            newTxt({Parent=oRow,Text=optName,Sz=UDim2.new(1,-28,1,0),Pos=UDim2.new(0,26,0,0),Z=82})
            local rB=Instance.new("TextButton"); rB.Size=UDim2.new(1,0,1,0); rB.BackgroundTransparency=1; rB.Text=""; rB.ZIndex=83; rB.Parent=oRow
            -- Store refs so we can safely reset without touching name labels
            optRefs[optName]={chk=chk,chkM=chkM}
            rB.MouseButton1Click:Connect(function()
                if multi then
                    local cnt=0; for _ in pairs(selected) do cnt=cnt+1 end
                    if selected[optName] then selected[optName]=nil; tw(chk,{BackgroundColor3=C.chkBg},.1); chkM.Text=""
                    elseif cnt<maxSel then selected[optName]=true; tw(chk,{BackgroundColor3=ac},.1); chkM.Text="✓" else return end
                    cfgSet(opts.Flag,selected)
                    if opts.Callback then local sel={}; for k in pairs(selected) do table.insert(sel,k) end; pcall(opts.Callback,sel) end
                else
                    -- FIX: clear via stored refs, never touches name TextLabel
                    for _,ref in pairs(optRefs) do tw(ref.chk,{BackgroundColor3=C.chkBg},.1); ref.chkM.Text="" end
                    selected={}; selected[optName]=true; tw(chk,{BackgroundColor3=ac},.1); chkM.Text="✓"
                    cfgSet(opts.Flag,optName); if opts.Callback then pcall(opts.Callback,optName) end
                end
            end)
        end
        hBtn.MouseButton1Click:Connect(function()
            expanded=not expanded; hLbl.Text=(expanded and "▴" or "▾").."  "..(opts.Name or "Dropdown")
            oFr.Visible=expanded
            -- Resize dRow so UIListLayout in content resizes panel correctly
            dRow.Size=UDim2.new(1,0,0,expanded and HDR+TOTAL or HDR)
            dw.Size=UDim2.new(1,0,0,HDR)  -- dw stays header height, oFr overflows
            -- Lift panel ZIndex to render above siblings when open
            panel.ZIndex=expanded and 50 or 13
        end)
        return {Get=function() if multi then local sel={}; for k in pairs(selected) do table.insert(sel,k) end; return sel else for k in pairs(selected) do return k end end end}
    end
    -- ColorPicker
    function Sec:ColorPicker(opts)
        local curColor=cfgGet(opts.Flag,opts.Default or Color3.fromRGB(255,255,255))
        if type(curColor)=="table" then curColor=Color3.fromRGB(curColor[1] or 255,curColor[2] or 255,curColor[3] or 255) end
        local row=newRow(28)
        newTxt({Parent=row,Text=opts.Name or "Color",Sz=UDim2.new(1,-64,1,0),Z=17})
        local preview2=Instance.new("Frame"); preview2.Size=UDim2.new(0,34,0,20); preview2.Position=UDim2.new(1,-54,0.5,-10); preview2.BackgroundColor3=curColor; preview2.BorderSizePixel=0; preview2.ZIndex=17; preview2.Parent=row; corner(5,preview2); stroke(C.border,1,preview2)
        local openBtn=Instance.new("TextButton"); openBtn.Size=UDim2.new(0,16,0,20); openBtn.Position=UDim2.new(1,-18,0.5,-10); openBtn.BackgroundColor3=C.btnBg; openBtn.Text="⋯"; openBtn.Font=Enum.Font.GothamBold; openBtn.TextSize=10; openBtn.TextColor3=C.txt; openBtn.ZIndex=17; openBtn.Parent=row; corner(5,openBtn)
        openBtn.MouseButton1Click:Connect(function()
            openColorPicker(parentSg,curColor,function(col) curColor=col; preview2.BackgroundColor3=col; local t={math.round(col.R*255),math.round(col.G*255),math.round(col.B*255)}; cfgSet(opts.Flag,t); if opts.Callback then pcall(opts.Callback,col) end end)
        end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,curColor) end
        return {Get=function() return curColor end, Set=function(_,v) curColor=v; preview2.BackgroundColor3=v end}
    end
    -- Label
    function Sec:Label(opts)
        local row=newRow(18)
        newTxt({Parent=row,Text=opts.Text or "",Size=10,Color=opts.Color or C.dim,Sz=UDim2.new(1,0,1,0),Z=17})
    end
    -- Divider
    function Sec:Divider(opts)
        local row=newRow(18); local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0); line.BackgroundColor3=C.divLine; line.BorderSizePixel=0; line.ZIndex=17; line.Parent=row
        if opts and opts.Label then local LW=math.min(#opts.Label*7+12,90); local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,LW,0,13); bg.Position=UDim2.new(0.5,-LW/2,0.5,-6); bg.BackgroundColor3=C.panel; bg.BorderSizePixel=0; bg.ZIndex=17; bg.Parent=row; corner(3,bg); newTxt({Parent=bg,Text=opts.Label,Font=Enum.Font.GothamBold,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=18}) end
    end
    return Sec
end

-- ── Tab & Window ──────────────────────────────────────────
function JL:Window(opts)
    opts=opts or {}
    if PG:FindFirstChild("JustLib") then PG.JustLib:Destroy() end
    if opts.Config then cfgLoad(opts.Config) end
    local sg=Instance.new("ScreenGui"); sg.Name="JustLib"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=999
    local ok=pcall(function() sg.Parent=game:GetService("CoreGui") end); if not ok then sg.Parent=PG end
    -- Badge
    local BPOS={top=UDim2.new(0.5,-79,0,14),center=UDim2.new(0.5,-79,0.5,-15),bottom=UDim2.new(0.5,-79,1,-44)}
    local badge2=Instance.new("Frame"); badge2.Size=UDim2.new(0,158,0,30); badge2.Position=BPOS.top; badge2.BackgroundColor3=C.badge; badge2.BorderSizePixel=0; badge2.ZIndex=60; badge2.Parent=sg; corner(8,badge2); stroke(C.border,1,badge2)
    -- badge icon
    if opts.Icon then local ic=mkIcon(badge2,opts.Icon,18,61); ic.Size=UDim2.new(0,18,0,18); ic.Position=UDim2.new(0,8,0.5,-9) end
    local offX=opts.Icon and 32 or 10
    local badgeTitle=newTxt({Parent=badge2,Text=opts.Title or "JustLib",Font=Enum.Font.GothamBold,Size=12,Sz=UDim2.new(0,78,1,0),Pos=UDim2.new(0,offX,0,0),Z=61})
    local divF=Instance.new("Frame"); divF.Size=UDim2.new(0,1,0,16); divF.Position=UDim2.new(0,100,0.5,-8); divF.BackgroundColor3=C.border; divF.BorderSizePixel=0; divF.ZIndex=61; divF.Parent=badge2
    local fpsL=newTxt({Parent=badge2,Text="60 FPS",Font=Enum.Font.GothamBold,Size=12,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,46,1,0),Pos=UDim2.new(0,104,0,0),Z=61})
    do local _lt=tick(); local _fr=0; RunSvc.Heartbeat:Connect(function() _fr=_fr+1; local n=tick(); if n-_lt>=0.5 then fpsL.Text=math.round(_fr/(n-_lt)).." FPS"; _fr=0; _lt=n end end) end
    local badgeTap=Instance.new("TextButton"); badgeTap.Size=UDim2.new(1,0,1,0); badgeTap.BackgroundTransparency=1; badgeTap.Text=""; badgeTap.ZIndex=62; badgeTap.Parent=badge2
    -- Window
    local WW,WH=530,370
    local win=Instance.new("Frame"); win.Size=UDim2.new(0,WW,0,WH); win.Position=UDim2.new(0.5,-WW/2,0.5,-WH/2); win.BackgroundTransparency=1; win.BorderSizePixel=0; win.ZIndex=10; win.Visible=false; win.ClipsDescendants=false; win.Parent=sg
    -- Sidebar
    local SBW=38; local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,SBW,0,0); sidebar.Position=UDim2.new(0,0,0.5,0); sidebar.BackgroundColor3=C.sidebar; sidebar.BorderSizePixel=0; sidebar.ZIndex=12; sidebar.Parent=win; corner(10,sidebar); stroke(C.border,1,sidebar)
    local sbList=Instance.new("UIListLayout"); sbList.FillDirection=Enum.FillDirection.Vertical; sbList.HorizontalAlignment=Enum.HorizontalAlignment.Center; sbList.VerticalAlignment=Enum.VerticalAlignment.Center; sbList.Padding=UDim.new(0,8); sbList.Parent=sidebar; pad(0,0,10,10,sidebar)
    sbList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h=sbList.AbsoluteContentSize.Y+20; sidebar.Size=UDim2.new(0,SBW,0,h); sidebar.Position=UDim2.new(0,0,0.5,-h/2)
    end)
    -- Content area
    local content=Instance.new("Frame"); content.Size=UDim2.new(1,-(SBW+10),1,0); content.Position=UDim2.new(0,SBW+10,0,0); content.BackgroundTransparency=1; content.ZIndex=11; content.ClipsDescendants=true; content.Parent=win
    local tabFrames={}; local tabBtns={}; local activeTabId=nil; local _tabCount=0
    local function switchToTab(id)
        local prevId=activeTabId
        -- Direction: new tab index > current → slide left, else slide right
        local goRight=(prevId ~= nil and id > prevId)
        for tid,fr in pairs(tabFrames) do
            if tid==id then
                fr.Position=UDim2.new(goRight and 1 or -1, 0, 0, 0)
                fr.Visible=true
                tw(fr,{Position=UDim2.new(0,0,0,0)},.22,Enum.EasingStyle.Quart)
            elseif prevId and tid==prevId then
                tw(fr,{Position=UDim2.new(goRight and -1 or 1, 0, 0, 0)},.22,Enum.EasingStyle.Quart)
                task.delay(.23, function() fr.Visible=false; fr.Position=UDim2.new(0,0,0,0) end)
            else
                fr.Visible=false
            end
        end
        for tid,btn in pairs(tabBtns) do
            if tid==id then btn.BackgroundColor3=Color3.fromRGB(18,36,62); local ic=btn:FindFirstChildOfClass("TextLabel") or btn:FindFirstChildOfClass("ImageLabel"); if ic then if ic:IsA("TextLabel") then ic.TextColor3=ACCENTS[1] else ic.ImageColor3=ACCENTS[1] end end
            else btn.BackgroundColor3=Color3.fromRGB(24,24,34); local ic=btn:FindFirstChildOfClass("TextLabel") or btn:FindFirstChildOfClass("ImageLabel"); if ic then if ic:IsA("TextLabel") then ic.TextColor3=C.dim else ic.ImageColor3=C.dim end end end
        end
        activeTabId=id
    end
    -- Open/close
    local isOpen=false
    local function openW() isOpen=true; win.Visible=true; local s=.82; win.Size=UDim2.new(0,WW*s,0,WH*s); win.Position=UDim2.new(0.5,-(WW*s)/2,0.5,-(WH*s)/2); tw(win,{Size=UDim2.new(0,WW,0,WH),Position=UDim2.new(0.5,-WW/2,0.5,-WH/2)},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out); tw(badge2,{BackgroundColor3=C.badgeHi},.15); if activeTabId then switchToTab(activeTabId) end end
    local function closeW() isOpen=false; local s=.82; tw(win,{Size=UDim2.new(0,WW*s,0,WH*s),Position=UDim2.new(0.5,-(WW*s)/2,0.5,-(WH*s)/2)},.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In); task.delay(.19,function() if not isOpen then win.Visible=false end end); tw(badge2,{BackgroundColor3=C.badge},.15) end
    draggable(badgeTap,badge2,function() if isOpen then closeW() else openW() end end)
    draggable(sidebar,win)
    local hotkey=opts.Hotkey or Enum.KeyCode.RightShift
    UIS.InputBegan:Connect(function(i,gp) if gp then return end; if i.KeyCode==hotkey then if isOpen then closeW() else openW() end end end)
    local Win={}
    -- :Tab() → creates a new tab
    function Win:Tab(topts)
        topts=topts or {}; local typ=topts.Type or "Grid"; _tabCount=_tabCount+1; local id=_tabCount
        -- Sidebar button
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,26,0,26); btn.BackgroundColor3=Color3.fromRGB(24,24,34); btn.Text=""; btn.ZIndex=13; btn.Parent=sidebar; corner(6,btn)
        local ic=mkIcon(btn,topts.Icon or "◼",16,14); ic.Position=UDim2.new(0.5,-8,0.5,-8); ic.Size=UDim2.new(0,16,0,16)
        tabBtns[id]=btn
        -- Content frame
        local tabFrame=Instance.new("Frame"); tabFrame.Size=UDim2.new(1,0,1,0); tabFrame.Position=UDim2.new(0,0,0,0); tabFrame.BackgroundTransparency=1; tabFrame.ZIndex=12; tabFrame.Visible=false; tabFrame.Parent=content
        tabFrames[id]=tabFrame
        btn.MouseButton1Click:Connect(function() switchToTab(id) end)
        if not activeTabId then activeTabId=id; tabFrame.Visible=true; btn.BackgroundColor3=Color3.fromRGB(18,36,62) end
        local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=ACCENTS[1]; scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.ZIndex=12; scroll.Parent=tabFrame; pad(0,2,6,8,scroll)
        local Tab={}
        if typ=="Grid" then
            -- 3-column grid
            local CW=math.floor(((WW-SBW-10-2)-2*8)/3)
            local colCon=Instance.new("Frame"); colCon.Size=UDim2.new(1,0,0,0); colCon.BackgroundTransparency=1; colCon.ZIndex=12; colCon.Parent=scroll
            local colF={}; local colL={}
            for i,n in ipairs({"left","mid","right"}) do
                local col=Instance.new("Frame"); col.Size=UDim2.new(0,CW,0,0); col.Position=UDim2.new(0,(i-1)*(CW+8),0,0); col.BackgroundTransparency=1; col.ZIndex=12; col.Parent=colCon; colF[n]=col
                local L=Instance.new("UIListLayout"); L.FillDirection=Enum.FillDirection.Vertical; L.Padding=UDim.new(0,8); L.SortOrder=Enum.SortOrder.LayoutOrder; L.Parent=col; colL[n]=L
                L:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    local mH=0; for _,nm in ipairs({"left","mid","right"}) do local h2=colL[nm].AbsoluteContentSize.Y; colF[nm].Size=UDim2.new(0,CW,0,h2); mH=math.max(mH,h2) end
                    colCon.Size=UDim2.new(1,0,0,mH+14); scroll.CanvasSize=UDim2.new(0,0,0,mH+14)
                end)
            end
            local _pOrd={left=0,mid=0,right=0}
            function Tab:Section(sopts)
                sopts=sopts or {}; local col=sopts.Column or "left"; _pOrd[col]=_pOrd[col]+1
                -- No wrapper frame: makeSection creates its own panel directly in the column
                return makeSection(colF[col],sopts.Title or "Section",sg,_pOrd[col])
            end
        else
            -- List (single column)
            local listCon=Instance.new("Frame"); listCon.Size=UDim2.new(1,0,0,0); listCon.BackgroundTransparency=1; listCon.ZIndex=12; listCon.Parent=scroll
            local listL=Instance.new("UIListLayout"); listL.FillDirection=Enum.FillDirection.Vertical; listL.Padding=UDim.new(0,8); listL.SortOrder=Enum.SortOrder.LayoutOrder; listL.Parent=listCon
            listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                listCon.Size=UDim2.new(1,0,0,listL.AbsoluteContentSize.Y+14); scroll.CanvasSize=UDim2.new(0,0,0,listL.AbsoluteContentSize.Y+14)
            end)
            local _sOrd=0
            function Tab:Section(sopts)
                sopts=sopts or {}; _sOrd=_sOrd+1
                return makeSection(listCon,sopts.Title or "Section",sg,_sOrd)
            end
        end
        return Tab
    end
    -- :Settings() → built-in settings tab (optional)
    function Win:Settings()
        if not opts.Settings and opts.Settings~=nil then return nil end
        local sTab=self:Tab({Icon="⚙",Type="List"})
        local appSec=sTab:Section({Title="Appearance"})
        -- Blur slider
        do local LT=game:GetService("Lighting")
            local function getBlur() local b=LT:FindFirstChildOfClass("BlurEffect"); if not b then b=Instance.new("BlurEffect"); b.Parent=LT end; return b end
            appSec:Slider({Name="Blur (0-100%)",Min=0,Max=100,Default=cfgGet("_blur",0),Flag="_blur",Callback=function(v) local sz=math.round(v*56/100); local b=getBlur(); b.Enabled=(sz>0); b.Size=sz end})
            task.spawn(function() while task.wait(0.5) do local v2=cfgGet("_blur",0) or 0; if v2>0 then local sz=math.round(v2*56/100); local b=getBlur(); if not b.Enabled then b.Enabled=true end; if b.Size~=sz then b.Size=sz end end end end)
        end
        appSec:Toggle({Name="Show FPS",Default=cfgGet("_showfps",true),Flag="_showfps",Callback=function(v) fpsL.Visible=v end})
        local badgeSec=sTab:Section({Title="Badge"})
        badgeSec:Button({Name="Position → Top",   Callback=function() tw(badge2,{Position=BPOS.top},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end})
        badgeSec:Button({Name="Position → Center",Callback=function() tw(badge2,{Position=BPOS.center},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end})
        badgeSec:Button({Name="Position → Bottom",Callback=function() tw(badge2,{Position=BPOS.bottom},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end})
        badgeSec:Button({Name="Close Hub",Callback=function() closeW() end})
        return sTab
    end
    return Win
end

return JL
