local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local function mount(contentFrame)
    local workspaceRoot = game:GetService("Workspace")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local alive = true
    local master, animals, chests = false, true, true
    local distances = {500, 1000, 2500, math.huge}
    local distanceIndex = 2
    local queue, queued, tracked = {}, {}, {}
    local queueHead, queueTail = 1, 0
    local connections, owned = {}, {}
    local heartbeatClock, elapsed = 0, 0
    local billboardFolder

    local function disconnectAll()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
    end

    local function cleanup()
        if not alive then return end
        alive = false
        disconnectAll()
        for model in pairs(tracked) do
            local item = tracked[model]
            if item.gui then item.gui:Destroy() end
            tracked[model] = nil
        end
        if billboardFolder then billboardFolder:Destroy() end
        for _, object in ipairs(owned) do object:Destroy() end
        owned = {}
    end

    table.insert(connections, contentFrame.Destroying:Connect(cleanup))

    local layout = contentFrame:FindFirstChildOfClass("UIListLayout")
    if not layout then
        layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = contentFrame
        table.insert(owned, layout)
    end

    local function row(text, order)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -8, 0, 32)
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        button.BorderColor3 = Color3.fromRGB(95, 95, 95)
        button.TextColor3 = Color3.fromRGB(245, 245, 245)
        button.Font = Enum.Font.Gotham
        button.TextSize = 13
        button.LayoutOrder = order
        button.Text = text
        button.Parent = contentFrame
        table.insert(owned, button)
        return button
    end

    local masterButton = row("World ESP: OFF", 100)
    local animalButton = row("Animals: ON", 101)
    local chestButton = row("Treasure chests: ON", 102)
    local rangeButton = row("Distance: 1000", 103)

    local function refreshControls()
        masterButton.Text = "World ESP: " .. (master and "ON" or "OFF")
        animalButton.Text = "Animals: " .. (animals and "ON" or "OFF")
        chestButton.Text = "Treasure chests: " .. (chests and "ON" or "OFF")
        local value = distances[distanceIndex]
        rangeButton.Text = "Distance: " .. (value == math.huge and "Unlimited" or tostring(value))
    end
    masterButton.Activated:Connect(function() master = not master; refreshControls() end)
    animalButton.Activated:Connect(function() animals = not animals; refreshControls() end)
    chestButton.Activated:Connect(function() chests = not chests; refreshControls() end)
    rangeButton.Activated:Connect(function()
        distanceIndex = distanceIndex % #distances + 1
        refreshControls()
    end)

    local species = {horse=true, bear=true, deer=true, bison=true, coyote=true, wolf=true, rabbit=true, boar=true, cow=true, ox=true, goat=true, sheep=true, pig=true, chicken=true, turkey=true, elk=true, moose=true, buffalo=true, fox=true, alligator=true, snake=true}
    local function lower(value) return string.lower(tostring(value or "")) end
    local function hasSpecies(value)
        local words = tostring(value or ""):gsub("(%l)(%u)", "%1 %2")
        for word in lower(words):gmatch("[%a]+") do if species[word] then return word end end
    end
    local function playerDescendant(instance)
        local current = instance
        while current and current ~= workspaceRoot do
            if current:IsA("Model") and Players:GetPlayerFromCharacter(current) then return true end
            current = current.Parent
        end
        return false
    end
    local function attributeString(model, name)
        local value = model:GetAttribute(name)
        return type(value) == "string" and value or nil
    end
    local function tagged(model, names)
        for _, name in ipairs(names) do if CollectionService:HasTag(model, name) then return true end end
        return false
    end
    local function classify(model)
        if not model or not model:IsA("Model") or playerDescendant(model) then return nil end
        local animal = attributeString(model, "AnimalType") or attributeString(model, "Species")
        local animalName = hasSpecies(animal)
        if animal and animal ~= "" or animalName or hasSpecies(model.Name) or tagged(model, {"Animal"}) then
            if animal and animal ~= "" then return "animal", animal end
            if animalName or hasSpecies(model.Name) then return "animal", animalName or hasSpecies(model.Name) end
            return "animal", model.Name
        end
        local name = lower(model.Name)
        local chestName = name:find("treasurechest", 1, true) or name == "treasure chest"
        if not chestName then for word in name:gmatch("[%a]+") do if word == "chest" then chestName = true end end end
        if chestName or tagged(model, {"TreasureChest", "treasure", "chest"}) then
            return "chest", "Treasure chest"
        end
        return nil
    end
    local function nearestModel(instance)
        if instance:IsA("Model") then return instance end
        return instance:FindFirstAncestorOfClass("Model")
    end
    local function enqueue(instance)
        local model = nearestModel(instance)
        if model and not queued[model] then queued[model] = true; queueTail = queueTail + 1; queue[queueTail] = model end
    end
    local function partFor(model)
        if model.PrimaryPart then return model.PrimaryPart end
        return model:FindFirstChildWhichIsA("BasePart", true)
    end
    local function goldFor(model)
        local names = {Gold=true, GoldAmount=true, TreasureGold=true, RewardGold=true, GoldValue=true, Coins=true}
        for key in pairs(names) do
            local value = model:GetAttribute(key)
            if type(value) == "number" and value == value and value >= 0 and value < math.huge then return value end
        end
        for _, child in ipairs(model:GetDescendants()) do
            if names[child.Name] and (child:IsA("NumberValue") or child:IsA("IntValue")) then
                local value = child.Value
                if type(value) == "number" and value == value and value >= 0 and value < math.huge then return value end
            end
        end
    end
    local function remove(model)
        local item = tracked[model]
        if item then if item.gui then item.gui:Destroy() end; tracked[model] = nil end
    end
    local function trackedCount()
        local count = 0
        for _ in pairs(tracked) do count = count + 1 end
        return count
    end
    local function add(model)
        if tracked[model] or not model.Parent or trackedCount() >= 300 then return end
        local kind, label = classify(model)
        if not kind then return end
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Model") and classify(child) then return end
        end
        local ancestor = model.Parent
        while ancestor do
            if ancestor:IsA("Model") and tracked[ancestor] then remove(ancestor) end
            ancestor = ancestor.Parent
        end
        local part = partFor(model)
        if not part then return end
        tracked[model] = {kind=kind, label=label, part=part, gui=nil, gold=nil, nextGoldAt=0}
    end

    for _, instance in ipairs(workspaceRoot:GetDescendants()) do enqueue(instance) end
    table.insert(connections, workspaceRoot.DescendantAdded:Connect(enqueue))
    table.insert(connections, workspaceRoot.DescendantRemoving:Connect(function(instance)
        if tracked[instance] then remove(instance) end
    end))
    for _, tag in ipairs({"Animal", "TreasureChest", "treasure", "chest"}) do
        table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(enqueue))
    end
    table.insert(connections, RunService.Heartbeat:Connect(function(dt)
        if not alive then return end
        heartbeatClock = heartbeatClock + dt
        elapsed = elapsed + dt
        for _ = 1, 100 do
            local model = queue[queueHead]
            if not model then break end
            queue[queueHead] = nil
            queueHead = queueHead + 1
            queued[model] = nil
            add(model)
        end
        if queueHead > queueTail then queueHead, queueTail = 1, 0 end
        if not playerGui then playerGui = player and player:FindFirstChildOfClass("PlayerGui") end
        if master and playerGui and not billboardFolder then
            billboardFolder = Instance.new("Folder")
            billboardFolder.Name = "HoneyBunWorldESP"
            billboardFolder.Parent = playerGui
        end
        local camera = workspaceRoot.CurrentCamera
        if not camera then
            for _, item in pairs(tracked) do if item.gui then item.gui.Enabled = false end end
            return
        end
        if heartbeatClock < 0.1 then return end
        heartbeatClock = 0
        local origin = camera.CFrame.Position
        for model, item in pairs(tracked) do
            local enabled = master and ((item.kind == "animal" and animals) or (item.kind == "chest" and chests))
            if not model.Parent or not item.part.Parent then remove(model)
            elseif not enabled then if item.gui then item.gui:Destroy(); item.gui = nil end
            else
                local distance = (item.part.Position - origin).Magnitude
                local point, visible = camera:WorldToViewportPoint(item.part.Position)
                if distance <= distances[distanceIndex] and visible and point.Z > 0 then
                    if not item.gui then
                        local gui = Instance.new("BillboardGui")
                        gui.Name, gui.AlwaysOnTop, gui.Size = "WorldESP", true, UDim2.fromOffset(190, 26)
                        gui.StudsOffset = Vector3.new(0, item.part.Size.Y * 0.5 + 2, 0)
                        gui.Adornee, gui.Parent = item.part, billboardFolder
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
                        label.TextStrokeTransparency = 0.25; label.TextStrokeColor3 = Color3.fromRGB(25, 25, 25)
                        label.Font, label.TextSize = Enum.Font.GothamBold, 13
                        label.Parent = gui
                        item.gui = gui; item.text = label
                    end
                    if item.kind == "chest" and elapsed >= item.nextGoldAt then
                        item.gold = goldFor(model)
                        item.nextGoldAt = elapsed + 1
                    end
                    item.text.Text = item.kind == "animal" and (item.label .. " · " .. math.floor(distance) .. " studs") or ((item.gold and ("Treasure chest · Gold: " .. tostring(item.gold)) or "Treasure chest · Gold unknown") .. " · " .. math.floor(distance) .. " studs")
                    item.text.TextColor3 = item.kind == "animal" and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 225, 130)
                    item.gui.Enabled = true
                elseif item.gui then item.gui.Enabled = false end
            end
        end
    end))
    refreshControls()
    return cleanup
end

return mount
