local JL = {}; JL.Flags = {}; JL._winOpen = false
local TS=game:GetService("TweenService"); local UIS=game:GetService("UserInputService")
local HTTP=game:GetService("HttpService"); local LP=game:GetService("Players").LocalPlayer
local PG=LP:WaitForChild("PlayerGui"); local RunSvc=game:GetService("RunService")
local C={
    panel=Color3.fromRGB(45,45,48),   pHdr=Color3.fromRGB(35,35,38),
    border=Color3.fromRGB(70,70,75),  txt=Color3.fromRGB(240,240,240),
    dim=Color3.fromRGB(160,160,165),  togOn=Color3.fromRGB(46,204,113),
    togOff=Color3.fromRGB(35,35,38),  slTrack=Color3.fromRGB(55,55,60),
    btnBg=Color3.fromRGB(55,55,60),   btnHov=Color3.fromRGB(75,75,80),
    sidebar=Color3.fromRGB(30,30,33), fpsGrn=Color3.fromRGB(72,214,92),
    badge=Color3.fromRGB(35,35,38),   badgeHi=Color3.fromRGB(50,60,90),
    chkBg=Color3.fromRGB(35,35,38),   divLine=Color3.fromRGB(70,70,75),
    input=Color3.fromRGB(55,55,60),
}
local ACCENTS={
    Color3.fromRGB(82,152,255), Color3.fromRGB(148,92,255),
    Color3.fromRGB(72,198,138), Color3.fromRGB(255,132,72),
    Color3.fromRGB(255,72,108), Color3.fromRGB(72,208,208),
}
local _ai=0; local function nxAc() _ai=_ai+1; return ACCENTS[((_ai-1)%#ACCENTS)+1] end
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
local function textMode(opts)
    local m=tostring((opts and opts.TextMode) or "Scroll"):lower()
    if m=="wrap" or m=="wrapped" or m=="2line" then return "Wrap" end
    return "Scroll"
end
local function textHeight(text,width,size)
    local ok,b=pcall(function()
        return game:GetService("TextService"):GetTextSize(tostring(text or ""),size,Enum.Font.GothamBold,Vector2.new(math.max(40,width),1000))
    end)
    if not ok then return size+8 end
    return math.clamp(math.ceil(b.Y),size+2,size*2+6)
end
local function textHost(parent,x,y,w,h,z)
    local host=Instance.new("Frame")
    host.BackgroundTransparency=1; host.ClipsDescendants=true; host.Size=UDim2.new(0,w,0,h); host.Position=UDim2.new(0,x,0,y); host.ZIndex=z or 18; host.Parent=parent
    return host
end
local function longText(parent,text,opts)
    opts=opts or {}; local mode=textMode(opts); local size=opts.Size or 12
    local host=opts.Host or textHost(parent,opts.X or 0,opts.Y or 0,opts.Width or 100,opts.Height or 24,opts.Z or 18)
    local lbl=Instance.new("TextLabel")
    lbl.BackgroundTransparency=1; lbl.Text=tostring(text or ""); lbl.Font=opts.Font or Enum.Font.GothamBold; lbl.TextSize=size
    lbl.TextColor3=opts.Color or C.txt; lbl.TextXAlignment=opts.XAlign or Enum.TextXAlignment.Left; lbl.TextYAlignment=opts.YAlign or Enum.TextYAlignment.Center
    lbl.ZIndex=(opts.Z or 18)+1; lbl.TextTruncate=Enum.TextTruncate.None; lbl.TextWrapped=(mode=="Wrap"); lbl.Parent=host
    if mode=="Wrap" then
        lbl.Size=UDim2.new(1,0,1,0)
        lbl.Position=UDim2.new(0,0,0,0)
    else
        lbl.TextWrapped=false
        lbl.AutomaticSize=Enum.AutomaticSize.X
        lbl.Size=UDim2.new(0,math.max(host.AbsoluteSize.X,1),1,0)
        lbl.Position=UDim2.new(0,0,0,0)
        local function marquee()
            if not lbl.Parent or mode~="Scroll" then return end
            task.spawn(function()
                task.wait(0.15)
                while lbl.Parent do
                    local overflow=lbl.TextBounds.X-host.AbsoluteSize.X
                    if overflow>4 then
                        lbl.Position=UDim2.new(0,0,0,0)
                        task.wait(0.55)
                        tw(lbl,{Position=UDim2.new(0,-overflow-10,0,0)},math.clamp(overflow/35,0.7,2.8),Enum.EasingStyle.Linear,Enum.EasingDirection.InOut)
                        task.wait(math.clamp(overflow/35,0.7,2.8)+0.35)
                        if not lbl.Parent then break end
                        tw(lbl,{Position=UDim2.new(0,0,0,0)},math.clamp(overflow/35,0.7,2.8),Enum.EasingStyle.Linear,Enum.EasingDirection.InOut)
                        task.wait(math.clamp(overflow/35,0.7,2.8)+0.55)
                    else
                        task.wait(0.8)
                    end
                end
            end)
        end
        marquee()
    end
    return host,lbl,mode
end
local function adaptiveRowHeight(opts,base,width,size)
    if textMode(opts)=="Wrap" then
        return math.max(base,textHeight(opts.Name or opts.Text or "",width,size)+10)
    end
    return base
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
    local preview=Instance.new("Frame"); preview.Size=UDim2.new(0,28,0,20); preview.Position=UDim2.new(1,-66,0.5,-10); preview.BackgroundColor3=currentColor; preview.BorderSizePixel=0; preview.ZIndex=203; preview.Parent=hdr; corner(5,preview); stroke(C.border,1,preview)
    local function refreshPreview() preview.BackgroundColor3=Color3.fromHSV(h,s,v) end
    local svBg=Instance.new("Frame"); svBg.Size=UDim2.new(1,-20,0,120); svBg.Position=UDim2.new(0,10,0,44); svBg.BackgroundColor3=Color3.fromHSV(h,1,1); svBg.BorderSizePixel=0; svBg.ZIndex=202; svBg.ClipsDescendants=true; svBg.Parent=card; corner(4,svBg)
    local svSat=Instance.new("Frame"); svSat.Size=UDim2.new(1,0,1,0); svSat.BackgroundColor3=Color3.new(1,1,1); svSat.BorderSizePixel=0; svSat.ZIndex=203; svSat.Parent=svBg; corner(4,svSat)
    local svSatG=Instance.new("UIGradient"); svSatG.Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(1,1,1)); svSatG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); svSatG.Rotation=0; svSatG.Parent=svSat
    local svVal=Instance.new("Frame"); svVal.Size=UDim2.new(1,0,1,0); svVal.BackgroundColor3=Color3.new(0,0,0); svVal.BorderSizePixel=0; svVal.ZIndex=204; svVal.Parent=svBg; corner(4,svVal)
    local svValG=Instance.new("UIGradient"); svValG.Color=ColorSequence.new(Color3.new(0,0,0),Color3.new(0,0,0)); svValG.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); svValG.Rotation=90; svValG.Parent=svVal
    local svCursor=Instance.new("Frame"); svCursor.Size=UDim2.new(0,10,0,10); svCursor.BackgroundColor3=Color3.new(1,1,1); svCursor.BorderSizePixel=0; svCursor.ZIndex=205; corner(5,svCursor)
    local function updateSvCursor() svCursor.Position=UDim2.new(s,-5,1-v,-5); svCursor.Parent=svBg end
    updateSvCursor()
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

-- Blocking Yes/No confirmation dialog. Returns true/false once the user answers.
local function confirmDialog(promptTitle, promptDesc)
    local CoreGui=game:GetService("CoreGui")
    local sg3=Instance.new("ScreenGui"); sg3.Name="JLConfirm"; sg3.ResetOnSpawn=false; sg3.IgnoreGuiInset=true; sg3.DisplayOrder=1000
    local okp=pcall(function() sg3.Parent=CoreGui end); if not okp or not sg3.Parent then sg3.Parent=PG end
    local bd=Instance.new("Frame"); bd.Size=UDim2.new(1,0,1,0); bd.BackgroundColor3=Color3.new(0,0,0); bd.BackgroundTransparency=0.45; bd.BorderSizePixel=0; bd.ZIndex=300; bd.Parent=sg3
    local card=Instance.new("Frame"); card.Size=UDim2.new(0,260,0,140); card.Position=UDim2.new(0.5,-130,0.5,-70); card.BackgroundColor3=C.panel; card.BorderSizePixel=0; card.ZIndex=301; card.Parent=bd; corner(10,card); stroke(C.border,1,card)
    newTxt({Parent=card,Text=promptTitle,Font=Enum.Font.GothamBold,Size=14,Color=C.txt,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-20,0,20),Pos=UDim2.new(0,10,0,14),Z=302})
    newTxt({Parent=card,Text=promptDesc,Size=11,Color=C.dim,Wrap=true,XAlign=Enum.TextXAlignment.Center,Sz=UDim2.new(1,-24,0,48),Pos=UDim2.new(0,12,0,40),Z=302})
    local yesBtn=Instance.new("TextButton"); yesBtn.Size=UDim2.new(0,105,0,32); yesBtn.Position=UDim2.new(0,18,1,-46); yesBtn.BackgroundColor3=Color3.fromRGB(72,198,138); yesBtn.Text="Yes"; yesBtn.Font=Enum.Font.GothamBold; yesBtn.TextSize=13; yesBtn.TextColor3=Color3.new(1,1,1); yesBtn.ZIndex=302; yesBtn.Parent=card; corner(7,yesBtn)
    local noBtn=Instance.new("TextButton"); noBtn.Size=UDim2.new(0,105,0,32); noBtn.Position=UDim2.new(1,-123,1,-46); noBtn.BackgroundColor3=Color3.fromRGB(215,70,70); noBtn.Text="No"; noBtn.Font=Enum.Font.GothamBold; noBtn.TextSize=13; noBtn.TextColor3=Color3.new(1,1,1); noBtn.ZIndex=302; noBtn.Parent=card; corner(7,noBtn)
    local result=nil
    yesBtn.MouseButton1Click:Connect(function() if result~=nil then return end; result=true end)
    noBtn.MouseButton1Click:Connect(function() if result~=nil then return end; result=false end)
    while result==nil do task.wait() end
    sg3:Destroy()
    return result
end

local function makeSection(parentFrame,title,parentSg,layoutOrder,variant)
    local ac=nxAc()
    local headerH=(variant=="Grid" and 42 or 36)
    local panel=Instance.new("Frame"); panel.Size=UDim2.new(1,0,0,headerH); panel.BackgroundColor3=C.panel; panel.BorderSizePixel=0; panel.ZIndex=13; panel.LayoutOrder=layoutOrder or 1; panel.ClipsDescendants=true; panel.Parent=parentFrame
    corner(10,panel); stroke(C.border,1,panel)
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,headerH); hdr.BackgroundColor3=C.pHdr; hdr.BorderSizePixel=0; hdr.ZIndex=14; hdr.Parent=panel; corner(8,hdr)
    local hfix=Instance.new("Frame"); hfix.Size=UDim2.new(1,0,0.5,0); hfix.Position=UDim2.new(0,0,0.5,0); hfix.BackgroundColor3=C.pHdr; hfix.BorderSizePixel=0; hfix.ZIndex=14; hfix.Parent=hdr
    local titleHost= textHost(hdr,14,0,headerH>40 and 1 or 1,headerH,15)
titleHost.Size=UDim2.new(1,-58,0,headerH)
local _,titleLbl=longText(hdr,title,{Host=titleHost,Size=(variant=="Grid" and 12 or 13),XAlign=Enum.TextXAlignment.Left,Z=15})
    local arrow=Instance.new("TextLabel"); arrow.Size=UDim2.new(0,36,0,headerH); arrow.Position=UDim2.new(1,-36,0,0); arrow.BackgroundTransparency=1; arrow.Text="▼"; arrow.Font=Enum.Font.GothamBold; arrow.TextSize=9; arrow.TextColor3=C.dim; arrow.TextXAlignment=Enum.TextXAlignment.Center; arrow.TextYAlignment=Enum.TextYAlignment.Center; arrow.ZIndex=15; arrow.Parent=hdr
    local secBtn=Instance.new("TextButton"); secBtn.Size=UDim2.new(1,0,1,0); secBtn.BackgroundTransparency=1; secBtn.Text=""; secBtn.ZIndex=16; secBtn.Parent=hdr
    local strip=Instance.new("Frame"); strip.BackgroundColor3=ac; strip.BorderSizePixel=0; strip.ZIndex=16; strip.Visible=(variant=="Grid"); strip.Parent=panel; corner(3,strip)
    local content=Instance.new("Frame"); content.Size=UDim2.new(1,0,0,0); content.Position=UDim2.new(0,0,0,headerH); content.BackgroundTransparency=1; content.ZIndex=14; content.ClipsDescendants=true; content.Parent=panel
    local list=Instance.new("UIListLayout"); list.FillDirection=Enum.FillDirection.Vertical; list.Padding=UDim.new(0,5); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=content; pad(12,8,8,8,content)
    local collapsed=false; local storedH=0
    local function updatePanel()
        local h=list.AbsoluteContentSize.Y+16
        content.Size=UDim2.new(1,0,0,h); panel.Size=UDim2.new(1,0,0,headerH+h)
        if not collapsed then storedH=h end
        if not collapsed and list.AbsoluteContentSize.Y>0 then
            strip.Visible=true; strip.Size=UDim2.new(0,3,0,list.AbsoluteContentSize.Y); strip.Position=UDim2.new(0,7,0,headerH+8)
        elseif variant~="Grid" then strip.Visible=false end
    end
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanel)
    secBtn.MouseButton1Click:Connect(function()
        collapsed=not collapsed; tw(arrow,{Rotation=collapsed and 180 or 0},.2)
        if collapsed then
            strip.Visible=false; tw(panel,{Size=UDim2.new(1,0,0,headerH+2)},.18)
            task.delay(.19,function() if collapsed then content.Visible=false end end)
        else
            content.Visible=true; tw(panel,{Size=UDim2.new(1,0,0,headerH+storedH)},.18)
            task.delay(.2,function() if not collapsed then updatePanel() end end)
        end
    end)
    local iOrd=0
    local Sec={}
    local function newRow(h2) iOrd=iOrd+1; local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,h2); r.BackgroundTransparency=1; r.ZIndex=16; r.LayoutOrder=iOrd; r.Parent=content; return r end
    function Sec:Toggle(opts)
        local state=cfgGet(opts.Flag,opts.Default or false)
        local row=newRow(adaptiveRowHeight(opts,32,170,12))
        local bg=Instance.new("TextButton"); bg.Size=UDim2.new(1,0,1,0); bg.BackgroundColor3=C.btnBg; bg.Text=""; bg.ZIndex=17; bg.Parent=row; corner(6,bg); stroke(C.border,1,bg)
        local host=textHost(bg,8,0,math.max(40,bg.AbsoluteSize.X-48),bg.AbsoluteSize.Y,18); host.Size=UDim2.new(1,-40,1,0)
        local _,lbl=longText(bg,opts.Name or "Toggle",{Host=host,Size=12,XAlign=Enum.TextXAlignment.Left,Z=18})
        local ind=Instance.new("Frame"); ind.Size=UDim2.new(0,16,0,16); ind.Position=UDim2.new(1,-24,0.5,-8); ind.BackgroundColor3=state and (ac or C.togOn) or C.togOff; ind.BorderSizePixel=0; ind.ZIndex=18; ind.Parent=bg; corner(4,ind); stroke(C.border,1,ind)
        bg.MouseButton1Click:Connect(function()
            state=not state; tw(ind,{BackgroundColor3=state and (ac or C.togOn) or C.togOff},.12)
            cfgSet(opts.Flag,state); if opts.Callback then pcall(opts.Callback,state) end
        end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,state) end
        return {Set=function(_,v) state=v; ind.BackgroundColor3=v and (ac or C.togOn) or C.togOff; cfgSet(opts.Flag,v) end, Get=function() return state end}
    end
    function Sec:Slider(opts)
        local val=cfgGet(opts.Flag,opts.Default or opts.Min or 0); local vmin=opts.Min or 0; local vmax=opts.Max or 100
        local row=newRow(adaptiveRowHeight(opts,40,160,11)+(textMode(opts)=="Wrap" and 8 or 0))
        local top=Instance.new("Frame"); top.Size=UDim2.new(1,0,0,18); top.BackgroundTransparency=1; top.ZIndex=17; top.Parent=row
        local host=textHost(top,4,0,math.max(40,top.AbsoluteSize.X-50),18,17); host.Size=UDim2.new(1,-50,0,(textMode(opts)=="Wrap" and 30 or 18))
        local _,lbl=longText(top,opts.Name or "Slider",{Host=host,Size=11,XAlign=Enum.TextXAlignment.Left,Z=17})
        local valLbl
        valLbl=Instance.new("TextLabel"); valLbl.Size=UDim2.new(0,44,1,0); valLbl.Position=UDim2.new(1,-44,0,0); valLbl.BackgroundTransparency=1; valLbl.Text=tostring(val); valLbl.Font=Enum.Font.GothamBold; valLbl.TextSize=11; valLbl.TextColor3=C.dim; valLbl.TextXAlignment=Enum.TextXAlignment.Right; valLbl.ZIndex=17; valLbl.Parent=top
        local tBg=Instance.new("TextButton"); tBg.Size=UDim2.new(1,-8,0,8); tBg.Position=UDim2.new(0,4,0,(textMode(opts)=="Wrap" and 34 or 24)); tBg.BackgroundColor3=C.slTrack; tBg.Text=""; tBg.ZIndex=17; tBg.Parent=row; corner(4,tBg); stroke(C.border,1,tBg)
        local pct=math.clamp((val-vmin)/(vmax-vmin),0,1)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(pct,0,1,0); fill.BackgroundColor3=ac; fill.BorderSizePixel=0; fill.ZIndex=18; fill.Parent=tBg; corner(4,fill)
        local sliding=false
        local function updSlider(inp)
            local p=math.clamp((inp.Position.X-tBg.AbsolutePosition.X)/tBg.AbsoluteSize.X,0,1)
            val=math.round(vmin+p*(vmax-vmin)); valLbl.Text=tostring(val); tw(fill,{Size=UDim2.new(p,0,1,0)},.06)
            cfgSet(opts.Flag,val); if opts.Callback then pcall(opts.Callback,val) end
        end
        tBg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=true; updSlider(i) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end end)
        UIS.InputChanged:Connect(function(i) if not sliding then return end; if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end; updSlider(i) end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,val) end
        return {Set=function(_,v) val=v; local p=math.clamp((v-vmin)/(vmax-vmin),0,1); fill.Size=UDim2.new(p,0,1,0); valLbl.Text=tostring(v); cfgSet(opts.Flag,v) end, Get=function() return val end}
    end
    function Sec:Button(opts)
        local row=newRow(adaptiveRowHeight(opts,32,190,12))
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundColor3=C.btnBg; btn.Text=""; btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.TextColor3=C.txt; btn.TextXAlignment=Enum.TextXAlignment.Center; btn.TextTruncate=Enum.TextTruncate.None; btn.ZIndex=17; btn.Parent=row; corner(6,btn); stroke(C.border,1,btn)
        local bHost=textHost(btn,10,0,math.max(40,btn.AbsoluteSize.X-20),btn.AbsoluteSize.Y,17); bHost.Size=UDim2.new(1,-20,1,0)
        local _,bLbl=longText(btn,opts.Name or "Button",{Host=bHost,Size=12,XAlign=Enum.TextXAlignment.Center,Z=17})
        btn.MouseEnter:Connect(function() tw(btn,{BackgroundColor3=C.btnHov},.1) end); btn.MouseLeave:Connect(function() tw(btn,{BackgroundColor3=C.btnBg},.1) end)
        btn.MouseButton1Click:Connect(function() tw(btn,{BackgroundColor3=ac},.06); task.delay(.14,function() tw(btn,{BackgroundColor3=C.btnBg},.12) end); if opts.Callback then pcall(opts.Callback) end end)
        return btn
    end
    function Sec:Input(opts)
        local row=newRow(adaptiveRowHeight(opts,32,180,12))
        local bg=Instance.new("Frame"); bg.Size=UDim2.new(1,0,1,0); bg.BackgroundColor3=C.input; bg.BorderSizePixel=0; bg.ZIndex=17; bg.Parent=row; corner(6,bg); stroke(C.border,1,bg)
        local box=Instance.new("TextBox"); box.Size=UDim2.new(1,-16,1,0); box.Position=UDim2.new(0,8,0,0); box.BackgroundTransparency=1; box.PlaceholderText=opts.Placeholder or (opts.Name or "Input"); box.PlaceholderColor3=C.dim; box.Text=cfgGet(opts.Flag,"") or ""; box.Font=Enum.Font.GothamBold; box.TextSize=12; box.TextColor3=C.txt; box.ClearTextOnFocus=false; box.MultiLine=opts.MultiLine or false; box.TextWrapped=opts.MultiLine or textMode(opts)=="Wrap"; box.TextXAlignment=Enum.TextXAlignment.Left; box.ZIndex=18; box.Parent=bg
        box.FocusLost:Connect(function(enter) if enter or opts.OnChange then cfgSet(opts.Flag,box.Text); if opts.Callback then pcall(opts.Callback,box.Text) end end end)
        if opts.OnChange then box:GetPropertyChangedSignal("Text"):Connect(function() cfgSet(opts.Flag,box.Text); if opts.Callback then pcall(opts.Callback,box.Text) end end) end
        return {Get=function() return box.Text end, Set=function(_,v) box.Text=v end}
    end
    
            function Sec:Dropdown(opts)
        local options=opts.Options or {}; local multi=opts.MultiSelect; local maxSel=opts.MaxSelect or 1
        local selected={}
        local saved=cfgGet(opts.Flag,opts.Default)
        if saved then if type(saved)=="table" then for _,v in ipairs(saved) do selected[v]=true end elseif saved~="" then selected[saved]=true end end
        local dropOpen=false
        local row=newRow(adaptiveRowHeight(opts,32,180,12))
        local bg=Instance.new("TextButton"); bg.Size=UDim2.new(1,0,0,(textMode(opts)=="Wrap" and row.Size.Y.Offset or 32)); bg.BackgroundColor3=C.btnBg; bg.Text=""; bg.ZIndex=17; bg.Parent=row; corner(6,bg); stroke(C.border,1,bg)
        local dHost=textHost(bg,8,0,math.max(40,bg.AbsoluteSize.X-40),bg.Size.Y.Offset,18); dHost.Size=UDim2.new(1,-40,1,0)
        local _,lbl=longText(bg,opts.Name or "Dropdown",{Host=dHost,Size=12,XAlign=Enum.TextXAlignment.Left,Z=18})
        local darr=Instance.new("TextLabel"); darr.Size=UDim2.new(0,32,1,0); darr.Position=UDim2.new(1,-32,0,0); darr.BackgroundTransparency=1; darr.Text="▼"; darr.Font=Enum.Font.GothamBold; darr.TextSize=9; darr.TextColor3=C.dim; darr.TextXAlignment=Enum.TextXAlignment.Center; darr.TextYAlignment=Enum.TextYAlignment.Center; darr.ZIndex=18; darr.Parent=bg
        local OPT_H=24; local TOTAL=math.min(#options,5)*OPT_H+8
        local container=Instance.new("ScrollingFrame"); container.Size=UDim2.new(1,0,0,0); container.Position=UDim2.new(0,0,0,34); container.BackgroundColor3=C.pHdr; container.BorderSizePixel=0; container.ZIndex=80; container.Visible=false; container.ClipsDescendants=true; container.ScrollBarThickness=3; container.ScrollBarImageColor3=C.border; container.Parent=row; corner(6,container); stroke(C.border,1,container)
        local cStack=Instance.new("UIListLayout"); cStack.FillDirection=Enum.FillDirection.Vertical; cStack.SortOrder=Enum.SortOrder.LayoutOrder; cStack.Padding=UDim.new(0,2); cStack.Parent=container; pad(4,4,4,4,container)
        cStack:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() container.CanvasSize=UDim2.new(0,0,0,cStack.AbsoluteContentSize.Y+8) end)
        local optRefs={}
        for i,optName in ipairs(options) do
            local opt=Instance.new("TextButton"); opt.Size=UDim2.new(1,0,0,OPT_H); opt.BackgroundColor3=C.btnBg; opt.Text=""; opt.Font=Enum.Font.GothamBold; opt.TextSize=11; opt.TextColor3=C.txt; opt.TextXAlignment=Enum.TextXAlignment.Center; opt.TextTruncate=Enum.TextTruncate.None; opt.ZIndex=81; opt.Parent=container; corner(4,opt)
            local oHost=textHost(opt,8,0,math.max(40,opt.AbsoluteSize.X-16),OPT_H,81); oHost.Size=UDim2.new(1,-16,1,0)
            longText(opt,tostring(optName),{Host=oHost,Size=11,XAlign=Enum.TextXAlignment.Center,Z=81,TextMode=opts.TextMode})
            local selMark=Instance.new("Frame"); selMark.Size=UDim2.new(0,3,0.6,0); selMark.Position=UDim2.new(0,0,0.2,0); selMark.BackgroundColor3=ac; selMark.BorderSizePixel=0; selMark.ZIndex=82; selMark.Visible=selected[optName] or false; selMark.Parent=opt; corner(2,selMark)
            optRefs[optName]={opt=opt,mark=selMark}
            opt.MouseEnter:Connect(function() tw(opt,{BackgroundColor3=C.btnHov},.1) end); opt.MouseLeave:Connect(function() tw(opt,{BackgroundColor3=C.btnBg},.1) end)
            opt.MouseButton1Click:Connect(function()
                if multi then
                    local cnt=0; for _ in pairs(selected) do cnt=cnt+1 end
                    if selected[optName] then 
                        selected[optName]=nil; selMark.Visible=false
                    elseif cnt<maxSel then 
                        selected[optName]=true; selMark.Visible=true 
                    else 
                        return 
                    end

                    local sel={}
                    for k in pairs(selected) do table.insert(sel,k) end

                    cfgSet(opts.Flag,sel)
                    if opts.Callback then pcall(opts.Callback,sel) end
                else
                    for _,ref in pairs(optRefs) do ref.mark.Visible=false end
                    selected={}; selected[optName]=true; selMark.Visible=true
                    lbl.Text=(opts.Name or "Dropdown")..": "..optName
                    cfgSet(opts.Flag,optName)
                    if opts.Callback then pcall(opts.Callback,optName) end
                end
            end)
        end

        bg.MouseButton1Click:Connect(function()
            dropOpen = not dropOpen
            container.Visible = dropOpen
            tw(container, {Size = dropOpen and UDim2.new(1, 0, 0, TOTAL) or UDim2.new(1, 0, 0, 0)}, 0.2)
            tw(row, {Size = dropOpen and UDim2.new(1, 0, 0, 36 + TOTAL) or UDim2.new(1, 0, 0, 32)}, 0.2)
            darr.Text = dropOpen and "▲" or "▼"
        end)

        if not multi then
            for k in pairs(selected) do lbl.Text=(opts.Name or "Dropdown")..": "..k end
        end
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then
            if multi then
                local sel={}; for k in pairs(selected) do table.insert(sel,k) end
                pcall(opts.Callback,sel)
            else
                for k in pairs(selected) do pcall(opts.Callback,k) end
            end
        end

        return {
            Get = function() return selected end
        }
    end

    function Sec:ColorPicker(opts)
        local curColor=cfgGet(opts.Flag,opts.Default or Color3.fromRGB(255,255,255))
        if type(curColor)=="table" then curColor=Color3.fromRGB(curColor[1] or 255,curColor[2] or 255,curColor[3] or 255) end
        local row=newRow(adaptiveRowHeight(opts,28,150,11))
        local cHost=textHost(row,0,0,math.max(40,row.AbsoluteSize.X-64),row.AbsoluteSize.Y,17); cHost.Size=UDim2.new(1,-64,1,0); longText(row,opts.Name or "Color",{Host=cHost,Size=11,Z=17,TextMode=opts.TextMode})
        local preview2=Instance.new("Frame"); preview2.Size=UDim2.new(0,34,0,20); preview2.Position=UDim2.new(1,-54,0.5,-10); preview2.BackgroundColor3=curColor; preview2.BorderSizePixel=0; preview2.ZIndex=17; preview2.Parent=row; corner(5,preview2); stroke(C.border,1,preview2)
        local openBtn=Instance.new("TextButton"); openBtn.Size=UDim2.new(0,16,0,20); openBtn.Position=UDim2.new(1,-18,0.5,-10); openBtn.BackgroundColor3=C.btnBg; openBtn.Text="⋯"; openBtn.Font=Enum.Font.GothamBold; openBtn.TextSize=10; openBtn.TextColor3=C.txt; openBtn.ZIndex=17; openBtn.Parent=row; corner(5,openBtn)
        openBtn.MouseButton1Click:Connect(function()
            openColorPicker(parentSg,curColor,function(col) curColor=col; preview2.BackgroundColor3=col; local t={math.round(col.R*255),math.round(col.G*255),math.round(col.B*255)}; cfgSet(opts.Flag,t); if opts.Callback then pcall(opts.Callback,col) end end)
        end)
        if opts.Callback and cfgGet(opts.Flag,nil)~=nil then pcall(opts.Callback,curColor) end
        return {Get=function() return curColor end, Set=function(_,v) curColor=v; preview2.BackgroundColor3=v end}
    end

    function Sec:Label(opts)
        local row=newRow(18)
        newTxt({Parent=row,Text=opts.Text or "",Size=10,Color=opts.Color or C.dim,Sz=UDim2.new(1,0,1,0),Z=17})
    end

    function Sec:Divider(opts)
        local row=newRow(18); local line=Instance.new("Frame"); line.Size=UDim2.new(1,0,0,1); line.Position=UDim2.new(0,0,0.5,0); line.BackgroundColor3=C.divLine; line.BorderSizePixel=0; line.ZIndex=17; line.Parent=row
        if opts and opts.Label then local LW=math.min(#opts.Label*7+12,90); local bg=Instance.new("Frame"); bg.Size=UDim2.new(0,LW,0,13); bg.Position=UDim2.new(0.5,-LW/2,0.5,-6); bg.BackgroundColor3=C.panel; bg.BorderSizePixel=0; bg.ZIndex=17; bg.Parent=row; corner(3,bg); newTxt({Parent=bg,Text=opts.Label,Font=Enum.Font.GothamBold,Size=9,Color=C.dim,XAlign=Enum.TextXAlignment.Center,Z=18}) end
    end

    function Sec:Custom(height, setupFn)
        iOrd=iOrd+1
        local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,height); f.BackgroundTransparency=1; f.ZIndex=16; f.LayoutOrder=iOrd; f.ClipsDescendants=true; f.Parent=content
        if setupFn then setupFn(f) end
        return f
    end

    return Sec
end
function JL:Window(opts)
    opts=opts or {}
    if shared._JLActive and shared._JLActive.alive then
        local restart=confirmDialog("Hub Already Running","A JustLib hub is already open. Restart it?")
        if not restart then return nil end
        pcall(shared._JLActive.destroy)
    end
    if opts.Config then cfgLoad(opts.Config) end
    local sg=Instance.new("ScreenGui"); sg.Name="JustXLibrary"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=999
    local ok=pcall(function() sg.Parent=game:GetService("CoreGui") end); if not ok then sg.Parent=PG end
    local _dead=false
    local BPOS={top=UDim2.new(0.5,-79,0,14),center=UDim2.new(0.5,-79,0.5,-15),bottom=UDim2.new(0.5,-79,1,-44)}
    local badge2=Instance.new("Frame"); badge2.Size=UDim2.new(0,158,0,30); badge2.Position=BPOS.top; badge2.BackgroundColor3=C.badge; badge2.BorderSizePixel=0; badge2.ZIndex=60; badge2.Parent=sg; corner(8,badge2); stroke(C.border,1,badge2)
    if opts.Icon then local ic=mkIcon(badge2,opts.Icon,18,61); ic.Size=UDim2.new(0,18,0,18); ic.Position=UDim2.new(0,8,0.5,-9) end
    local offX=opts.Icon and 32 or 10
    local badgeTitle=newTxt({Parent=badge2,Text=opts.Title or "JustXLibrary",Font=Enum.Font.GothamBold,Size=12,Sz=UDim2.new(0,78,1,0),Pos=UDim2.new(0,offX,0,0),Z=61})
    local divF=Instance.new("Frame"); divF.Size=UDim2.new(0,1,0,16); divF.Position=UDim2.new(0,100,0.5,-8); divF.BackgroundColor3=C.border; divF.BorderSizePixel=0; divF.ZIndex=61; divF.Parent=badge2
    local fpsL=newTxt({Parent=badge2,Text="60 FPS",Font=Enum.Font.GothamBold,Size=12,Color=C.fpsGrn,XAlign=Enum.TextXAlignment.Right,Sz=UDim2.new(0,46,1,0),Pos=UDim2.new(0,104,0,0),Z=61})
    local fpsConn
    do local _lt=tick(); local _fr=0; fpsConn=RunSvc.Heartbeat:Connect(function() _fr=_fr+1; local n=tick(); if n-_lt>=0.5 then fpsL.Text=math.round(_fr/(n-_lt)).." FPS"; _fr=0; _lt=n end end) end
    local badgeTap=Instance.new("TextButton"); badgeTap.Size=UDim2.new(1,0,1,0); badgeTap.BackgroundTransparency=1; badgeTap.Text=""; badgeTap.ZIndex=62; badgeTap.Parent=badge2
    local WW,WH=680,430
    local win=Instance.new("Frame"); win.Size=UDim2.new(0,WW,0,WH); win.Position=UDim2.new(0.5,-WW/2,0.5,-WH/2); win.BackgroundTransparency=1; win.BorderSizePixel=0; win.ZIndex=10; win.Visible=false; win.ClipsDescendants=false; win.Parent=sg
    local SBW=44; local sidebar=Instance.new("Frame"); sidebar.Size=UDim2.new(0,SBW,0,0); sidebar.Position=UDim2.new(0,0,0.5,0); sidebar.BackgroundColor3=C.sidebar; sidebar.BorderSizePixel=0; sidebar.ZIndex=12; sidebar.Parent=win; corner(10,sidebar); stroke(C.border,1,sidebar)
    local sbList=Instance.new("UIListLayout"); sbList.FillDirection=Enum.FillDirection.Vertical; sbList.HorizontalAlignment=Enum.HorizontalAlignment.Center; sbList.VerticalAlignment=Enum.VerticalAlignment.Center; sbList.Padding=UDim.new(0,8); sbList.Parent=sidebar; pad(0,0,10,10,sidebar)
    sbList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h=sbList.AbsoluteContentSize.Y+20; sidebar.Size=UDim2.new(0,SBW,0,h); sidebar.Position=UDim2.new(0,0,0.5,-h/2)
    end)
    local content=Instance.new("Frame"); content.Size=UDim2.new(1,-(SBW+10),1,0); content.Position=UDim2.new(0,SBW+10,0,0); content.BackgroundTransparency=1; content.ZIndex=11; content.ClipsDescendants=true; content.Parent=win
    local tabFrames={}; local tabBtns={}; local activeTabId=nil; local _tabCount=0; local gridConnections={}
    local function switchToTab(id)
        local prevId=activeTabId
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
    local isOpen=false
    local function openW() isOpen=true; win.Visible=true; local s=.82; win.Size=UDim2.new(0,WW*s,0,WH*s); win.Position=UDim2.new(0.5,-(WW*s)/2,0.5,-(WH*s)/2); tw(win,{Size=UDim2.new(0,WW,0,WH),Position=UDim2.new(0.5,-WW/2,0.5,-WH/2)},.28,Enum.EasingStyle.Back,Enum.EasingDirection.Out); tw(badge2,{BackgroundColor3=C.badgeHi},.15); if activeTabId then switchToTab(activeTabId) end; JL._winOpen=true end
    local function closeW() isOpen=false; JL._winOpen=false; local s=.82; tw(win,{Size=UDim2.new(0,WW*s,0,WH*s),Position=UDim2.new(0.5,-(WW*s)/2,0.5,-(WH*s)/2)},.18,Enum.EasingStyle.Quart,Enum.EasingDirection.In); task.delay(.19,function() if not isOpen then win.Visible=false end end); tw(badge2,{BackgroundColor3=C.badge},.15); pcall(function() local LT2=game:GetService("Lighting"); local b=LT2:FindFirstChildOfClass("BlurEffect"); if b then b.Enabled=false end end) end
    draggable(badgeTap,badge2,function() if isOpen then closeW() else openW() end end)
    draggable(sidebar,win)
    local hotkey=opts.Hotkey or Enum.KeyCode.RightShift
    local hotkeyConn=UIS.InputBegan:Connect(function(i,gp) if gp then return end; if i.KeyCode==hotkey then if isOpen then closeW() else openW() end end end)

    -- Full teardown: kills background loops, disconnects everything, wipes the GUI.
    local function destroyHub()
        if _dead then return end
        _dead=true
        JL._winOpen=false
        if shared._JLActive then shared._JLActive.alive=false end
        pcall(function() fpsConn:Disconnect() end)
        pcall(function() hotkeyConn:Disconnect() end)
        for _,conn in ipairs(gridConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(gridConnections)
        pcall(function()
            local LT2=game:GetService("Lighting")
            local b=LT2:FindFirstChildOfClass("BlurEffect")
            if b then b:Destroy() end
        end)
        if sg and sg.Parent then sg:Destroy() end
        if _cpSg then _cpSg=nil end
    end

    local Win={}
    function Win:Tab(topts)
        topts=topts or {}; local typ=topts.Type or "Grid"; _tabCount=_tabCount+1; local id=_tabCount
        local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,26,0,26); btn.BackgroundColor3=Color3.fromRGB(24,24,34); btn.Text=""; btn.ZIndex=13; btn.Parent=sidebar; corner(6,btn)
        local ic=mkIcon(btn,topts.Icon or "◼",16,14); ic.Position=UDim2.new(0.5,-8,0.5,-8); ic.Size=UDim2.new(0,16,0,16)
        tabBtns[id]=btn
        local tabFrame=Instance.new("Frame"); tabFrame.Size=UDim2.new(1,0,1,0); tabFrame.Position=UDim2.new(0,0,0,0); tabFrame.BackgroundTransparency=1; tabFrame.ZIndex=12; tabFrame.Visible=false; tabFrame.Parent=content
        tabFrames[id]=tabFrame
        btn.MouseButton1Click:Connect(function() switchToTab(id) end)
        if not activeTabId then activeTabId=id; tabFrame.Visible=true; btn.BackgroundColor3=Color3.fromRGB(18,36,62) end
        local scroll=Instance.new("ScrollingFrame"); scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=ACCENTS[1]; scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.ZIndex=12; scroll.Parent=tabFrame; pad(0,2,34,8,scroll)
        local Tab={}
        if typ=="Grid" then
            -- Grid 2.0:
            -- * 3 columns remain the default visual layout.
            -- * Numeric columns 1,2,3... are supported.
            -- * left/mid/right remain backwards-compatible aliases.
            -- * Each column has a minimum readable width.
            -- * The grid can scroll both vertically and horizontally.
            local gap=10
            local MIN_CW=188
            local colCon=Instance.new("Frame")
            colCon.Size=UDim2.new(0,0,0,0)
            colCon.BackgroundTransparency=1
            colCon.ZIndex=12
            colCon.Parent=scroll

            scroll.ScrollingDirection=Enum.ScrollingDirection.XY
            scroll.ScrollingEnabled=true
            scroll.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable

            local columns={}
            local layouts={}
            local orders={}
            local columnCount=0
            local dirty=false

            local function resolveColumn(value)
                if value==nil then return 1 end
                if value=="left" then return 1 end
                if value=="mid" or value=="center" then return 2 end
                if value=="right" then return 3 end
                local n=tonumber(value)
                if n and n>=1 then return math.floor(n) end
                return 1
            end

            local function ensureColumn(index)
                index=math.max(1,math.floor(index))
                if columns[index] then return columns[index] end

                columnCount=math.max(columnCount,index)
                local col=Instance.new("Frame")
                col.Name="GridColumn"..index
                col.BackgroundTransparency=1
                col.Size=UDim2.new(0,MIN_CW,0,0)
                col.ZIndex=12
                col.Parent=colCon

                local layout=Instance.new("UIListLayout")
                layout.FillDirection=Enum.FillDirection.Vertical
                layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
                layout.Padding=UDim.new(0,gap)
                layout.SortOrder=Enum.SortOrder.LayoutOrder
                layout.Parent=col

                columns[index]=col
                layouts[index]=layout
                orders[index]=0

                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    dirty=true
                end)

                return col
            end

            local function rebuild()
                if not scroll.Parent then return end

                local visibleWidth=math.max(scroll.AbsoluteSize.X-4,MIN_CW*3+gap*2)
                local cw=math.max(MIN_CW,math.floor((visibleWidth-gap*2)/3))
                local maxHeight=0

                for i=1,columnCount do
                    local col=columns[i]
                    local layout=layouts[i]
                    if col and layout then
                        local h=layout.AbsoluteContentSize.Y
                        col.Size=UDim2.new(0,cw,0,h)
                        col.Position=UDim2.new(0,(i-1)*(cw+gap),0,0)
                        maxHeight=math.max(maxHeight,h)
                    end
                end

                local totalWidth=math.max(visibleWidth,columnCount*cw+math.max(0,columnCount-1)*gap)
                colCon.Size=UDim2.new(0,totalWidth,0,maxHeight+14)
                scroll.CanvasSize=UDim2.new(0,totalWidth,0,maxHeight+14)
                dirty=false
            end

            local gridConn=scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(rebuild)
            table.insert(gridConnections,gridConn)

            for i=1,3 do ensureColumn(i) end
            task.defer(rebuild)

            local function makeGridSection(sopts)
                sopts=sopts or {}
                local index=resolveColumn(sopts.Column)
                local col=ensureColumn(index)
                orders[index]=(orders[index] or 0)+1
                task.defer(rebuild)
                return makeSection(col,sopts.Title or "Section",sg,orders[index],"Grid")
            end

            function Tab:Section(sopts)
                return makeGridSection(sopts)
            end

            function Tab:Column(index)
                local n=resolveColumn(index)
                ensureColumn(n)
                return {
                    Section=function(_,sopts)
                        sopts=sopts or {}
                        sopts.Column=n
                        return makeGridSection(sopts)
                    end
                }
            end

            -- A single lightweight scheduler handles content changes and is
            -- disconnected when the hub is destroyed.
            local scheduler=RunSvc.Heartbeat:Connect(function()
                if dirty then rebuild() end
            end)
            table.insert(gridConnections,scheduler)

        elseif typ=="Settings" then
            -- Settings 3.0: a real dashboard. Cards are placed into
            -- independent columns instead of UIGridLayout, so their heights
            -- never collapse or overlap on mobile/desktop.
            local root=Instance.new("Frame")
            root.Size=UDim2.new(1,0,0,0)
            root.BackgroundTransparency=1
            root.Parent=scroll

            local columns={}
            local columnLists={}
            local cards={}

            local function makeColumn(index)
                local c=Instance.new("Frame")
                c.BackgroundTransparency=1
                c.ZIndex=13
                c.Parent=root
                columns[index]=c

                local l=Instance.new("UIListLayout")
                l.FillDirection=Enum.FillDirection.Vertical
                l.Padding=UDim.new(0,10)
                l.SortOrder=Enum.SortOrder.LayoutOrder
                l.Parent=c
                columnLists[index]=l
                return c
            end

            for i=1,3 do makeColumn(i) end

            local function card(parent,title,kicker,height,accent)
                local f=Instance.new("Frame")
                f.Size=UDim2.new(1,0,0,height)
                f.BackgroundColor3=C.panel
                f.BorderSizePixel=0
                f.ZIndex=13
                f.Parent=parent
                corner(12,f)
                stroke(C.border,1,f)

                local stripe=Instance.new("Frame")
                stripe.Size=UDim2.new(0,3,0,34)
                stripe.Position=UDim2.new(0,0,0,14)
                stripe.BackgroundColor3=accent or ACCENTS[1]
                stripe.BorderSizePixel=0
                stripe.ZIndex=16
                stripe.Parent=f
                corner(2,stripe)

                newTxt({
                    Parent=f,Text=kicker or "SETTINGS",
                    Font=Enum.Font.GothamBold,Size=8,Color=C.dim,
                    Sz=UDim2.new(1,-30,0,12),Pos=UDim2.new(0,15,0,10),Z=16
                })

                local host=textHost(f,15,22,100,20,16)
                host.Size=UDim2.new(1,-30,0,22)
                longText(f,title,{
                    Host=host,Size=13,Z=16,TextMode="Scroll"
                })

                table.insert(cards,f)
                return f
            end

            local function switch(parent,y,name,flag,default)
                local row=Instance.new("TextButton")
                row.Size=UDim2.new(1,-20,0,34)
                row.Position=UDim2.new(0,10,0,y)
                row.BackgroundColor3=C.btnBg
                row.Text=""
                row.ZIndex=16
                row.Parent=parent
                corner(8,row)

                local host=textHost(row,10,0,100,34,17)
                host.Size=UDim2.new(1,-55,1,0)
                longText(row,name,{
                    Host=host,Size=11,Z=17,TextMode="Scroll"
                })

                local state=cfgGet(flag,default)
                local sw=Instance.new("Frame")
                sw.Size=UDim2.new(0,34,0,18)
                sw.Position=UDim2.new(1,-43,0.5,-9)
                sw.BackgroundColor3=state and ACCENTS[1] or C.togOff
                sw.BorderSizePixel=0
                sw.ZIndex=18
                sw.Parent=row
                corner(9,sw)

                local knob=Instance.new("Frame")
                knob.Size=UDim2.new(0,14,0,14)
                knob.Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)
                knob.BackgroundColor3=Color3.new(1,1,1)
                knob.BorderSizePixel=0
                knob.ZIndex=19
                knob.Parent=sw
                corner(7,knob)

                row.MouseButton1Click:Connect(function()
                    state=not state
                    cfgSet(flag,state)
                    if flag=="_showfps" then fpsL.Visible=state end
                    if flag=="_blurEnabled" then
                        local LT=game:GetService("Lighting")
                        local be=LT:FindFirstChildOfClass("BlurEffect")
                        if state and (cfgGet("_blur",0) or 0)>0 then
                            if not be then be=Instance.new("BlurEffect"); be.Parent=LT end
                            be.Size=math.round((cfgGet("_blur",0) or 0)*56/100)
                            be.Enabled=JL._winOpen
                        elseif be then
                            be.Enabled=false
                        end
                    end
                    tw(sw,{BackgroundColor3=state and ACCENTS[1] or C.togOff},.14)
                    tw(knob,{Position=state and UDim2.new(1,-16,0.5,-7) or UDim2.new(0,2,0.5,-7)},.14)
                end)
            end

            local function action(parent,y,name,callback,destructive)
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(1,-20,0,34)
                b.Position=UDim2.new(0,10,0,y)
                b.BackgroundColor3=destructive and Color3.fromRGB(100,45,48) or C.btnBg
                b.Text=""
                b.ZIndex=16
                b.Parent=parent
                corner(8,b)
                stroke(C.border,1,b)

                longText(b,name,{
                    Host=textHost(b,10,0,100,34,17),
                    Size=11,XAlign=Enum.TextXAlignment.Center,
                    Z=17,TextMode="Scroll"
                })

                b.MouseEnter:Connect(function()
                    tw(b,{BackgroundColor3=destructive and Color3.fromRGB(125,55,58) or C.btnHov},.1)
                end)
                b.MouseLeave:Connect(function()
                    tw(b,{BackgroundColor3=destructive and Color3.fromRGB(100,45,48) or C.btnBg},.1)
                end)
                b.MouseButton1Click:Connect(callback)
            end

            -- LEFT: interface / appearance
            local left=columns[1]
            local interface=card(left,"Interface","APPEARANCE",126,ACCENTS[1])
            switch(interface,44,"Show FPS","_showfps",true)
            switch(interface,82,"Interface blur","_blurEnabled",(cfgGet("_blur",0) or 0)>0)

            local appearance=card(left,"Display","APPEARANCE",108,ACCENTS[2])
            newTxt({
                Parent=appearance,Text="Compact controls, readable spacing",
                Font=Enum.Font.Gotham,Size=10,Color=C.dim,
                Sz=UDim2.new(1,-20,0,18),Pos=UDim2.new(0,10,0,45),Z=16
            })
            action(appearance,68,"Reset Interface",function()
                cfgSet("_blur",0)
                cfgSet("_blurEnabled",false)
                local b=game:GetService("Lighting"):FindFirstChildOfClass("BlurEffect")
                if b then b.Enabled=false end
            end,false)

            -- CENTER: layout / floating badge
            local center=columns[2]
            local badge=card(center,"Floating Badge","LAYOUT",194,ACCENTS[3])
            newTxt({
                Parent=badge,Text="POSITION",
                Font=Enum.Font.GothamBold,Size=8,Color=C.dim,
                Sz=UDim2.new(1,-20,0,14),Pos=UDim2.new(0,10,0,44),Z=16
            })

            local positions={{"Top","top"},{"Center","center"},{"Bottom","bottom"}}
            for i,item in ipairs(positions) do
                local b=Instance.new("TextButton")
                b.Size=UDim2.new(1,-20,0,32)
                b.Position=UDim2.new(0,10,0,62+(i-1)*39)
                b.BackgroundColor3=(cfgGet("_badgepos","top")==item[2]) and Color3.fromRGB(18,36,62) or C.btnBg
                b.Text=item[1]
                b.Font=Enum.Font.GothamBold
                b.TextSize=10
                b.TextColor3=C.txt
                b.ZIndex=16
                b.Parent=badge
                corner(8,b)

                b.MouseButton1Click:Connect(function()
                    cfgSet("_badgepos",item[2])
                    tw(badge2,{Position=BPOS[item[2]]},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
                    for _,ch in ipairs(badge:GetChildren()) do
                        if ch:IsA("TextButton") then ch.BackgroundColor3=C.btnBg end
                    end
                    b.BackgroundColor3=Color3.fromRGB(18,36,62)
                end)
            end

            -- RIGHT: effects / session
            local right=columns[3]
            local blur=card(right,"Blur Amount","EFFECTS",116,ACCENTS[4])
            local blurValue=cfgGet("_blur",0) or 0
            local valLbl=newTxt({
                Parent=blur,Text=tostring(math.round(blurValue)).."%",
                Font=Enum.Font.GothamBold,Size=11,Color=C.txt,
                XAlign=Enum.TextXAlignment.Right,
                Sz=UDim2.new(0,45,0,18),Pos=UDim2.new(1,-55,0,44),Z=16
            })

            local track=Instance.new("TextButton")
            track.Size=UDim2.new(1,-30,0,8)
            track.Position=UDim2.new(0,15,0,76)
            track.BackgroundColor3=C.slTrack
            track.Text=""
            track.ZIndex=16
            track.Parent=blur
            corner(4,track)

            local fill=Instance.new("Frame")
            fill.Size=UDim2.new(blurValue/100,0,1,0)
            fill.BackgroundColor3=ACCENTS[4]
            fill.BorderSizePixel=0
            fill.ZIndex=17
            fill.Parent=track
            corner(4,fill)

            local drag=false
            local function setBlur(v)
                blurValue=math.clamp(math.round(v),0,100)
                cfgSet("_blur",blurValue)
                valLbl.Text=tostring(blurValue).."%"
                fill.Size=UDim2.new(blurValue/100,0,1,0)

                local LT=game:GetService("Lighting")
                local b=LT:FindFirstChildOfClass("BlurEffect")
                if blurValue>0 then
                    if not b then b=Instance.new("BlurEffect"); b.Parent=LT end
                    b.Size=math.round(blurValue*56/100)
                    b.Enabled=JL._winOpen and (cfgGet("_blurEnabled",true)~=false)
                elseif b then
                    b.Enabled=false
                end
            end

            local blurBegan=track.InputBegan:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                    drag=true
                    setBlur((i.Position.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X)*100)
                end
            end)
            local blurChanged=UIS.InputChanged:Connect(function(i)
                if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                    setBlur((i.Position.X-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X)*100)
                end
            end)
            local blurEnded=UIS.InputEnded:Connect(function(i)
                if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
            end)
            table.insert(gridConnections,blurBegan)
            table.insert(gridConnections,blurChanged)
            table.insert(gridConnections,blurEnded)

            local session=card(right,"Library","SESSION",160,ACCENTS[5])
            newTxt({
                Parent=session,Text="JustXLibrary",
                Font=Enum.Font.GothamBold,Size=12,Color=C.txt,
                Sz=UDim2.new(1,-20,0,18),Pos=UDim2.new(0,10,0,44),Z=16
            })
            newTxt({
                Parent=session,Text="Grid 2.0 • Dashboard",
                Font=Enum.Font.Gotham,Size=10,Color=C.dim,
                Sz=UDim2.new(1,-20,0,18),Pos=UDim2.new(0,10,0,64),Z=16
            })
            action(session,92,"Reset Badge Position",function()
                cfgSet("_badgepos","top")
                tw(badge2,{Position=BPOS.top},.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
            end,false)
            action(session,130,"Unload JustXLibrary",function()
                local sure=confirmDialog("Unload Library","This will completely remove the current hub.")
                if sure then destroyHub() end
            end,true)

            local function layoutSettings()
                local width=math.max(280,scroll.AbsoluteSize.X-4)
                local cols=(width>=650 and 3) or (width>=430 and 2) or 1
                local gap=10
                local cw=math.floor((width-gap*(cols-1))/cols)

                for i=1,3 do
                    local c=columns[i]
                    if i<=cols then
                        c.Visible=true
                        c.Size=UDim2.new(0,cw,0,0)
                        c.Position=UDim2.new(0,(i-1)*(cw+gap),0,0)
                    else
                        c.Visible=false
                    end
                end

                local heights={}
                for i=1,cols do
                    heights[i]=columnLists[i].AbsoluteContentSize.Y
                end

                local maxH=0
                for i=1,cols do maxH=math.max(maxH,heights[i] or 0) end
                root.Size=UDim2.new(0,width,0,maxH+12)
                scroll.CanvasSize=UDim2.new(0,width,0,maxH+24)
            end

            for _,l in ipairs(columnLists) do
                local con=l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(layoutSettings)
                table.insert(gridConnections,con)
            end
            local settingsResize=scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutSettings)
            table.insert(gridConnections,settingsResize)

            task.defer(layoutSettings)
            function Tab:Section()
                error("Settings tabs use the built-in dashboard.",2)
            end
        else
            local listCon=Instance.new("Frame")
            listCon.Size=UDim2.new(1,0,0,0)
            listCon.BackgroundTransparency=1
            listCon.ZIndex=12
            listCon.Parent=scroll

            local listL=Instance.new("UIListLayout")
            listL.FillDirection=Enum.FillDirection.Vertical
            listL.Padding=UDim.new(0,10)
            listL.SortOrder=Enum.SortOrder.LayoutOrder
            listL.Parent=listCon

            listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                listCon.Size=UDim2.new(1,0,0,listL.AbsoluteContentSize.Y+14)
                scroll.CanvasSize=UDim2.new(0,0,0,listL.AbsoluteContentSize.Y+14)
            end)

            local _sOrd=0
            function Tab:Section(sopts)
                sopts=sopts or {}
                _sOrd+=1
                return makeSection(listCon,sopts.Title or "Section",sg,_sOrd)
            end
        end
        return Tab
    end
    function Win:Settings()
        return self:Tab({Icon="⚙",Type="Settings"})
    end
    shared._JLActive={alive=true, destroy=destroyHub}
    return Win
end
return JL
