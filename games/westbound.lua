-- Loaded only in Westbound by Honey Bun Hub's loader.lua.
-- Client-side visuals only: no hitbox or character properties are changed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local worldMount, worldError
do
    local ok, result = pcall(function()
        local url = "https://raw.githubusercontent.com/noahkcarmstrong-ops/honey-bun-hub/main/games/world.lua?refresh=" .. tostring(DateTime.now().UnixTimestampMillis)
        local chunk, message = loadstring(game:HttpGet(url, false))
        assert(chunk, message)
        return chunk()
    end)
    if ok and type(result) == "function" then worldMount = result else worldError = result end
end

local function text(parent, value, size, color, fontSize)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size, label.Font, label.Text = size, Enum.Font.Gotham, value
    label.TextColor3, label.TextSize, label.TextXAlignment = color, fontSize or 12, Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function button(parent, value)
    local item = Instance.new("TextButton")
    item.Size, item.BackgroundColor3, item.BorderSizePixel = UDim2.fromOffset(112, 28), Color3.fromRGB(34, 34, 34), 0
    item.Font, item.TextColor3, item.TextSize, item.Text = Enum.Font.GothamMedium, Color3.fromRGB(215, 215, 215), 11, value
    item.Parent = parent
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 5)
    return item
end

return {
    name = "WESTBOUND",
    description = "Player ESP and visual hitbox helpers for Westbound.",
    mount = function(contentFrame)
        local localPlayer, playerGui = Players.LocalPlayer, Players.LocalPlayer:WaitForChild("PlayerGui")
        local old = playerGui:FindFirstChild("HoneyBunWestboundESP")
        if old then old:Destroy() end
        local s = {enabled=false,cowboys=true,outlaws=true,others=true,labels=true,names=true,distance=true,health=true,tracers=false,boxes=false,chams=false,hitbox=false,visibleOnly=false,maxDistance=1000}
        local choices, choiceIndex = {500,1000,2500,math.huge}, 2
        local colors = {Cowboys=Color3.fromRGB(75,145,235),Outlaws=Color3.fromRGB(220,75,75),Other=Color3.fromRGB(165,165,165)}
        local connections, records, ownedRows, dead = {}, {}, {}, false
        local worldCleanup
        local overlay = Instance.new("ScreenGui")
        overlay.Name,overlay.IgnoreGuiInset,overlay.ResetOnSpawn,overlay.DisplayOrder = "HoneyBunWestboundESP",true,false,20
        overlay.Parent = playerGui
        local function connect(signal, fn)
            local c = signal:Connect(fn); table.insert(connections,c); return c
        end
        local function row(labelText, initial, set, toggle)
            local frame = Instance.new("Frame")
            frame.Size,frame.BackgroundTransparency,frame.Parent = UDim2.new(1,0,0,32),1,contentFrame
            table.insert(ownedRows, frame)
            text(frame,labelText,UDim2.new(1,-124,1,0),Color3.fromRGB(190,190,190),11)
            local item = button(frame,"OFF")
            item.AnchorPoint,item.Position = Vector2.new(1,.5),UDim2.new(1,0,.5,0)
            local function paint(value)
                item.Text = value and "ON" or "OFF"
                item.TextColor3 = value and Color3.fromRGB(240,240,240) or Color3.fromRGB(135,135,135)
                item.BackgroundColor3 = value and Color3.fromRGB(58,58,58) or Color3.fromRGB(34,34,34)
            end
            paint(initial)
            connect(item.Activated,function()
                if toggle == false then set(initial); return end
                initial=not initial; set(initial); paint(initial)
            end)
            return item
        end
        local heading = Instance.new("Frame")
        heading.Size,heading.BackgroundTransparency,heading.Parent = UDim2.new(1,0,0,30),1,contentFrame
        table.insert(ownedRows, heading)
        text(heading,"WESTBOUND ESP",UDim2.new(1,0,1,0),Color3.fromRGB(235,235,235),13)
        local legend = Instance.new("Frame")
        legend.Size,legend.BackgroundTransparency,legend.Parent = UDim2.new(1,0,0,30),1,contentFrame
        table.insert(ownedRows, legend)
        local status = text(legend,"Blue Cowboys (0)  •  Red Outlaws (0)  •  Other (0)",UDim2.new(1,0,1,0),Color3.fromRGB(120,120,120),10)
        row("Master ESP",s.enabled,function(v)s.enabled=v end)
        row("Cowboys",s.cowboys,function(v)s.cowboys=v end)
        row("Outlaws",s.outlaws,function(v)s.outlaws=v end)
        row("Other teams",s.others,function(v)s.others=v end)
        row("Labels",s.labels,function(v)s.labels=v end)
        row("Names",s.names,function(v)s.names=v end)
        row("Distance",s.distance,function(v)s.distance=v end)
        row("Health",s.health,function(v)s.health=v end)
        row("Tracers",s.tracers,function(v)s.tracers=v end)
        row("2D boxes",s.boxes,function(v)s.boxes=v end)
        row("Chams",s.chams,function(v)s.chams=v end)
        row("Visual hitbox",s.hitbox,function(v)s.hitbox=v end)
        row("Visible only",s.visibleOnly,function(v)s.visibleOnly=v end)
        local distanceButton = row("Max distance",true,function() end,false)
        distanceButton.Text = "1000 studs"
        connect(distanceButton.Activated,function()
            choiceIndex = choiceIndex % #choices + 1; s.maxDistance = choices[choiceIndex]
            distanceButton.Text = s.maxDistance == math.huge and "Unlimited" or (tostring(s.maxDistance).." studs")
        end)

        local function kind(player)
            local name = player.Team and string.lower(player.Team.Name) or ""
            if string.find(name,"cowboy",1,true) then return "Cowboys" end
            if string.find(name,"outlaw",1,true) then return "Outlaws" end
            return "Other"
        end
        local function allowed(team)
            return (team=="Cowboys" and s.cowboys) or (team=="Outlaws" and s.outlaws) or (team=="Other" and s.others)
        end
        local function hide(record)
            record.name.Visible,record.tracer.Visible,record.box.Visible,record.selection.Visible = false,false,false,false
            record.highlight.Enabled = false
        end
        local function bind(record, character)
            record.character,record.humanoid,record.root = character,character and character:FindFirstChildOfClass("Humanoid"),character and character:FindFirstChild("HumanoidRootPart")
            record.highlight.Adornee,record.selection.Adornee = character,record.root; hide(record)
        end
        local function add(player)
            if player==localPlayer or records[player] then return end
            local record = {player=player,name=text(overlay,"",UDim2.fromOffset(240,20),Color3.new(1,1,1),12),tracer=Instance.new("Frame"),box=Instance.new("Frame"),highlight=Instance.new("Highlight"),selection=Instance.new("SelectionBox")}
            record.name.AnchorPoint,record.name.TextXAlignment = Vector2.new(.5,1),Enum.TextXAlignment.Center
            record.name.TextStrokeColor3,record.name.TextStrokeTransparency = Color3.new(0,0,0),0.35
            record.tracer.BorderSizePixel,record.tracer.AnchorPoint,record.tracer.BackgroundColor3,record.tracer.Size = 0,Vector2.new(0,.5),Color3.fromRGB(180,180,180),UDim2.fromOffset(0,1)
            record.tracer.Parent,record.box.Parent,record.name.Parent = overlay,overlay,overlay
            record.box.BackgroundTransparency,record.box.BorderSizePixel = 1,1
            record.highlight.FillTransparency,record.highlight.OutlineTransparency,record.highlight.DepthMode,record.highlight.Parent = .72,.15,Enum.HighlightDepthMode.AlwaysOnTop,overlay
            record.selection.LineThickness,record.selection.SurfaceTransparency,record.selection.Color3,record.selection.Parent = .04,1,Color3.fromRGB(255,190,70),overlay
            records[player] = record
            record.characterConnection = connect(player.CharacterAdded,function(character)bind(record,character)end)
            if player.Character then bind(record,player.Character) end
        end
        local function remove(player)
            local record=records[player]; if not record then return end
            records[player]=nil
            if record.characterConnection then record.characterConnection:Disconnect() end
            for _,object in ipairs({record.name,record.tracer,record.box,record.highlight,record.selection}) do object:Destroy() end
        end
        for _,player in ipairs(Players:GetPlayers()) do add(player) end
        connect(Players.PlayerAdded,add); connect(Players.PlayerRemoving,remove)
        local function visible(character,root,camera)
            local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
            local filters={camera,character}
            if localPlayer.Character then table.insert(filters,localPlayer.Character) end
            params.FilterDescendantsInstances=filters
            local result=workspace:Raycast(camera.CFrame.Position,root.Position-camera.CFrame.Position,params)
            return result==nil or result.Instance:IsDescendantOf(character)
        end
        local function setTracer(frame,fromPoint,toPoint)
            local delta=toPoint-fromPoint
            frame.Position,frame.Size,frame.Rotation=UDim2.fromOffset(fromPoint.X,fromPoint.Y),UDim2.fromOffset(delta.Magnitude,1),math.deg(math.atan2(delta.Y,delta.X))
        end
        local function update(record,camera,viewport)
            local character=record.player.Character
            if character ~= record.character then bind(record,character) end
            if not character or not character.Parent then hide(record); return end
            local root=character and character:FindFirstChild("HumanoidRootPart")
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            record.root,record.humanoid=root,humanoid
            if not s.enabled or not character or not root or not humanoid or humanoid.Health<=0 then hide(record); return end
            local distance,team=(camera.CFrame.Position-root.Position).Magnitude,kind(record.player)
            if distance>s.maxDistance or not allowed(team) or (s.visibleOnly and not visible(character,root,camera)) then hide(record); return end
            local color,rootPoint=colors[team],camera:WorldToViewportPoint(root.Position)
            if rootPoint.Z<=0 then hide(record); return end
            local boxCf,boxSize=character:GetBoundingBox(); local minX,minY,maxX,maxY=viewport.X,viewport.Y,0,0; local allInFront=true
            for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                local point=camera:WorldToViewportPoint((boxCf*CFrame.new(boxSize.X*x/2,boxSize.Y*y/2,boxSize.Z*z/2)).Position)
                if point.Z<=0 then allInFront=false else minX,minY,maxX,maxY=math.min(minX,point.X),math.min(minY,point.Y),math.max(maxX,point.X),math.max(maxY,point.Y) end
            end end end
            local valid=allInFront and maxX>minX and maxY>minY
            record.name.Visible=s.labels and (s.names or s.distance or s.health)
            if record.name.Visible then
                local parts={}; if s.names then table.insert(parts,(record.player.DisplayName or record.player.Name).." ["..team.."]") end
                if s.distance then table.insert(parts,string.format("[%d]",math.floor(distance))) end; if s.health then table.insert(parts,string.format("HP %d",math.floor(humanoid.Health))) end
                record.name.Text,record.name.TextColor3=table.concat(parts,"  "),color; record.name.Position=UDim2.fromOffset(rootPoint.X,valid and minY-2 or rootPoint.Y-28)
            end
            record.tracer.Visible=s.tracers; record.tracer.BackgroundColor3=color
            if record.tracer.Visible then setTracer(record.tracer,Vector2.new(viewport.X/2,viewport.Y),Vector2.new(rootPoint.X,rootPoint.Y)) end
            record.box.Visible=s.boxes and valid; if record.box.Visible then record.box.Position,record.box.Size,record.box.BorderColor3=UDim2.fromOffset(minX,minY),UDim2.fromOffset(maxX-minX,maxY-minY),color end
            record.highlight.Enabled,record.highlight.FillColor,record.highlight.OutlineColor=s.chams,color,color
            record.selection.Visible,record.selection.Adornee=s.hitbox,record.root
        end
        local elapsed=0
        connect(RunService.RenderStepped,function(delta)
            if dead then return end; elapsed=elapsed+delta; if elapsed<.05 then return end; elapsed=0
            local camera=workspace.CurrentCamera
            if not camera then for _,record in pairs(records) do hide(record) end; return end
            local viewport=camera.ViewportSize; local counts={Cowboys=0,Outlaws=0,Other=0}
            for _,record in pairs(records) do
                local teamName=kind(record.player); counts[teamName]=counts[teamName]+1
                update(record,camera,viewport)
            end
            status.Text = string.format("Blue Cowboys (%d)  •  Red Outlaws (%d)  •  Other (%d)",counts.Cowboys,counts.Outlaws,counts.Other)
        end)
        local cleanup
        cleanup=function()
            if dead then return end; dead=true
            if worldCleanup then worldCleanup() end
            for _,c in ipairs(connections) do c:Disconnect() end
            for player in pairs(records) do remove(player) end
            if overlay then overlay:Destroy() end
            for _,child in ipairs(ownedRows) do if child.Parent then child:Destroy() end end
        end
        connect(contentFrame.Destroying,cleanup)
        if worldMount then
            local ok, result = pcall(worldMount, contentFrame)
            if ok and type(result) == "function" then worldCleanup = result else worldError = result end
        end
        if worldError then
            warn("Honey Bun Hub: world ESP failed to load", worldError)
            local notice = text(contentFrame,"Animal/chest controls unavailable. Refresh to retry.",UDim2.new(1,-8,0,40),Color3.fromRGB(170,170,170),11)
            notice.LayoutOrder, notice.TextWrapped = 100, true
            table.insert(ownedRows,notice)
        end
        return cleanup
    end,
}
