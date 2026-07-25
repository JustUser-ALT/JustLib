-- ══════════════════════════════════════════════════════════
--  JustLib  v1.0  ·  by Just Neos
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
local _ai=0;
local function nxAc() _ai=_ai+1; return ACCENTS[((_ai-1)%#ACCENTS)+1] end

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
        sg2.DisplayOrder=999999999
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
local _cpSg=nil
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
    for _,c in ipairs(bd:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local card=Instance.new("Frame"); card.Size=UDim2.new(0,240,0,280); card.Position=UDim2.new(0.5,-120,0.5,-140)
    card.BackgroundColor3=C.panel; card.BorderSizePixel=0; card.ZIndex=201; card.Parent=bd; corner(12,card); stroke(C.border,1,card)
    
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,34); hdr.BackgroundColor3=C.pHdr; hdr.BorderSizePixel=0; hdr.ZIndex=202; hdr.Parent=card; corner(12,hdr)
    local hdrFix=Instance.new("Frame"); hdrFix.Size=UDim2.new(1,0,0.5,0); hdrFix.Position=UDim2.new(0,0,0.5,0); hdrFix.BackgroundColor3=C.pHdr; hdrFix.BorderSizePixel=0; hdrFix.ZIndex=202; hdrFix.Parent=hdr
    newTxt({Parent=hdr,Text="Color Picker",Font=Enum.Font.GothamBold,Size=13,Color=C.txt,Sz=UDim2.new(1,-44,1,0),Pos=UDim2.new(0,12,0,0),Z=203})
    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,24,0,24); closeBtn.Position=UDim2.new(1,-30,0.5,-12); closeBtn.BackgroundColor3=Color3.fromRGB(215,70,70); closeBtn.Text="✕"; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=12; closeBtn.TextColor3=Color3.new(1,1,1); closeBtn.ZIndex=203; closeBtn.Parent=hdr; corner(7,closeBtn)
    closeBtn.MouseButton1Click:Connect(function() bd.Visible=false end)
    draggable(hdr,card)
    
    local preview=Instance.new("Frame"); preview.Size=UDim2.new(0,30,0,24); preview.Position=UDim2.new(1,-42,0.5,-12); preview.BackgroundColor3=currentColor; preview.BorderSizePixel=0; preview.ZIndex=203; preview.Parent=hdr; corner(6,preview)
    local function refreshPreview() preview.BackgroundColor3=Color3.fromHSV(h,s,v) end
    
    local svBg=Instance.new("Frame"); svBg.Size=UDim2.new(1,-20,0,120); svBg.Position=UDim2.new(0,10,0,44); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); svBg.BorderSizePixel=0; svBg.ZIndex=202; svBg.Parent=card; corner(4,svBg)
    local svSat=Instance.new("Frame"); svSat.Size=UDim2.new(1,0,1,0); svSat.BackgroundColor3=Color3.new(1,1,1); svSat.BorderSizePixel=0; svSat.ZIndex=203; svSat.Parent=svBg; corner(4,svSat)
    local svSatG=Instance.new("UIGradient"); svSatG.Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(1,1,1)); svSatG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); svSatG.Rotation=0; svSatG.Parent=svSat
    local svVal=Instance.new("Frame"); svVal.Size=UDim2.new(1,0,1,0); svVal.BackgroundColor3=Color3.new(0,0,0); svVal.BorderSizePixel=0; svVal.ZIndex=204; svVal.Parent=svBg; corner(4,svVal)
    local svValG=Instance.new("UIGradient"); svValG.Color=ColorSequence.new(Color3.new(0,0,0),Color3.new(0,0,0)); svValG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); svValG.Rotation=90; svValG.Parent=svVal
    
    local svCursor=Instance.new("Frame"); svCursor.Size=UDim2.new(0,10,0,10); svCursor.BackgroundColor3=Color3.new(1,1,1); svCursor.BorderSizePixel=0; svCursor.ZIndex=205; corner(5,svCursor)
    local function updateSvCursor() svCursor.Position=UDim2.new(s,-5,1-v,-5); svCursor.Parent=svBg end
    updateSvCursor()
    stroke(Color3.new(0,0,0),1.5,svCursor)
    
    local svHit=Instance.new("TextButton"); svHit.Size=UDim2.new(1,0,1,0); svHit.BackgroundTransparency=1; svHit.Text=""; svHit.ZIndex=206; svHit.Parent=svBg
    local svDragging=false
    local function updateSV(inp) local ap=svBg.AbsolutePosition; local as=svBg.AbsoluteSize; s=math.clamp((inp.Position.X-ap.X)/as.X,0,1); v=math.clamp(1-(inp.Position.Y-ap.Y)/as.Y,0,1); updateSvCursor(); refreshPreview(); if callback then callback(Color3.fromHSV(h,s,v)) end end
    svHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=true; updateSV(i) end end)
    UIS.InputChanged:Connect(function(i) if svDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then updateSV(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then svDragging=false end end)
    
    local hueBar=Instance.new("Frame"); hueBar.Size=UDim2.new(1,-20,0,12); hueBar.Position=UDim2.new(0,10,0,172); hueBar.BackgroundColor3=Color3.new(1,1,1); hueBar.BorderSizePixel=0; hueBar.ZIndex=202; hueBar.Parent=card; corner(4,hueBar)
    local hueG=Instance.new("UIGradient"); hueG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),ColorSequenceKeypoint.new(0.167,Color3.fromRGB(255,255,0)),ColorSequenceKeypoint.new(0.333,Color3.fromRGB(0,255,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),ColorSequenceKeypoint.new(0.667,Color3.fromRGB(0,0,255)),ColorSequenceKeypoint.new(0.833,Color3.fromRGB(255,0,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))}); hueG.Parent=hueBar
    local hueCursor=Instance.new("Frame"); hueCursor.Size=UDim2.new(0,8,1,4); hueCursor.Position=UDim2.new(h,-4,0,-2); hueCursor.BackgroundColor3=Color3.new(1,1,1); hueCursor.BorderSizePixel=0; hueCursor.ZIndex=203; hueCursor.Parent=hueBar; corner(2,hueCursor); stroke(Color3.new(0,0,0),1,hueCursor)
    local hueHit=Instance.new("TextButton"); hueHit.Size=UDim2.new(1,0,1,0); hueHit.BackgroundTransparency=1; hueHit.Text=""; hueHit.ZIndex=204; hueHit.Parent=hueBar
    local hueDragging=false
    local function updateHue(inp) local ap=hueBar.AbsolutePosition; local as=hueBar.AbsoluteSize; h=math.clamp((inp.Position.X-ap.X)/as.X,0,1); hueCursor.Position=UDim2.new(h,-4,0,-2); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); refreshPreview(); if callback then callback(Color3.fromHSV(h,s,v)) end end
    hueHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDragging=true; updateHue(i) end end)
    UIS.InputChanged:Connect(function(i) if hueDragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then updateHue(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then hueDragging=false end end)
    
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
    bd.InputBegan:Connect(function(i) if (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then local pos=Vector2.new(i.Position.X,i.Position.Y); local cp=card.AbsolutePosition; local cs=card.AbsoluteSize; if pos.X<cp.X or pos.X>cp.X+cs.X or pos.Y<cp.Y or pos.Y>cp.Y+cs.Y then bd.Visible=false end end end)
end

-- ── Section builder (Minimal Minimalistic Grid Style) ────────────────
local function makeSection(parentFrame,title,parentSg)
    local ac=nxAc()
    local panel=Instance.new("Frame")
    panel.Size=UDim2.new(1,0,0,28)
    panel.BackgroundColor3=C.panel
    panel.BorderSizePixel=0
    panel.ZIndex=13
    panel.ClipsDescendants=true
    panel.Parent=parentFrame
    corner(8,panel)
    stroke(C.border,1,panel)

    local hdr=Instance.new("Frame")
    hdr.Size=UDim2.new(1,0,0,28)
    hdr.BackgroundTransparency=1
    hdr.ZIndex=14
    hdr.Parent=panel

    newTxt({Parent=hdr,Text=title,Font=Enum.Font.GothamBold,Size=11,Color=ac,Sz=UDim2.new(1,-30,1,0),Pos=UDim2.new(0,8,0,0),Z=15})

    local cb=Instance.new("TextButton")
    cb.Size=UDim2.new(0,18,0,18)
    cb.Position=UDim2.new(1,-22,0.5,-9)
    cb.BackgroundTransparency=1
    cb.Text="↓"
    cb.Font=Enum.Font.GothamBold
    cb.TextSize=10
    cb.TextColor3=C.dim
    cb.ZIndex=15
    cb.Parent=hdr

    local content=Instance.new("Frame")
    content.Size=UDim2.new(1,-12,0,0)
    content.Position=UDim2.new(0,6,0,28)
    content.BackgroundTransparency=1
    content.ZIndex=14
    content.ClipsDescendants=true
    content.Parent=panel

    local list=Instance.new("UIListLayout")
    list.FillDirection=Enum.FillDirection.Vertical
    list.Padding=UDim.new(0,4)
    list.SortOrder=Enum.SortOrder.LayoutOrder
    list.Parent=content
    pad(0,0,2,6,content)

    local function resizePanel()
        local h=list.AbsoluteContentSize.Y+8
        content.Size=UDim2.new(1,-12,0,h)
        panel.Size=UDim2.new(1,0,0,28+h)
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)

    local collapsed=false
    local lastH=0
    cb.MouseButton1Click:Connect(function()
        collapsed=not collapsed
        cb.Text=collapsed and "↑" or "↓"
        if collapsed then
            lastH=list.AbsoluteContentSize.Y+8
            tw(panel,{Size=UDim2.new(1,0,0,28)},.18)
            task.delay(.18,function() if collapsed then content.Visible=false end end)
        else
            content.Visible=true
            tw(panel,{Size=UDim2.new(1,0,0,28+lastH)},.18)
        end
    end)

    local iOrd=0
    local Sec={}
    local function newRow(h2)
        iOrd=iOrd+1
        local r=Instance.new("Frame")
        r.Size=UDim2.new(1,0,0,h2)
        r.BackgroundTransparency=1
        r.ZIndex=16
        r.LayoutOrder=iOrd
        r.Parent=content
        return r
    end

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
        local hit=Instance.new("TextButton"); hit.Size=UDim2.new(1,0,0,18); hit.Position=UDim2.new(0,0,0.5,-9); hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=20; hit.Parent=tBg
        local sliding=false
        local function upd(i)
            local ap=tBg.AbsolutePosition; local as=tBg.AbsoluteSize
            local p=math.clamp((i.Position.X-ap.X)/as.X,0,1)
            val=math.round(vmin+p*(vmax-vmin))
            fill.Size=UDim2.new(p,0,1,0); kn.Position=kp(p); valLbl.Text=tostring(val)
            cfgSet(opts.Flag,val)
            if opts.Callback then pcall(opts.Callback,val) end
        end
        hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true; upd(i) end end)
        UIS.InputChanged:Connect(function(i) if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,val) end
        return {Set=function(_,v) val=v; local p2=(v-vmin)/(vmax-vmin); fill.Size=UDim2.new(p2,0,1,0); kn.Position=kp(p2); valLbl.Text=tostring(v); cfgSet(opts.Flag,v) end, Get=function() return val end}
    end

    -- Button
    function Sec:Button(opts)
        local row=newRow(28)
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundColor3=C.btnBg; btn.BorderSizePixel=0; btn.Text=opts.Name or "Button"; btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.TextColor3=C.txt; btn.TextTruncate=Enum.TextTruncate.AtEnd; btn.ZIndex=17; btn.Parent=row; corner(7,btn); stroke(C.border,1,btn)
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.btnHov},.1) end)
        btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.btnBg},.1) end)
        btn.MouseButton1Click:Connect(function() tw(btn,{BackgroundColor3=ac},.06); task.delay(.14,function() tw(btn,{BackgroundColor3=C.btnBg},.12) end); if opts.Callback then pcall(opts.Callback) end end)
        return btn
    end

    -- Input
    function Sec:Input(opts)
        local h2=opts.MultiLine and 58 or 34
        local row=newRow(h2)
        newTxt({Parent=row,Text=opts.Name or "Input",Size=10,Color=C.dim,Sz=UDim2.new(1,0,0,14),Z=17})
        local boxH=h2-18
        local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-2,0,boxH); box.Position=UDim2.new(0,1,0,16); box.BackgroundColor3=C.input; box.PlaceholderText=opts.Placeholder or ""; box.Text=cfgGet(opts.Flag,"") or ""; box.Font=Enum.Font.Gotham; box.TextSize=11; box.TextColor3=C.txt; box.ClearTextOnFocus=false; box.MultiLine=opts.MultiLine or false; box.TextWrapped=opts.MultiLine or false; box.ZIndex=17; box.Parent=row; corner(6,box); stroke(C.border,1,box); pad(6,6,0,0,box)
        box.FocusLost:Connect(function(e) cfgSet(opts.Flag,box.Text); if opts.Callback then pcall(opts.Callback,box.Text,e) end end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,box.Text,true) end
        return {Set=function(_,v) box.Text=v; cfgSet(opts.Flag,v) end, Get=function() return box.Text end}
    end

    -- Dropdown
    function Sec:Dropdown(opts)
        local items=opts.Options or {}; local sel=cfgGet(opts.Flag,opts.Default or items[1] or "")
        local isOpen=false; local rowH=28
        local row=newRow(rowH)
        newTxt({Parent=row,Text=opts.Name or "Dropdown",Sz=UDim2.new(0.48,0,0,28),Z=17})
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0.5,0,0,24); btn.Position=UDim2.new(0.5,0,0,2); btn.BackgroundColor3=C.btnBg; btn.BorderSizePixel=0; btn.Text=""; btn.ZIndex=17; btn.Parent=row; corner(6,btn); stroke(C.border,1,btn)
        local selLbl=newTxt({Parent=btn,Text=sel,Font=Enum.Font.GothamBold,Size=10,Color=C.txt,Sz=UDim2.new(1,-18,1,0),Pos=UDim2.new(0,6,0,0),Z=18})
        local arrow=newTxt({Parent=btn,Text="▼",Size=8,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,12,1,0),Pos=UDim2.new(1,-14,0,0),Z=18})
        local dropF=Instance.new("Frame"); dropF.Size=UDim2.new(0.5,0,0,0); dropF.Position=UDim2.new(0.5,0,0,28); dropF.BackgroundColor3=C.panel; dropF.BorderSizePixel=0; dropF.ZIndex=30; dropF.ClipsDescendants=true; dropF.Visible=false; dropF.Parent=row; corner(6,dropF); stroke(C.border,1,dropF)
        local dList=Instance.new("UIListLayout"); dList.FillDirection=Enum.FillDirection.Vertical; dList.SortOrder=Enum.SortOrder.LayoutOrder; dList.Parent=dropF
        local function rebuild()
            for _,c in ipairs(dropF:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            for i,opt in ipairs(items) do
                local ob=Instance.new("TextButton"); ob.Size=UDim2.new(1,0,0,22); ob.BackgroundColor3=(opt==sel) and C.btnHov or C.panel; ob.BorderSizePixel=0; ob.Text=opt; ob.Font=Enum.Font.Gotham; ob.TextSize=10; ob.TextColor3=(opt==sel) and ac or C.txt; ob.ZIndex=31; ob.LayoutOrder=i; ob.Parent=dropF
                ob.MouseButton1Click:Connect(function()
                    sel=opt; selLbl.Text=opt; isOpen=false; arrow.Text="▼"; dropF.Visible=false; row.Size=UDim2.new(1,0,0,28); resizePanel(); cfgSet(opts.Flag,sel)
                    if opts.Callback then pcall(opts.Callback,sel) end
                end)
            end
        end
        rebuild()
        btn.MouseButton1Click:Connect(function()
            isOpen=not isOpen; arrow.Text=isOpen and "▲" or "▼"; dropF.Visible=isOpen
            if isOpen then local h2=math.min(#items*22,110); dropF.Size=UDim2.new(0.5,0,0,h2); row.Size=UDim2.new(1,0,0,28+h2) else row.Size=UDim2.new(1,0,0,28) end
            resizePanel()
        end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,sel) end
        return {Set=function(_,v) sel=v; selLbl.Text=v; cfgSet(opts.Flag,v) end, Refresh=function(_,newOpts) items=newOpts or {}; rebuild() end}
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
            openColorPicker(parentSg,curColor,function(col)
                curColor=col; preview2.BackgroundColor3=col
                local t={math.round(col.R*255),math.round(col.G*255),math.round(col.B*255)}
                cfgSet(opts.Flag,t)
                if opts.Callback then pcall(opts.Callback,col) end
            end)
        end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,curColor) end
        return {Set=function(_,col) curColor=col; preview2.BackgroundColor3=col; local t={math.round(col.R*255),math.round(col.G*255),math.round(col.B*255)}; cfgSet(opts.Flag,t) end}
    end

    return Sec
end

-- ── Window Builder ─────────────────────────────────────────
function JL:CreateWindow(cfg)
    cfgLoad(cfg.ConfigName or "JustLibConfig")
    local titleText=cfg.Title or "JustLib"
    local subText  =cfg.SubTitle or "v1.0"
    local tabs     =cfg.Tabs or {}

    local CoreGui=game:GetService("CoreGui")
    local sg=Instance.new("ScreenGui")
    sg.Name="JustLibGUI"
    sg.Parent=CoreGui
    sg.ResetOnSpawn=false
    sg.ClipToDeviceSafeArea=false
    sg.DisplayOrder=999999999
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Global

    local WW,WH=500,340
    local win=Instance.new("Frame")
    win.Size=UDim2.new(0,WW,0,WH)
    win.Position=UDim2.new(0.5,-WW/2,0.5,-WH/2)
    win.BackgroundTransparency=1
    win.BorderSizePixel=0
    win.ZIndex=10
    win.Parent=sg

    local sidebarW=52
    local sidebar=Instance.new("Frame")
    sidebar.Size=UDim2.new(0,sidebarW,1,0)
    sidebar.Position=UDim2.new(0,0,0,0)
    sidebar.BackgroundColor3=C.sidebar
    sidebar.BorderSizePixel=0
    sidebar.ZIndex=11
    sidebar.Parent=win
    corner(12,sidebar)
    stroke(C.border,1,sidebar)

    local logoLbl=Instance.new("TextLabel")
    logoLbl.Size=UDim2.new(1,0,0,36)
    logoLbl.BackgroundTransparency=1
    logoLbl.Text="JL"
    logoLbl.Font=Enum.Font.GothamBold
    logoLbl.TextSize=14
    logoLbl.TextColor3=ACCENTS[1]
    logoLbl.ZIndex=12
    logoLbl.Parent=sidebar

    local tabBtnsHolder=Instance.new("Frame")
    tabBtnsHolder.Size=UDim2.new(1,0,1,-44)
    tabBtnsHolder.Position=UDim2.new(0,0,0,40)
    tabBtnsHolder.BackgroundTransparency=1
    tabBtnsHolder.ZIndex=12
    tabBtnsHolder.Parent=sidebar

    local sbList=Instance.new("UIListLayout")
    sbList.FillDirection=Enum.FillDirection.Vertical
    sbList.Padding=UDim.new(0,6)
    sbList.HorizontalAlignment=Enum.HorizontalAlignment.Center
    sbList.SortOrder=Enum.SortOrder.LayoutOrder
    sbList.Parent=tabBtnsHolder

    local mainPanel=Instance.new("Frame")
    mainPanel.Size=UDim2.new(1,-(sidebarW+8),1,0)
    mainPanel.Position=UDim2.new(0,sidebarW+8,0,0)
    mainPanel.BackgroundColor3=C.panel
    mainPanel.BorderSizePixel=0
    mainPanel.ZIndex=11
    mainPanel.Parent=win
    corner(12,mainPanel)
    stroke(C.border,1,mainPanel)

    local topBar=Instance.new("Frame")
    topBar.Size=UDim2.new(1,0,0,36)
    topBar.BackgroundColor3=C.pHdr
    topBar.BorderSizePixel=0
    topBar.ZIndex=12
    topBar.Parent=mainPanel
    corner(12,topBar)

    local topFix=Instance.new("Frame")
    topFix.Size=UDim2.new(1,0,0.5,0)
    topFix.Position=UDim2.new(0,0,0.5,0)
    topFix.BackgroundColor3=C.pHdr
    topFix.BorderSizePixel=0
    topFix.ZIndex=12
    topFix.Parent=topBar

    newTxt({Parent=topBar,Text=titleText,Font=Enum.Font.GothamBold,Size=12,Color=C.txt,Sz=UDim2.new(0.5,0,1,0),Pos=UDim2.new(0,10,0,0),Z=13})
    newTxt({Parent=topBar,Text=subText,Font=Enum.Font.Gotham,Size=10,Color=C.dim,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0.4,0,1,0),Pos=UDim2.new(0.6,-36,0,0),Z=13})

    local closeBtn=Instance.new("TextButton")
    closeBtn.Size=UDim2.new(0,22,0,22)
    closeBtn.Position=UDim2.new(1,-28,0.5,-11)
    closeBtn.BackgroundColor3=Color3.fromRGB(215,70,70)
    closeBtn.Text="✕"
    closeBtn.Font=Enum.Font.GothamBold
    closeBtn.TextSize=11
    closeBtn.TextColor3=Color3.new(1,1,1)
    closeBtn.ZIndex=13
    closeBtn.Parent=topBar
    corner(6,closeBtn)

    draggable(topBar,win)

    local fpsL=newTxt({Parent=sidebar,Text="60",Font=Enum.Font.GothamBold,Size=9,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,0,0,12),Pos=UDim2.new(0,0,1,-14),Z=13})
    local _fc,_fl=0,os.clock()
    RunSvc.RenderStepped:Connect(function()
        _fc=_fc+1; local now=os.clock()
        if now-_fl>=0.5 then
            local fps=math.round(_fc/(now-_fl))
            fpsL.Text=tostring(fps)
            fpsL.TextColor3=(fps>=50) and C.fpsGrn or ((fps>=30) and Color3.fromRGB(220,200,60) or Color3.fromRGB(220,60,60))
            _fc=0; _fl=now
        end
    end)

    local contentArea=Instance.new("Frame")
    contentArea.Size=UDim2.new(1,0,1,-36)
    contentArea.Position=UDim2.new(0,0,0,36)
    contentArea.BackgroundTransparency=1
    contentArea.ZIndex=12
    contentArea.Parent=mainPanel

    local tabFrames={}
    local tabBtns={}
    local activeTabId=nil

    local function switchTab(id)
        for tid,tf in pairs(tabFrames) do tf.Visible=(tid==id) end
        for tid,btn in pairs(tabBtns) do
            if tid==id then
                btn.BackgroundColor3=Color3.fromRGB(18,36,62)
                local ic=btn:FindFirstChildOfClass("TextLabel") or btn:FindFirstChildOfClass("ImageLabel")
                if ic then if ic:IsA("TextLabel") then ic.TextColor3=ACCENTS[1] else ic.ImageColor3=ACCENTS[1] end end
            else
                btn.BackgroundColor3=Color3.fromRGB(24,24,34)
                local ic=btn:FindFirstChildOfClass("TextLabel") or btn:FindFirstChildOfClass("ImageLabel")
                if ic then if ic:IsA("TextLabel") then ic.TextColor3=C.dim else ic.ImageColor3=C.dim end end
            end
        end
        activeTabId=id
    end

    local isOpen=false
    local function openW()
        isOpen=true
        win.Visible=true
        local s=.82
        win.Size=UDim2.new(0,WW*s,0,WH*s)
        win.Position=UDim2.new(0.5,-(WW*s)/2,0.5,-(WH*s)/2)
        tw(win,{Size=UDim2.new(0,WW,0,WH),Position=UDim2.new(0.5,-WW/2,0.5,-WH/2)},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
    end

    local function closeW()
        isOpen=false
        tw(win,{Size=UDim2.new(0,WW*.82,0,WH*.82),Position=UDim2.new(0.5,-(WW*.82)/2,0.5,-(WH*.82)/2)},.2,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
        task.delay(.21,function() if not isOpen then win.Visible=false end end)
    end

    closeBtn.MouseButton1Click:Connect(closeW)

    -- ── Badge (Always on top) ───────────────────────────────
    local BPOS={
        top   =UDim2.new(0.5,-70,0,8),
        center=UDim2.new(0.5,-70,0.5,-18),
    }
    local savedPosName=cfgGet("_badgePos","top")
    local startPos=BPOS[savedPosName] or BPOS.top

    local badgeSg=Instance.new("ScreenGui")
    badgeSg.Name="JLBadge"
    badgeSg.Parent=CoreGui
    badgeSg.ResetOnSpawn=false
    badgeSg.ClipToDeviceSafeArea=false
    badgeSg.DisplayOrder=999999999
    badgeSg.ZIndexBehavior=Enum.ZIndexBehavior.Global

    local badge=Instance.new("Frame")
    badge.Size=UDim2.new(0,140,0,36)
    badge.Position=startPos
    badge.BackgroundColor3=C.badge
    badge.BorderSizePixel=0
    badge.ZIndex=100
    badge.Parent=badgeSg
    corner(10,badge)
    stroke(C.border,1,badge)

    local bIcon=Instance.new("TextLabel")
    bIcon.Size=UDim2.new(0,28,0,28)
    bIcon.Position=UDim2.new(0,4,0.5,-14)
    bIcon.BackgroundColor3=C.badgeHi
    bIcon.Text="JL"
    bIcon.Font=Enum.Font.GothamBold
    bIcon.TextSize=12
    bIcon.TextColor3=ACCENTS[1]
    bIcon.ZIndex=101
    bIcon.Parent=badge
    corner(7,bIcon)

    newTxt({Parent=badge,Text=titleText,Font=Enum.Font.GothamBold,Size=10,Color=C.txt,Sz=UDim2.new(1,-38,0,14),Pos=UDim2.new(0,36,0,5),Z=101})
    newTxt({Parent=badge,Text="Click to toggle",Font=Enum.Font.Gotham,Size=8,Color=C.dim,Sz=UDim2.new(1,-38,0,12),Pos=UDim2.new(0,36,0,19),Z=101})

    draggable(badge,badge,function()
        if isOpen then closeW() else openW() end
    end)

    UIS.InputBegan:Connect(function(i,g)
        if g then return end
        if i.KeyCode==Enum.KeyCode.RightControl or i.KeyCode==Enum.KeyCode.LeftControl then
            if isOpen then closeW() else openW() end
        end
    end)

    local badge2=badge

    -- ── Tab Factory ─────────────────────────────────────────
    local WinObj={}

    function WinObj:Tab(opts)
        local id=opts.Name or ("Tab"..(#tabBtns+1))
        local icon=opts.Icon or "•"

        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(0,36,0,36)
        btn.BackgroundColor3=Color3.fromRGB(24,24,34)
        btn.BorderSizePixel=0
        btn.Text=""
        btn.ZIndex=13
        btn.Parent=tabBtnsHolder
        corner(8,btn)

        local icObj=mkIcon(btn,icon,18,14)
        icObj.Position=UDim2.new(0.5,-9,0.5,-9)
        if icObj:IsA("TextLabel") then icObj.TextColor3=C.dim end

        local tf=Instance.new("Frame")
        tf.Size=UDim2.new(1,0,1,0)
        tf.BackgroundTransparency=1
        tf.ZIndex=12
        tf.Visible=false
        tf.Parent=contentArea

        local colLeft=Instance.new("ScrollingFrame")
        colLeft.Size=UDim2.new(0.5,-4,1,0)
        colLeft.Position=UDim2.new(0,0,0,0)
        colLeft.BackgroundTransparency=1
        colLeft.BorderSizePixel=0
        colLeft.ScrollBarThickness=2
        colLeft.ScrollBarImageColor3=C.border
        colLeft.ZIndex=12
        colLeft.Parent=tf

        local colRight=Instance.new("ScrollingFrame")
        colRight.Size=UDim2.new(0.5,-4,1,0)
        colRight.Position=UDim2.new(0.5,4,0,0)
        colRight.BackgroundTransparency=1
        colRight.BorderSizePixel=0
        colRight.ScrollBarThickness=2
        colRight.ScrollBarImageColor3=C.border
        colRight.ZIndex=12
        colRight.Parent=tf

        local ll=Instance.new("UIListLayout"); ll.FillDirection=Enum.FillDirection.Vertical; ll.Padding=UDim.new(0,6); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Parent=colLeft
        local lr=Instance.new("UIListLayout"); lr.FillDirection=Enum.FillDirection.Vertical; lr.Padding=UDim.new(0,6); lr.SortOrder=Enum.SortOrder.LayoutOrder; lr.Parent=colRight
        pad(6,6,6,6,colLeft); pad(6,6,6,6,colRight)

        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() colLeft.CanvasSize=UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+12) end)
        lr:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() colRight.CanvasSize=UDim2.new(0,0,0,lr.AbsoluteContentSize.Y+12) end)

        tabFrames[id]=tf
        tabBtns[id]=btn

        btn.MouseButton1Click:Connect(function() switchTab(id) end)

        if not activeTabId then switchTab(id) end

        local sideToggle=0
        local TabObj={}

        function TabObj:Section(sOpts)
            local sTitle=type(sOpts)=="table" and sOpts.Title or sOpts
            local side=type(sOpts)=="table" and sOpts.Side or nil
            local targetCol
            if side=="Left" then targetCol=colLeft
            elseif side=="Right" then targetCol=colRight
            else
                sideToggle=sideToggle+1
                targetCol=(sideToggle%2==1) and colLeft or colRight
            end
            return makeSection(targetCol,sTitle,sg)
        end

        return TabObj
    end

    -- Build default user tabs
    for _,tData in ipairs(tabs) do WinObj:Tab(tData) end

    -- Settings tab
    local sTab=WinObj:Tab({Name="Settings",Icon="⚙"})
    local appSec=sTab:Section({Title="Appearance"})

    do
        local LT=game:GetService("Lighting")
        local function getBlur()
            local b=LT:FindFirstChildOfClass("BlurEffect")
            if not b then b=Instance.new("BlurEffect"); b.Parent=LT end
            return b
        end
        appSec:Slider({
            Name="Blur (0-100%)",Min=0,Max=100,Default=cfgGet("_blur",0),Flag="_blur",
            Callback=function(v)
                local sz=math.round(v*56/100)
                local b=getBlur()
                b.Enabled=(sz>0)
                b.Size=sz
            end
        })
        task.spawn(function()
            while task.wait(0.5) do
                local v2=cfgGet("_blur",0) or 0
                if v2>0 then
                    local sz=math.round(v2*56/100)
                    local b=getBlur()
                    if not b.Enabled then b.Enabled=true end
                    if b.Size~=sz then b.Size=sz end
                end
            end
        end)
    end

    appSec:Toggle({Name="Show FPS",Default=cfgGet("_showfps",true),Flag="_showfps",Callback=function(v) fpsL.Visible=v end})

    local badgeSec=sTab:Section({Title="Badge"})
    badgeSec:Button({Name="Position → Top",Callback=function() tw(badge2,{Position=BPOS.top},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out); cfgSet("_badgePos","top") end})
    badgeSec:Button({Name="Position → Center",Callback=function() tw(badge2,{Position=BPOS.center},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out); cfgSet("_badgePos","center") end})

    openW()
    return WinObj
end

return JL
