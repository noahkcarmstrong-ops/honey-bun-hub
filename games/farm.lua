-- HoneyBunFarmRouteV3
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function mount(contentFrame)
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local gameKey = tostring(game.GameId or 0)
    local modeAttribute = "HoneyBunFarmMode_" .. gameKey
    local mode = playerGui and playerGui:GetAttribute(modeAttribute) or "both"
    if mode ~= "registers" and mode ~= "safes" then mode = "both" end
    local alive, running = true, false
    local stepClock, elapsed = 0, 0
    local activeRoot
    local pending, targetBackoff, scanned, eligible = nil, {}, 0, 0
    local attempts, successes, collectedTotal, failedAttempts, lastFailure = 0, 0, 0, 0, "none"
    local nextAttemptAt = 0
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
        alive, running, pending = false, false, nil
        saveMode()
        disconnectAll()
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
    label("Teleport route: checked landings, damage stop, server cooldowns apply.", 105)
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
        return item:IsA("Model") and item:FindFirstChild("Open") and item.Open:IsA("BasePart")
            and item:FindFirstChild("Union") and item.Union:IsA("BasePart")
            and item:FindFirstChild("Active") and item.Active:IsA("BoolValue")
    end
    local function validSafe(item)
        local amount = numberValue(item, "Amount")
        local open = item:FindFirstChild("Open")
        local part = item:FindFirstChild("Safe")
        if not item:IsA("Model") or not amount or amount <= 0 or not open or not open:IsA("BoolValue") or not part or not part:IsA("BasePart") then return false end
        return open.Value or (item:FindFirstChild("OpenSafe") and item.OpenSafe:IsA("RemoteEvent"))
    end
    local function isTarget(item, kind)
        return kind == "register" and validRegister(item) or kind == "safe" and validSafe(item)
    end
    local function scan()
        scanned, eligible = 0, 0
        local targets = {}
        for _, item in ipairs(workspace:GetDescendants()) do
            local kind = item.Name == "CashRegister" and "register" or item.Name == "Safe" and "safe"
            if kind then
                scanned = scanned + 1
                if (mode == "both" or mode == (kind == "register" and "registers" or "safes")) and isTarget(item, kind) then
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
        running, pending, activeRoot = false, nil, nil
        startButton.Text = "Start"
        setStatus(reason or "Stopped")
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
                and not hit.Instance:IsDescendantOf(target.model)
                and (hit.Instance:IsA("Terrain") or (hit.Instance.CanCollide and hit.Instance.Anchored)) then
                local floor = hit.Position
                local supported = true
                for _, corner in ipairs({{-1.5,-1.5},{-1.5,1.5},{1.5,-1.5},{1.5,1.5}}) do
                    local support = workspace:Raycast(Vector3.new(floor.X+corner[1],floor.Y+2,floor.Z+corner[2]),Vector3.new(0,-4,0),ray)
                    if not support or support.Normal.Y < 0.9 or support.Material == Enum.Material.Water
                        or math.abs(support.Position.Y-floor.Y) > 0.75
                        or support.Instance:IsDescendantOf(target.model)
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
    local function attempt(target, bag)
        local root = characterRoot()
        local remote = validRemote()
        if not root or not remote then stop("Stopped: character or Rob remote unavailable"); return end
        nextAttemptAt = elapsed + 1
        local moved = false
        if (target.part.Position-root.Position).Magnitude > 10 then
            local ok, landing = pcall(landingFor,target,root)
            if not ok or not landing then
                skippedLandings = skippedLandings + 1
                lastFailure = ok and "no clear grounded landing" or "landing checks unavailable"
                targetBackoff[target.model] = elapsed + 15
                setStatus("Skipping target: " .. lastFailure)
                return
            end
            local okMove = pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0,0,0)
                root.AssemblyAngularVelocity = Vector3.new(0,0,0)
                root.CFrame = landing
            end)
            if not okMove then stop("Stopped: teleport failed"); return end
            teleports = teleports + 1
            lastMovement = target.model:GetFullName()
            moved = true
        end
        pending = {target=target, bag=bag, phase=moved and "landing" or "ready", due=elapsed+(moved and 0.8 or 0.2), landingDeadline=elapsed+3}
        attempts = attempts + 1
        setStatus(moved and "Checking landing" or "Collecting nearby target")
    end
    local function doRemote()
        if not running or not pending then return end
        local function failTarget(reason)
            lastFailure = reason; targetBackoff[pending.target.model] = elapsed + 15; failedAttempts = failedAttempts + 1; pending = nil
            if failedAttempts >= 3 then stop("Repeated collection failures; scan needed") end
        end
        local target, remote = pending.target, validRemote()
        if not remote or not target.model.Parent or not isTarget(target.model, target.kind)
            or target.part.Parent ~= target.model
            or target.part ~= (target.kind == "register" and target.model.Open or target.model.Safe) then
            failTarget("target or Rob remote changed"); return
        end
        local bag, capacity = bagInfo()
        if not bag or not capacity or capacity <= 0 then stop("Stopped: bag data unavailable"); return end
        if bag >= capacity then stop("Bag full: cash in normally; automatic drop-off unverified"); return end
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
        if not ok then failTarget("Rob call failed"); return end
        pending.phase, pending.observeUntil = "observe", elapsed + 3
    end
    local function report()
        local bag, capacity = bagInfo()
        scan()
        local paths = {}
        local prompts = {}
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
            if item.Name == "CashRegister" or item.Name == "Safe" then
                local function childInfo(name)
                    local child = item:FindFirstChild(name)
                    if not child then return "missing" end
                    local value="present"
                    if child:IsA("BoolValue") or child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") then value=tostring(child.Value) end
                    return child.ClassName.."="..value
                end
                local name = item.GetFullName and item:GetFullName() or item.Name
                table.insert(paths, tostring(name) .. " {Open=" .. childInfo("Open") .. ", Amount=" .. childInfo("Amount") .. ", Active=" .. childInfo("Active") .. "}")
            end
        end
        return table.concat({"Honey Bun Hub farm report", "Mode: " .. modeText(), "Running: " .. tostring(running), "Bag: " .. tostring(bag or "unavailable") .. "/" .. tostring(capacity or "unavailable"), "Movement: checked teleport route V3", "Teleports: " .. teleports, "Skipped landings: " .. skippedLandings, "Last teleport: " .. lastMovement, "Health: " .. tostring(lastHealth or "unknown"), "Cash-in: automatic detection unverified", "Rob remote present: " .. tostring(validRemote() ~= nil), "Scanned: " .. scanned, "Eligible: " .. eligible, "Attempts: " .. attempts, "Confirmed bag increases: " .. successes, "Failed attempts: " .. failedAttempts, "Last failure: " .. lastFailure, "Possible drop-off prompts (unverified): " .. (#prompts > 0 and table.concat(prompts, ", ") or "none loaded"), "Targets: " .. (#paths > 0 and table.concat(paths, ", ") or "none")}, "\n")
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
        local targets = scan()
        if #targets == 0 then setStatus("Cannot start: no valid targets detected"); return end
        running, stepClock, failedAttempts, nextAttemptAt, activeRoot = true, 0, 0, elapsed, characterRoot()
        lastHealth = player.Character:FindFirstChildWhichIsA("Humanoid").Health
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
        if not root or root~=activeRoot then stop("Stopped: character unavailable or changed"); return end
        local health = player.Character:FindFirstChildWhichIsA("Humanoid").Health
        if lastHealth and health < lastHealth then lastHealth = health; lastFailure = "damage detected"; stop("Stopped: damage detected"); return end
        lastHealth = health
        if stepClock < 0.2 then return end
        stepClock = 0
        if not bag or not capacity or capacity <= 0 then stop("Stopped: bag data unavailable"); return end
        if pending then
            if pending.phase == "observe" and bag and pending.bag and bag > pending.bag then targetBackoff[pending.target.model] = elapsed + 30; local delta = bag - pending.bag; successes = successes + 1; collectedTotal = collectedTotal + delta; collectedLabel.Text = "Collected into bag: +" .. tostring(delta) .. " (total amount: " .. tostring(collectedTotal) .. ")"; pending = nil; failedAttempts = 0
            elseif pending.phase == "observe" and elapsed >= pending.observeUntil then
                failedAttempts = failedAttempts + 1; lastFailure = "no bag increase after attempt"; targetBackoff[pending.target.model] = elapsed + 15; pending = nil
                if failedAttempts >= 3 then stop("No collection confirmed; scan needed"); return end
            elseif pending.phase ~= "observe" and elapsed >= pending.due then doRemote() end
            return
        end
        if bag >= capacity then
            stop("Bag full: cash in normally; automatic drop-off unverified")
            return
        end
        if elapsed >= nextAttemptAt then
            nextAttemptAt=elapsed+1
            local target = nearest(scan(), root)
            if target then attempt(target, bag) else setStatus("Waiting for loaded targets or retry timers") end
        end
    end))
    return cleanup
end

return mount
