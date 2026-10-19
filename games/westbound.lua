-- Loaded only in Westbound by Honey Bun Hub's loader.lua.
-- Client-side visuals only: no hitbox or character properties are changed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
-- Read only explicit bounty fields exposed to this client; missing is not zero.
local function bountyAmount(player)
    local function number(value)
        if type(value)=="string" then value=tonumber((value:gsub("[$,]",""))) end
        if type(value)=="number" and value==value and value>=0 and value<math.huge then return math.floor(value) end
    end
    local amount=number(player:GetAttribute("Bounty"))
    if amount then return amount end
    local stats=player:FindFirstChild("leaderstats")
    local value=stats and stats:FindFirstChild("Bounty") or player:FindFirstChild("Bounty")
    if value and (value:IsA("IntValue") or value:IsA("NumberValue") or value:IsA("StringValue")) then
        return number(value.Value)
    end
end
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
        local s = {enabled=false,cowboys=true,outlaws=true,others=true,labels=true,names=true,distance=true,health=true,bounty=false,tracers=false,chams=false,hitbox=false,visibleOnly=false,maxDistance=math.huge,teamMode="All",style="Labels"}
        local env=type(getgenv)=="function" and getgenv() or _G
        if type(env.__HoneyBunHubSettings)~="table" then env.__HoneyBunHubSettings={} end
        local gameKey=tostring(game.GameId or 0)
        if type(env.__HoneyBunHubSettings[gameKey])~="table" then env.__HoneyBunHubSettings[gameKey]={} end
        local saved=env.__HoneyBunHubSettings[gameKey]
        local settingsAttribute="HoneyBunPlayerSettings_"..gameKey
        local http=game:GetService("HttpService")
        local ok,stored=pcall(function()
            local encoded=playerGui:GetAttribute(settingsAttribute)
            return type(encoded)=="string" and http:JSONDecode(encoded) or nil
        end)
        if ok and type(stored)=="table" then saved.player=stored end
        if type(saved.player)=="table" then
            for key,default in pairs(s) do
                if type(saved.player[key])==type(default) then s[key]=saved.player[key] end
            end
        end
        local choices, choiceIndex = {500,1000,2500,math.huge}, 4
        local validDistance=false
        for index,value in ipairs(choices) do if s.maxDistance==value then choiceIndex=index;validDistance=true end end
        if not validDistance then s.maxDistance=math.huge end
        if s.teamMode~="All" and s.teamMode~="Cowboys" and s.teamMode~="Outlaws" then s.teamMode="All" end
        if s.style~="Labels" and s.style~="Outline" and s.style~="Full" then s.style="Labels" end
        s.cowboys=s.teamMode=="All" or s.teamMode=="Cowboys"
        s.outlaws=s.teamMode=="All" or s.teamMode=="Outlaws";s.others=s.teamMode=="All"
        local advancedOpen=type(saved.player)=="table" and saved.player.advancedOpen==true
        saved.player=s
        s.advancedOpen=advancedOpen
        local function saveSettings()
            local snapshot={}
            for key,value in pairs(s) do snapshot[key]=value end
            if snapshot.maxDistance==math.huge then snapshot.maxDistance="Unlimited" end
            pcall(function() playerGui:SetAttribute(settingsAttribute,http:JSONEncode(snapshot)) end)
        end
        local colors = {Cowboys=Color3.fromRGB(75,145,235),Outlaws=Color3.fromRGB(220,75,75),Other=Color3.fromRGB(165,165,165)}
        local connections, records, ownedRows, advancedRows, advancedControls, dead = {}, {}, {}, {}, {}, false
        local nextOrder = 1
        local worldCleanup
        local overlay = Instance.new("ScreenGui")
        overlay.Name,overlay.IgnoreGuiInset,overlay.ResetOnSpawn,overlay.DisplayOrder = "HoneyBunWestboundESP",true,false,20
        overlay.Parent = playerGui
        local function connect(signal, fn)
            local c = signal:Connect(fn); table.insert(connections,c); return c
        end
        local function row(labelText, initial, set, toggle)
            local frame = Instance.new("Frame")
            frame.Size,frame.LayoutOrder,frame.BackgroundTransparency,frame.Parent = UDim2.new(1,0,0,28),nextOrder,1,contentFrame
            nextOrder = nextOrder + 1
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
                initial=item.Text~="ON"; set(initial); paint(initial); saveSettings()
            end)
            return item
        end
        local function cycleRow(labelText, values, current, set)
            local frame = Instance.new("Frame")
            frame.Size,frame.LayoutOrder,frame.BackgroundTransparency,frame.Parent = UDim2.new(1,0,0,28),nextOrder,1,contentFrame
            nextOrder = nextOrder + 1
            table.insert(ownedRows, frame)
            text(frame,labelText,UDim2.new(1,-124,1,0),Color3.fromRGB(190,190,190),11)
            local item = button(frame,current)
            item.AnchorPoint,item.Position = Vector2.new(1,.5),UDim2.new(1,0,.5,0)
            connect(item.Activated,function()
                local index=1
                for i,value in ipairs(values) do if value==item.Text then index=i; break end end
                index=index%#values+1
                item.Text=values[index]; set(values[index]); saveSettings()
            end)
            return item
        end
        local heading = Instance.new("Frame")
        heading.Size,heading.LayoutOrder,heading.BackgroundTransparency,heading.Parent = UDim2.new(1,0,0,28),0,1,contentFrame
        table.insert(ownedRows, heading)
        text(heading,"PLAYERS",UDim2.new(1,0,1,0),Color3.fromRGB(235,235,235),13)
        local syncAdvanced
        row("Player ESP",s.enabled,function(v)s.enabled=v end)
        cycleRow("Team filter",{"All","Cowboys","Outlaws"},s.teamMode,function(v)
            s.teamMode=v; s.cowboys=v=="All" or v=="Cowboys"; s.outlaws=v=="All" or v=="Outlaws"; s.others=v=="All"
        end)
        cycleRow("Style",{"Labels","Outline","Full"},s.style,function(v)
            s.style=v; s.labels=true; s.chams=v=="Outline" or v=="Full"; s.tracers=v=="Full"
            if syncAdvanced then syncAdvanced() end
        end)
        local advancedButton = button(contentFrame,"More player options")
        advancedButton.Size,advancedButton.LayoutOrder = UDim2.new(1,0,0,28),4
        table.insert(ownedRows,advancedButton)
        nextOrder = 5
        advancedButton.Text=advancedOpen and "Fewer player options" or "More player options"
        local function advancedRow(key, labelText, initial, set)
            local item=row(labelText,initial,set)
            local frame=item.Parent; frame.Visible=advancedOpen; table.insert(advancedRows,frame)
            advancedControls[key]=item
            return item
        end
        advancedRow("labels","Labels",s.labels,function(v)s.labels=v end)
        advancedRow("names","Names",s.names,function(v)s.names=v end)
        advancedRow("distance","Distance",s.distance,function(v)s.distance=v end)
        advancedRow("health","Health",s.health,function(v)s.health=v end)
        advancedRow("bounty","Outlaw bounty",s.bounty,function(v)s.bounty=v end)
        advancedRow("tracers","Tracers",s.tracers,function(v)s.tracers=v end)
        advancedRow("chams","Chams",s.chams,function(v)s.chams=v end)
        advancedRow("hitbox","Visual hitbox",s.hitbox,function(v)s.hitbox=v end)
        advancedRow("visibleOnly","Visible only",s.visibleOnly,function(v)s.visibleOnly=v end)
        local distanceButton = row("Max distance",true,function() end,false)
        local distanceFrame = distanceButton.Parent
        distanceFrame.Visible = advancedOpen
        table.insert(advancedRows,distanceFrame)
        distanceButton.Text = s.maxDistance==math.huge and "Unlimited" or (tostring(s.maxDistance).." studs")
        connect(distanceButton.Activated,function()
            choiceIndex = choiceIndex % #choices + 1; s.maxDistance = choices[choiceIndex]
            distanceButton.Text = s.maxDistance == math.huge and "Unlimited" or (tostring(s.maxDistance).." studs")
            saveSettings()
        end)
        syncAdvanced=function()
            for key,item in pairs(advancedControls) do
                local value=s[key]; item.Text=value and "ON" or "OFF"
                item.TextColor3=value and Color3.fromRGB(240,240,240) or Color3.fromRGB(135,135,135)
                item.BackgroundColor3=value and Color3.fromRGB(58,58,58) or Color3.fromRGB(34,34,34)
            end
        end
        connect(advancedButton.Activated,function()
            advancedOpen=not advancedOpen; advancedButton.Text=advancedOpen and "Fewer player options" or "More player options"
            s.advancedOpen=advancedOpen
            syncAdvanced()
            for _,frame in ipairs(advancedRows) do frame.Visible=advancedOpen end
            saveSettings()
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
            record.name.Visible,record.tracer.Visible,record.selection.Visible = false,false,false
            record.highlight.Enabled = false
        end
        local function bind(record, character)
            record.character,record.humanoid,record.root,record.isVisible = character,character and character:FindFirstChildOfClass("Humanoid"),character and character:FindFirstChild("HumanoidRootPart"),nil
            record.highlight.Adornee,record.selection.Adornee = character,record.root; hide(record)
        end
        local function add(player)
            if player==localPlayer or records[player] then return end
            local record = {player=player,isVisible=nil,name=text(overlay,"",UDim2.fromOffset(240,20),Color3.new(1,1,1),12),tracer=Instance.new("Frame"),highlight=Instance.new("Highlight"),selection=Instance.new("SelectionBox")}
            record.name.AnchorPoint,record.name.TextXAlignment = Vector2.new(.5,1),Enum.TextXAlignment.Center
            record.name.TextStrokeColor3,record.name.TextStrokeTransparency = Color3.new(0,0,0),0.35
            record.tracer.BorderSizePixel,record.tracer.AnchorPoint,record.tracer.BackgroundColor3,record.tracer.Size = 0,Vector2.new(.5,.5),Color3.fromRGB(180,180,180),UDim2.fromOffset(0,1)
            record.tracer.Parent,record.name.Parent = overlay,overlay
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
            for _,object in ipairs({record.name,record.tracer,record.highlight,record.selection}) do object:Destroy() end
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
            local midpoint=(fromPoint+toPoint)/2
            frame.Position,frame.Size,frame.Rotation=UDim2.fromOffset(midpoint.X,midpoint.Y),UDim2.fromOffset(delta.Magnitude,1),math.deg(math.atan2(delta.Y,delta.X))
        end
        local function update(record,camera,viewport,heavy)
            local character=record.player.Character
            if character ~= record.character then bind(record,character) end
            if not character or not character.Parent then hide(record); return end
            local root=character and character:FindFirstChild("HumanoidRootPart")
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            record.root,record.humanoid=root,humanoid
            if not s.enabled or not character or not root or not humanoid or humanoid.Health<=0 then hide(record); return end
            local distance,team=(camera.CFrame.Position-root.Position).Magnitude,kind(record.player)
            if distance>s.maxDistance or not allowed(team) then hide(record); return end
            if s.visibleOnly then
                if heavy or record.isVisible == nil then record.isVisible=visible(character,root,camera) end
                if not record.isVisible then hide(record); return end
            else
                record.isVisible=true
            end
            local color,rootPoint=colors[team],camera:WorldToViewportPoint(root.Position)
            if rootPoint.Z<=0 then hide(record); return end
            record.name.Visible=s.labels and (s.names or s.distance or s.health or (s.bounty and team=="Outlaws"))
            if record.name.Visible then
                local parts={}; if s.names then table.insert(parts,(record.player.DisplayName or record.player.Name).." ["..team.."]") end
                if s.distance then table.insert(parts,string.format("[%d]",math.floor(distance))) end; if s.health then table.insert(parts,string.format("HP %d",math.floor(humanoid.Health))) end
                if s.bounty and team=="Outlaws" then
                    if heavy or not record.bountyChecked then
                        record.bounty=bountyAmount(record.player); record.bountyChecked=true
                    end
                    table.insert(parts,record.bounty and string.format("\nBounty $%d",record.bounty) or "\nBounty unavailable")
                end
                record.name.Size=UDim2.fromOffset(320,s.bounty and team=="Outlaws" and 36 or 20)
                record.name.Text,record.name.TextColor3=table.concat(parts,"  "),color; record.name.Position=UDim2.fromOffset(rootPoint.X,rootPoint.Y-28)
            end
            record.tracer.Visible=s.tracers; record.tracer.BackgroundColor3=color
            if record.tracer.Visible then setTracer(record.tracer,Vector2.new(viewport.X/2,viewport.Y),Vector2.new(rootPoint.X,rootPoint.Y)) end
            record.highlight.Enabled,record.highlight.FillColor,record.highlight.OutlineColor=s.chams,color,color
            record.selection.Visible,record.selection.Adornee=s.hitbox,record.root
        end
        local elapsed,heavyElapsed=0,0
        connect(RunService.RenderStepped,function(delta)
            if dead then return end; elapsed=elapsed+delta; heavyElapsed=heavyElapsed+delta
            local camera=workspace.CurrentCamera
            if not camera then for _,record in pairs(records) do hide(record) end; return end
            local viewport=camera.ViewportSize
            local heavy=heavyElapsed>=.15; if heavy then heavyElapsed=0 end
            for _,record in pairs(records) do
                update(record,camera,viewport,heavy)
            end
        end)
        local cleanup
        cleanup=function()
            if dead then return end; dead=true
            saveSettings()
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
        saveSettings()
        return cleanup
    end,
}
