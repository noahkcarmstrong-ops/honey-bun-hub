-- HoneyBunFarmRouteV6
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function mount(contentFrame)
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local gameKey = tostring(game.GameId or 0)
    local modeAttribute = "HoneyBunFarmMode_" .. gameKey
    local moveAttribute = "HoneyBunFarmLastMove_" .. gameKey
    local incidentAttribute = "HoneyBunFarmIncident_" .. gameKey
    local savedMove = playerGui and playerGui:GetAttribute(moveAttribute) or "none"
    local savedIncident = playerGui and playerGui:GetAttribute(incidentAttribute) or "none"
    local lastMoveAt, watchedHumanoid
    local healthWatch, deathWatch
    local mode = playerGui and playerGui:GetAttribute(modeAttribute) or "both"
    if mode ~= "registers" and mode ~= "safes" then mode = "both" end
    local alive, running = true, false
    local stepClock, elapsed = 0, 0
    local activeRoot
    local pending, targetBackoff, scanned, eligible = nil, {}, 0, 0
    local attempts, successes, collectedTotal, failedAttempts, lastFailure = 0, 0, 0, 0, "none"
    local nextAttemptAt = 0
    local deposit, depositTried = nil, {}
    local scout, shopVisits, scoutRequests, lastScout = nil, {}, 0, "none"
    local rejected = {}
    local cashIns, campName = 0, "none"
    local targetFailures = setmetatable({}, {__mode="k"})
    local lastHealth
    local teleports, skippedLandings, lastMovement = 0, 0, "none"
    local connections, owned = {}, {}
    local statusLabel, bagLabel, collectedLabel

    local function saveMode()
        if playerGui then pcall(function() playerGui:SetAttribute(modeAttribute, mode) end) end
    end
    saveMode()

    local function disconnectAll()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end
    local function cleanup()
        if not alive then return end
        alive, running, pending, deposit, scout = false, false, nil, nil, nil
        saveMode()
        disconnectAll()
        if healthWatch then healthWatch:Disconnect() end
        if deathWatch then deathWatch:Disconnect() end
        for _, object in ipairs(owned) do object:Destroy() end
        owned = {}
    end
    table.insert(connections, contentFrame.Destroying:Connect(cleanup))

    local layout = contentFrame:FindFirstChildOfClass("UIListLayout")
    if not layout then
        layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = contentFrame
        table.insert(owned, layout)
    end
    local function row(text, order)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -8, 0, 30)
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        button.BorderSizePixel = 0
        button.TextColor3 = Color3.fromRGB(235, 235, 235)
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.LayoutOrder = order
        button.Text = text
        button.Parent = contentFrame
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 6)
        table.insert(owned, button)
        return button
    end
    local function label(text, order)
        local item = Instance.new("TextLabel")
        item.Size = UDim2.new(1, -8, 0, 22)
        item.BackgroundTransparency = 1
        item.TextColor3 = Color3.fromRGB(170, 170, 170)
        item.Font = Enum.Font.Gotham
        item.TextSize = 11
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.TextWrapped = true
        item.AutomaticSize = Enum.AutomaticSize.Y
        item.LayoutOrder = order
        item.Text = text
        item.Parent = contentFrame
        table.insert(owned, item)
        return item
    end
    label("FARM (experimental; live rewards unverified)", 100)
    statusLabel = label("Stopped", 101)
    bagLabel = label("Bag: unavailable", 102)
    collectedLabel = label("Collected into bag: 0", 103)
    local modeButton = row("Mode: Registers + safes", 104)
    label("Auto camp return when full. Failed targets are skipped; server cooldowns apply.", 105)
    local startButton = row("Start", 106)
    local reportButton = row("Copy farm report", 107)

    local function modeText()
        return mode == "registers" and "Registers" or mode == "safes" and "Safes" or "Registers + safes"
    end
    local function characterRoot()
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        if not root or not humanoid or humanoid.SeatPart or humanoid.Sit or (humanoid.Health and humanoid.Health <= 0) then return nil end
        return root
    end
    local function numberValue(object, name)
        local value = object and object:FindFirstChild(name)
        if value and not (value:IsA("NumberValue") or value:IsA("IntValue")) then return end
        local number = value and value.Value
        if type(number) == "number" and number == number and number < math.huge and number >= 0 then return number end
    end
    local function bagInfo()
        local states = player and player:FindFirstChild("States")
        local stats = player and player:FindFirstChild("Stats")
        local bag = numberValue(states, "Bag")
        local capacityFolder = stats and stats:FindFirstChild("BagSizeLevel")
        local capacity = numberValue(capacityFolder, "CurrentAmount")
        return bag, capacity
    end
    local function validRemote()
        local events = ReplicatedStorage and ReplicatedStorage:FindFirstChild("GeneralEvents")
        local remote = events and events:FindFirstChild("Rob")
        return remote and remote:IsA("RemoteEvent") and remote
    end
    local function validRegister(item)
        if not item:IsA("Model") then return false,"register is not a model" end
        for _, name in ipairs({"Open","Union"}) do
            local part=item:FindFirstChild(name)
            if not part or not part:IsA("BasePart") then return false,"register missing " .. name .. " BasePart" end
        end
        local active=item:FindFirstChild("Active")
        if not active or not active:IsA("BoolValue") then return false,"register missing Active BoolValue" end
        if not active.Value then return false,"register inactive" end
        return true
    end
    local function validSafe(item)
        if not item:IsA("Model") then return false,"safe is not a model" end
        local amount=numberValue(item,"Amount")
        if not amount then return false,"safe Amount unavailable" end
        if amount <= 0 then return false,"safe empty" end
        local open=item:FindFirstChild("Open")
        if not open or not open:IsA("BoolValue") then return false,"safe missing Open BoolValue" end
        local part=item:FindFirstChild("Safe")
        if not part or not part:IsA("BasePart") then return false,"safe missing Safe BasePart" end
        local remote=item:FindFirstChild("OpenSafe")
        if not open.Value and (not remote or not remote:IsA("RemoteEvent")) then return false,"closed safe missing OpenSafe RemoteEvent" end
        return true
    end
    local function isTarget(item, kind)
        if kind == "register" then return validRegister(item) end
        if kind == "safe" then return validSafe(item) end
        return false,"unknown target type"
    end
    local function scan()
        scanned, eligible = 0, 0
        rejected={}
        local targets = {}
        for _, item in ipairs(workspace:GetDescendants()) do
            local kind = item.Name == "CashRegister" and "register" or item.Name == "Safe" and "safe"
            if kind and item:IsA("Model") then
                scanned = scanned + 1
                local valid,reason=isTarget(item,kind)
                if not valid then rejected[reason]=(rejected[reason] or 0)+1 end
                if (mode == "both" or mode == (kind == "register" and "registers" or "safes")) and valid then
                    eligible = eligible + 1
                    table.insert(targets, {model=item, kind=kind, part=kind == "register" and item.Open or item.Safe})
                end
            end
        end
        return targets
    end
    local function nearest(targets, root)
        local best, bestDistance
        for _, target in ipairs(targets) do
            if not targetBackoff[target.model] or elapsed >= targetBackoff[target.model] then
                local distance = (target.part.Position - root.Position).Magnitude
                if not bestDistance or distance < bestDistance then best, bestDistance = target, distance end
            end
        end
        return best
    end
    local function setStatus(text)
        statusLabel.Text = text
    end
    local function refreshBag()
        local bag, capacity = bagInfo()
        bagLabel.Text = bag and ("Bag: " .. tostring(bag) .. "/" .. tostring(capacity or "?")) or "Bag: unavailable"
        return bag, capacity
    end
    local function stop(reason)
        running, pending, activeRoot, deposit, scout = false, nil, nil, nil, nil
        startButton.Text = "Start"
        setStatus(reason or "Stopped")
    end
    local function vectorText(value)
        if not value then return "unavailable" end
        return string.format("%.1f,%.1f,%.1f",value.X,value.Y,value.Z)
    end
    local function recordIncident(kind, health)
        local root=activeRoot
        local stage=pending and ("robbery/" .. pending.phase) or deposit and ("cash-in/" .. deposit.phase)
            or scout and ("region/" .. scout.phase) or "between actions"
        local age=lastMoveAt and string.format("%.2fs",elapsed-lastMoveAt) or "no move this run"
        savedIncident=kind .. "; stage=" .. stage .. "; health before=" .. tostring(lastHealth)
            .. "; health observed=" .. tostring(health) .. "; position=" .. vectorText(root and root.Position)
            .. "; velocity=" .. vectorText(root and root.AssemblyLinearVelocity) .. "; since move=" .. age
            .. "; last move=" .. savedMove
        lastFailure=kind
        if playerGui then pcall(function() playerGui:SetAttribute(incidentAttribute,savedIncident) end) end
    end
    local function watchHealth(humanoid)
        if watchedHumanoid == humanoid then return end
        if healthWatch then healthWatch:Disconnect() end
        if deathWatch then deathWatch:Disconnect() end
        watchedHumanoid=humanoid
        if humanoid.HealthChanged then
            healthWatch=humanoid.HealthChanged:Connect(function(health)
                if not alive or not running then return end
                if not lastHealth or health >= lastHealth then lastHealth=health;return end
                recordIncident(health <= 0 and "Death detected" or "Damage detected",health)
                lastHealth=health
                stop(health <= 0 and "Stopped: character unavailable or dead" or "Stopped: damage detected")
            end)
        end
        if humanoid.Died then
            deathWatch=humanoid.Died:Connect(function()
                if not alive or not running then return end
                recordIncident("Death detected",humanoid.Health)
                lastHealth=humanoid.Health
                stop("Stopped: character unavailable or dead")
            end)
        end
    end
    -- Only use loaded, solid, level ground with room for the character beside the target.
    -- These checks reduce collision/fall risk; server teleport enforcement is still possible.
    local function landingFor(target, root)
        local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = {player.Character}
        ray.RespectCanCollide = true
        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude
        overlap.FilterDescendantsInstances = {player.Character}
        overlap.RespectCanCollide = true
        local hip = math.max(humanoid.HipHeight or 2, 2)
        local height = hip + root.Size.Y + 2
        local size = Vector3.new(math.max(root.Size.X + 2, 4), height, math.max(root.Size.Z + 2, 4))
        local offsets = {{6,0},{-6,0},{0,6},{0,-6},{5,5},{5,-5},{-5,5},{-5,-5}}
        for _, offset in ipairs(offsets) do
            local pos = target.part.Position
            local hit = workspace:Raycast(Vector3.new(pos.X+offset[1],pos.Y+8,pos.Z+offset[2]), Vector3.new(0,-20,0),ray)
            if hit and hit.Normal.Y >= 0.9 and hit.Material ~= Enum.Material.Water
                and math.abs(hit.Position.Y-pos.Y) <= 6
                and (target.allowOwnGround or not target.model or not hit.Instance:IsDescendantOf(target.model))
                and (hit.Instance:IsA("Terrain") or (hit.Instance.CanCollide and hit.Instance.Anchored)) then
                local floor = hit.Position
                local supported = true
                for _, corner in ipairs({{-1.5,-1.5},{-1.5,1.5},{1.5,-1.5},{1.5,1.5}}) do
                    local support = workspace:Raycast(Vector3.new(floor.X+corner[1],floor.Y+2,floor.Z+corner[2]),Vector3.new(0,-4,0),ray)
                    if not support or support.Normal.Y < 0.9 or support.Material == Enum.Material.Water
                        or math.abs(support.Position.Y-floor.Y) > 0.75
                        or (not target.allowOwnGround and target.model and support.Instance:IsDescendantOf(target.model))
                        or not (support.Instance:IsA("Terrain") or (support.Instance.CanCollide and support.Instance.Anchored)) then
                        supported = false; break
                    end
                end
                local box = CFrame.new(floor.X,floor.Y+height/2+0.2,floor.Z)
                if supported and #workspace:GetPartBoundsInBox(box,size,overlap) == 0 then
                    return CFrame.new(floor.X,floor.Y+hip+root.Size.Y/2+0.2,floor.Z)
                end
            end
        end
    end
    local function moveToTarget(target, root, purpose)
        if (target.part.Position-root.Position).Magnitude <= 10 then return true, false end
        local ok, landing = pcall(landingFor,target,root)
        if not ok or not landing then
            skippedLandings = skippedLandings + 1
            return false, ok and "no clear grounded landing" or "landing checks unavailable"
        end
        lastMovement=target.name or target.model:GetFullName()
        lastMoveAt=elapsed
        local humanoid=player.Character:FindFirstChildWhichIsA("Humanoid")
        savedMove="purpose=" .. (purpose or target.kind or "target") .. "; target=" .. lastMovement
            .. "; from=" .. vectorText(root.Position) .. "; to=" .. vectorText(landing.Position)
            .. "; distance=" .. string.format("%.1f",(landing.Position-root.Position).Magnitude)
            .. "; health=" .. tostring(humanoid.Health)
        if playerGui then pcall(function() playerGui:SetAttribute(moveAttribute,savedMove) end) end
        local okMove = pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            root.AssemblyAngularVelocity = Vector3.new(0,0,0)
            root.CFrame = landing
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            root.AssemblyAngularVelocity = Vector3.new(0,0,0)
        end)
        if not okMove then return false, "teleport failed" end
        if not running or characterRoot() ~= root then return false,"movement interrupted" end
        teleports = teleports + 1
        return true, true
    end
    local function shopAnchors()
        local result={}
        local shops=workspace:FindFirstChild("Shops")
        if not shops then return result end
        for _, item in ipairs(shops:GetChildren()) do
            if item:IsA("Model") or item:IsA("BasePart") then
                local ok,pos=pcall(function()
                    if item:IsA("BasePart") then return item.Position end
                    return item:GetPivot().Position
                end)
                if ok and pos then
                    table.insert(result,{model=item,part={Position=pos},name=item:GetFullName(),key=item,allowOwnGround=true})
                end
            end
        end
        return result
    end
    local function beginScout(root)
        local regions={}
        for _, anchor in ipairs(shopAnchors()) do
            local duplicate=false
            for _, region in ipairs(regions) do
                if (anchor.part.Position-region.part.Position).Magnitude < 150 then duplicate=true;break end
            end
            if not duplicate then table.insert(regions,anchor) end
        end
        local candidate,rank,distance
        for _, anchor in ipairs(regions) do
            local visit=shopVisits[anchor.key]
            local age=visit or -math.huge
            local d=(anchor.part.Position-root.Position).Magnitude
            if (not visit or elapsed-visit >= 30) and (not candidate or age < rank or (age==rank and d < distance)) then
                candidate,rank,distance=anchor,age,d
            end
        end
        if not candidate then
            setStatus(#regions==0 and "No available targets; no shop regions loaded" or "Waiting for region/target retry timers")
            return
        end
        shopVisits[candidate.key]=elapsed
        lastScout=candidate.name
        local state={target=candidate,phase="stream",ready=true,deadline=elapsed+6}
        scout=state
        setStatus("Loading targets near " .. candidate.name)
        if workspace.StreamingEnabled and player.RequestStreamAroundAsync and task and task.spawn then
            state.ready=false;scoutRequests=scoutRequests+1
            task.spawn(function()
                local ok=pcall(function() player:RequestStreamAroundAsync(candidate.part.Position,4) end)
                if alive and running and scout==state then
                    state.ready=true
                    if not ok then lastFailure="region streaming request failed" end
                end
            end)
        end
    end
    local function processScout(root)
        local state=scout
        if not state.ready and elapsed < state.deadline then return end
        -- A shop is a discovery anchor, not a validated robbery destination.
        -- Streaming can reveal targets without moving the character toward NPCs.
        local target=nearest(scan(),root)
        scout=nil;nextAttemptAt=elapsed
        setStatus(target and "Targets loaded; continuing route" or "No usable targets in region; searching another area")
    end
    local function campCandidates()
        local result = {}
        for _, item in ipairs(workspace:GetDescendants()) do
            local name = item.Name:lower():gsub("[^%w]", "")
            local team = tostring(item:GetAttribute("Team") or item:GetAttribute("Faction") or ""):lower()
            if (item:IsA("Model") or item:IsA("BasePart")) and
                (name:match("^outlawcamp%d*$") or name == "outlawcampcashin" or name == "outlawcashin"
                    or (name == "camp" and team:find("outlaw",1,true))) then
                local ok, pos = pcall(function()
                    if item:IsA("BasePart") then return item.Position end
                    if item.PrimaryPart then return item.PrimaryPart.Position end
                    return item:GetPivot().Position
                end)
                if ok and pos then
                    table.insert(result,{model=item,part={Position=pos},name=item:GetFullName(),key=item,allowOwnGround=true})
                end
            end
        end
        for _, anchor in ipairs(shopAnchors()) do
            if anchor.model.Name:match("^OutlawGeneralStore%d+$") then table.insert(result,anchor) end
        end
        return result
    end
    local function beginDeposit(root)
        local candidate, distance
        for _, camp in ipairs(campCandidates()) do
            local d = (camp.part.Position-root.Position).Magnitude
            if not depositTried[camp.key] and (not distance or d < distance) then candidate,distance=camp,d end
        end
        -- Historical camp location, only attempted when no named loaded camp remains.
        -- Its current cash-in behavior is confirmed only by the bag actually reaching zero.
        if not candidate and not depositTried.historical then
            candidate={part={Position=Vector3.new(1636.62537,104.349976,-1736.184)},name="Historical camp (unverified)",key="historical",allowOwnGround=true}
        end
        if not candidate then stop("Cash-in unavailable: no camp emptied the bag; copy farm report"); return end
        depositTried[candidate.key]=true
        campName=candidate.name
        local state={target=candidate,phase="stream",ready=true,due=elapsed+6}
        deposit=state
        setStatus("Returning to " .. campName)
        if workspace.StreamingEnabled and player.RequestStreamAroundAsync and task and task.spawn then
            state.ready=false
            task.spawn(function()
                pcall(function() player:RequestStreamAroundAsync(candidate.part.Position,4) end)
                if alive and running and deposit==state then state.ready=true end
            end)
        end
    end
    local function processDeposit(root, bag)
        local state=deposit
        if state.phase == "stream" then
            if not state.ready and elapsed < state.due then return end
            local ok, moved=moveToTarget(state.target,root,"cash-in")
            if not running then return end
            if not ok then lastFailure="cash-in: " .. moved; deposit=nil; return end
            state.phase,state.due,state.deadline="wait",elapsed+(moved and 0.8 or 0.2),elapsed+10
            state.moved,state.landingDeadline=moved,elapsed+3
            setStatus("Waiting for bag to empty at " .. campName)
            return
        end
        if (root.Position-state.target.part.Position).Magnitude > 20 then
            lastFailure="cash-in landing rejected";stop("Stopped: " .. lastFailure);return
        end
        local humanoid=player.Character:FindFirstChildWhichIsA("Humanoid")
        local velocity=root.AssemblyLinearVelocity
        if state.moved and elapsed >= state.landingDeadline
            and (humanoid.FloorMaterial == Enum.Material.Air or not velocity or velocity.Magnitude > 12) then
            lastFailure="cash-in landing did not settle";stop("Stopped: " .. lastFailure);return
        end
        if bag == 0 and elapsed >= state.due and humanoid.FloorMaterial ~= Enum.Material.Air
            and (not velocity or velocity.Magnitude <= 12) then
            cashIns=cashIns+1;deposit=nil;depositTried={};failedAttempts=0;nextAttemptAt=elapsed
            setStatus("Bag emptied; continuing route")
        elseif elapsed >= state.deadline then
            lastFailure="camp did not empty bag";deposit=nil
            setStatus("Cash-in not confirmed; trying another camp")
        end
    end
    local function backoff(target,reason)
        local count=(targetFailures[target.model] or 0)+1
        targetFailures[target.model]=count
        targetBackoff[target.model]=elapsed+math.min(120,15*2^math.min(count-1,3))
        failedAttempts=failedAttempts+1;lastFailure=reason
        setStatus("Skipping failed target; continuing route")
    end
    local function attempt(target, bag)
        local root = characterRoot()
        local remote = validRemote()
        if not root or not remote then stop("Stopped: character or Rob remote unavailable"); return end
        nextAttemptAt = elapsed + 1
        local ok,moved=moveToTarget(target,root)
        if not running then return end
        if not ok then backoff(target,moved);return end
        pending = {target=target, bag=bag, phase=moved and "landing" or "ready", due=elapsed+(moved and 0.8 or 0.2), landingDeadline=elapsed+3}
        attempts = attempts + 1
        setStatus(moved and "Checking landing" or "Collecting nearby target")
    end
    local function doRemote()
        if not running or not pending then return end
        local function failTarget(reason)
            backoff(pending.target,reason);pending=nil
        end
        local target, remote = pending.target, validRemote()
        if not remote or not target.model.Parent or not isTarget(target.model, target.kind)
            or target.part.Parent ~= target.model
            or target.part ~= (target.kind == "register" and target.model.Open or target.model.Safe) then
            failTarget("target or Rob remote changed"); return
        end
        local bag, capacity = bagInfo()
        if not bag or not capacity or capacity <= 0 then stop("Stopped: bag data unavailable"); return end
        if bag >= capacity then pending=nil;setStatus("Bag full; returning to camp");return end
        local root = characterRoot()
        if not root or (target.part.Position - root.Position).Magnitude > 12 then
            lastFailure = "landing rejected or target out of reach"
            stop("Stopped: " .. lastFailure); return
        end
        if pending.phase == "landing" then
            local velocity = root.AssemblyLinearVelocity
            local humanoid = player.Character:FindFirstChildWhichIsA("Humanoid")
            if not velocity or velocity.Magnitude > 12 or humanoid.FloorMaterial == Enum.Material.Air then
                if elapsed >= pending.landingDeadline then
                    lastFailure = "landing did not settle"; stop("Stopped: " .. lastFailure)
                else pending.due = elapsed + 0.2 end
                return
            end
            pending.phase = "ready"
        end
        if pending.phase == "waitSafe" then
            if target.model.Open.Value then pending.phase = "ready"
            elseif elapsed >= pending.openDeadline then failTarget("safe did not open"); return
            else pending.due = elapsed + 0.2; return end
        end
        if pending.phase == "ready" and target.kind == "safe" and not target.model.Open.Value then
            local ok = pcall(function() target.model.OpenSafe:FireServer("Completed") end)
            if not running or not pending then return end
            if not ok then failTarget("OpenSafe call failed"); return end
            pending.phase, pending.due, pending.openDeadline = "waitSafe", elapsed + 0.2, elapsed + 5
            return
        end
        local ok = pcall(function()
            if target.kind == "register" then
                remote:FireServer("Register", {Part=target.model.Union, OpenPart=target.model.Open, ActiveValue=target.model.Active, Active=true})
            else
                remote:FireServer("Safe", target.model)
            end
        end)
        if not running or not pending then return end
        if not ok then failTarget("Rob call failed"); return end
        pending.phase, pending.observeUntil = "observe", elapsed + 3
    end
    local function report()
        local bag, capacity = bagInfo()
        scan()
        local paths = {}
        local reasons={}
        for reason,count in pairs(rejected) do table.insert(reasons,reason .. "=" .. count) end
        table.sort(reasons)
        local prompts = {}
        local campPaths = {}
        for _, item in ipairs(workspace:GetDescendants()) do
            local name=item.Name:lower()
            if #campPaths < 20 and (name:find("camp",1,true) or name:find("cashin",1,true) or name:find("outlaw",1,true)) then
                local ok,cf=pcall(function()
                    return item:IsA("BasePart") and item.CFrame or item:IsA("Model") and item:GetPivot()
                end)
                local pos=ok and cf and cf.Position
                local where=pos and string.format(" @ %.1f,%.1f,%.1f",pos.X,pos.Y,pos.Z) or ""
                table.insert(campPaths,item:GetFullName() .. " [" .. item.ClassName .. "]" .. where)
            end
        end
        local root=characterRoot()
        local pos=root and root.Position
        local position=pos and string.format("%.1f, %.1f, %.1f",pos.X,pos.Y,pos.Z) or "unavailable"
        for _, item in ipairs(workspace:GetDescendants()) do
            if item:IsA("ProximityPrompt") then
                local text = tostring(item.ActionText or "") .. " " .. tostring(item.ObjectText or "")
                local lower = text:lower()
                if #prompts < 12 and (lower:find("cash", 1, true) or lower:find("deposit", 1, true) or lower:find("bag", 1, true)) then
                    table.insert(prompts, item:GetFullName() .. " [" .. text .. "]")
                end
            end
        end
        for _, item in ipairs(workspace:GetDescendants()) do
            if #paths >= 8 then break end
            if item:IsA("Model") and (item.Name == "CashRegister" or item.Name == "Safe") then
                local function childInfo(name)
                    local child = item:FindFirstChild(name)
                    if not child then return "missing" end
                    local value="present"
                    if child:IsA("BoolValue") or child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then value=tostring(child.Value) end
                    return child.ClassName.."="..value
                end
                local name = item.GetFullName and item:GetFullName() or item.Name
                local descendants={}
                if item.Name == "Safe" then
                    for _, child in ipairs(item:GetDescendants()) do
                        if #descendants >= 24 then break end
                        if child:IsA("BasePart") or child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("ProximityPrompt") then
                            table.insert(descendants,child.Name .. ":" .. child.ClassName)
                        end
                    end
                end
                table.insert(paths, tostring(name) .. " {Open=" .. childInfo("Open") .. ", Amount=" .. childInfo("Amount") .. ", Active=" .. childInfo("Active") .. ", Safe=" .. childInfo("Safe") .. ", OpenSafe=" .. childInfo("OpenSafe") .. ", Children=" .. table.concat(descendants,"|") .. "}")
            end
        end
        return table.concat({"Honey Bun Hub farm report", "Mode: " .. modeText(), "Running: " .. tostring(running), "Bag: " .. tostring(bag or "unavailable") .. "/" .. tostring(capacity or "unavailable"), "Movement: checked teleport route V6", "Teleports: " .. teleports, "Skipped landings: " .. skippedLandings, "Last teleport: " .. lastMovement, "Saved last move: " .. savedMove, "Last incident (saved): " .. savedIncident, "Health: " .. tostring(lastHealth or "unknown"), "Cash-in: nearest recognized loaded camp; historical fallback", "Position: " .. position, "Camp objects: " .. (#campPaths > 0 and table.concat(campPaths, ", ") or "none loaded"), "Camp: " .. campName, "Confirmed cash-ins: " .. cashIns, "Loaded camp candidates: " .. #campCandidates(), "Rob remote present: " .. tostring(validRemote() ~= nil), "Scanned: " .. scanned, "Eligible: " .. eligible, "Rejected targets: " .. (#reasons>0 and table.concat(reasons,", ") or "none"), "Shop anchors: " .. #shopAnchors(), "Region requests: " .. scoutRequests, "Region movement: streaming only", "Last region: " .. lastScout, "Region scan active: " .. tostring(scout~=nil), "Attempts: " .. attempts, "Confirmed bag increases: " .. successes, "Failed attempts: " .. failedAttempts, "Last failure: " .. lastFailure, "Possible drop-off prompts (unverified): " .. (#prompts > 0 and table.concat(prompts, ", ") or "none loaded"), "Targets: " .. (#paths > 0 and table.concat(paths, ", ") or "none")}, "\n")
    end
    modeButton.Activated:Connect(function()
        mode = mode == "both" and "registers" or mode == "registers" and "safes" or "both"
        modeButton.Text = "Mode: " .. modeText(); saveMode()
    end)
    startButton.Activated:Connect(function()
        if running then stop("Stopped"); return end
        if not characterRoot() then setStatus("Cannot start: living character required"); return end
        local bag, capacity = bagInfo()
        if bag == nil or not capacity or capacity <= 0 then setStatus("Cannot start: bag data unavailable"); return end
        if not validRemote() then setStatus("Cannot start: Rob remote unavailable"); return end
        scan()
        depositTried={};deposit=nil;scout=nil
        running, stepClock, failedAttempts, nextAttemptAt, activeRoot = true, 0, 0, elapsed, characterRoot()
        local humanoid=player.Character:FindFirstChildWhichIsA("Humanoid")
        lastHealth=humanoid.Health
        watchHealth(humanoid)
        startButton.Text = "Stop"; setStatus("Running teleport route; cooldowns unchanged")
    end)
    reportButton.Activated:Connect(function()
        local text = report()
        if type(setclipboard) == "function" then
            local ok = pcall(setclipboard, text)
            reportButton.Text = ok and "Farm report copied" or "Clipboard unavailable"
            if not ok then setStatus("Report ready; clipboard unavailable") end
            if not ok and type(warn)=="function" then warn(text) end
        else
            reportButton.Text = "Clipboard unavailable"
            setStatus("Report ready; clipboard unavailable")
            if type(warn) == "function" then warn(text) end
        end
    end)
    modeButton.Text = "Mode: " .. modeText()
    refreshBag()
    table.insert(connections, RunService.Heartbeat:Connect(function(dt)
        if not alive then return end
        elapsed, stepClock = elapsed + dt, stepClock + dt
        local bag, capacity = refreshBag()
        if not running then return end
        local root = characterRoot()
        if not root or root~=activeRoot then
            local humanoid=player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
            if humanoid and humanoid.Health <= 0 then recordIncident("Death detected",humanoid.Health)
            else recordIncident("Character unavailable or changed",humanoid and humanoid.Health) end
            stop("Stopped: character unavailable or changed");return
        end
        local health = player.Character:FindFirstChildWhichIsA("Humanoid").Health
        if lastHealth and health < lastHealth then recordIncident("Damage detected",health); lastHealth = health; stop("Stopped: damage detected"); return end
        lastHealth = health
        if stepClock < 0.2 then return end
        stepClock = 0
        if not bag or not capacity or capacity <= 0 then stop("Stopped: bag data unavailable"); return end
        if bag >= capacity and scout then scout=nil end
        if deposit then processDeposit(root,bag);return end
        if scout then processScout(root);return end
        if bag == 0 and next(depositTried) then
            cashIns=cashIns+1;depositTried={};failedAttempts=0;nextAttemptAt=elapsed
            setStatus("Bag emptied; continuing route")
        end
        if pending and pending.phase ~= "observe" and bag >= capacity then pending=nil end
        if pending then
            if pending.phase == "observe" and bag and pending.bag and bag > pending.bag then targetFailures[pending.target.model]=nil; targetBackoff[pending.target.model] = elapsed + 30; local delta = bag - pending.bag; successes = successes + 1; collectedTotal = collectedTotal + delta; collectedLabel.Text = "Collected into bag: +" .. tostring(delta) .. " (total amount: " .. tostring(collectedTotal) .. ")"; pending = nil; failedAttempts = 0
            elseif pending.phase == "observe" and elapsed >= pending.observeUntil then
                backoff(pending.target,"no bag increase after attempt");pending=nil
            elseif pending.phase ~= "observe" and elapsed >= pending.due then doRemote() end
            return
        end
        if bag >= capacity then
            beginDeposit(root)
            return
        end
        if bag > 0 and next(depositTried) then beginDeposit(root);return end
        if elapsed >= nextAttemptAt then
            nextAttemptAt=elapsed+1
            local target = nearest(scan(), root)
            if target then attempt(target, bag) else beginScout(root) end
        end
    end))
    return cleanup
end

return mount
