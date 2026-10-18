local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local function mount(contentFrame)
    local workspaceRoot = game:GetService("Workspace")
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local alive = true
    local animals, chests, advanced, rareOnly = false, false, false, false
    local animalTypesExpanded, rareTypesExpanded = false, false
    local animalTypes, speciesButtons, speciesButtonLabels = {}, {}, {}
    local animalTypesDefault, rareTypesDefault = true, true
    local rareSelections, rareButtons, rareButtonLabels = {}, {}, {}
    local speciesButtonCount = 0
    local rareButtonCount = 0
    local distances = {500, 1000, 2500, math.huge}
    local distanceIndex = 4
    local queue, queued, tracked = {}, {}, {}
    local queueHead, queueTail = 1, 0
    local connections, owned = {}, {}
    local heartbeatClock, elapsed = 0, 0

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
        button.Size = UDim2.new(1, -8, 0, 28)
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        button.BorderSizePixel = 0
        button.TextColor3 = Color3.fromRGB(245, 245, 245)
        button.Font = Enum.Font.Gotham
        button.TextSize = 13
        button.LayoutOrder = order
        button.Text = text
        button.Parent = contentFrame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = button
        table.insert(owned, button)
        return button
    end

    local function label(text, order, size, color)
        local item = Instance.new("TextLabel")
        item.Size = UDim2.new(1, -8, 0, size)
        item.BackgroundTransparency = 1
        item.TextColor3 = color
        item.Font = Enum.Font.Gotham
        item.TextSize = size == 24 and 16 or 12
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.LayoutOrder = order
        item.Text = text
        item.Parent = contentFrame
        table.insert(owned, item)
        return item
    end

    local heading = label("WORLD", 100, 24, Color3.fromRGB(245, 245, 245))
    local animalButton = row("Animals: OFF", 101)
    local chestButton = row("Treasure chests: OFF", 102)
    local moreButton = row("More world options", 103)
    local rangeButton = row("Distance: Unlimited", 104)
    local foundLabel = label("No targets discovered yet", 105, 20, Color3.fromRGB(150, 150, 150))
    foundLabel.Size, foundLabel.TextWrapped = UDim2.new(1, -8, 0, 48), true
    local animalTypesButton = row("Animal types", 106)
    local allAnimalsButton = row("All animal types", 107)
    local noAnimalsButton = row("No animal types", 108)
    local rareButton = row("Rare animals only: OFF", 109)
    local rareTypesButton = row("Rare animal types", 110)
    local allRareButton = row("All rare animal types", 111)
    local noRareButton = row("No rare animal types", 112)
    local reportButton = row("Copy visibility report", 113)
    local rareVariantNames = {
        {"dire wolf", "Dire Wolf"}, {"legendary bison", "Legendary Bison"},
        {"legendary deer", "Legendary Deer"}, {"legendary black bear", "Legendary Black Bear"},
        {"legendary grizzly bear", "Legendary Grizzly Bear"}, {"legendary wolf", "Legendary Wolf"},
        {"legendary coyote", "Legendary Coyote"}, {"legendary dire wolf", "Legendary Dire Wolf"},
        {"legendary bull moose", "Legendary Bull Moose"},
    }
    for _, variant in ipairs(rareVariantNames) do rareSelections[variant[1]] = true end
    rangeButton.Visible, foundLabel.Visible, reportButton.Visible = false, false, false

    local function updateSpeciesButtons()
        for key, button in pairs(speciesButtons) do
            button.Visible = animals and animalTypesExpanded
            button.Text = (animalTypes[key] and "✓ " or "  ") .. speciesButtonLabels[key]
        end
        animalTypesButton.Visible = animals
        allAnimalsButton.Visible = animals and animalTypesExpanded
        noAnimalsButton.Visible = animals and animalTypesExpanded
        rareButton.Visible = animals
        rareTypesButton.Visible = animals
        allRareButton.Visible = animals and rareTypesExpanded
        noRareButton.Visible = animals and rareTypesExpanded
        for key, button in pairs(rareButtons) do
            button.Visible = animals and rareTypesExpanded
            button.Text = (rareSelections[key] and "✓ " or "  ") .. rareButtonLabels[key]
        end
    end

    local function refreshControls()
        animalButton.Text = "Animals: " .. (animals and "ON" or "OFF")
        chestButton.Text = "Treasure chests: " .. (chests and "ON" or "OFF")
        rareButton.Text = "Rare animals only: " .. (rareOnly and "ON" or "OFF")
        moreButton.Text = advanced and "Hide world options" or "More world options"
        rangeButton.Visible, foundLabel.Visible, reportButton.Visible = advanced, advanced, advanced
        local animalCount, rareCount, chestCount, eligibleChests, unknownChests = 0, 0, 0, 0, 0
        for _, item in pairs(tracked) do
            if item.kind == "animal" then
                animalCount = animalCount + 1
                if item.rare then rareCount = rareCount + 1 end
            else chestCount = chestCount + 1 end
            if item.kind == "chest" then
                if item.chestState == "unlooted" then eligibleChests = eligibleChests + 1 end
                if item.chestState == "unknown" then unknownChests = unknownChests + 1 end
            end
        end
        if animalCount + chestCount == 0 then
            foundLabel.Text = "No targets discovered yet"
        elseif unknownChests > 0 then
            foundLabel.Text = "Animals found: " .. animalCount .. " (rare: " .. rareCount .. ") · Chests found: " .. chestCount .. " · Eligible: " .. eligibleChests .. " · " .. unknownChests .. " chest loot state unreadable"
        else
            foundLabel.Text = "Animals found: " .. animalCount .. " (rare: " .. rareCount .. ") · Chests found: " .. chestCount .. " · Eligible: " .. eligibleChests
        end
        local value = distances[distanceIndex]
        rangeButton.Text = "Distance: " .. (value == math.huge and "Unlimited" or tostring(value))
        local streaming = "unknown"
        local ok, state = pcall(function() return workspaceRoot.StreamingEnabled end)
        if ok and type(state) == "boolean" then streaming = state and "on" or "off" end
        local farthest = 0
        local camera = workspaceRoot.CurrentCamera
        local cameraPosition
        if camera then pcall(function() cameraPosition = camera.CFrame.Position end) end
        if cameraPosition then
            for _, item in pairs(tracked) do
                local okDistance, distance = pcall(function() return (item.part.Position - cameraPosition).Magnitude end)
                if okDistance and type(distance) == "number" and distance > farthest then farthest = distance end
            end
        end
        if advanced then
            foundLabel.Text = foundLabel.Text .. " · Streaming: " .. streaming .. " · Farthest tracked: " .. math.floor(farthest) .. " studs"
        end
        updateSpeciesButtons()
    end
    local function visibilityEnabled(item)
        if item.kind == "animal" then
            local allowed = item.rare and (not item.rareKey or rareSelections[item.rareKey] ~= false) or (not item.rare and item.speciesKey and animalTypes[item.speciesKey] ~= false)
            return animals and ((rareOnly and item.rare and allowed) or (not rareOnly and allowed))
        end
        return chests and item.chestState == "unlooted"
    end
    local function visibilityReport()
        local streaming = "unknown"
        local ok, state = pcall(function() return workspaceRoot.StreamingEnabled end)
        if ok and type(state) == "boolean" then streaming = state and "on" or "off" end
        local camera = workspaceRoot.CurrentCamera
        local cameraPosition
        if camera then pcall(function() cameraPosition = camera.CFrame.Position end) end
        local animalsFound, chestsFound, eligible, enabled, filtered, farthest = 0, 0, 0, 0, 0, 0
        for _, item in pairs(tracked) do
            if item.kind == "animal" then animalsFound = animalsFound + 1 else
                chestsFound = chestsFound + 1
                if item.chestState == "unlooted" then eligible = eligible + 1 end
            end
            if visibilityEnabled(item) then enabled = enabled + 1 else filtered = filtered + 1 end
            if cameraPosition then
                local okDistance, distance = pcall(function() return (item.part.Position - cameraPosition).Magnitude end)
                if okDistance and type(distance) == "number" and distance > farthest then farthest = distance end
            end
        end
        local queuedCount = 0
        for _ in pairs(queued) do queuedCount = queuedCount + 1 end
        local playersLoaded, playerFarthest = 0, 0
        for _, other in ipairs(Players:GetPlayers()) do
            local character = other.Character
            local root
            if character then root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart end
            if root then
                playersLoaded = playersLoaded + 1
                if cameraPosition then
                    local okDistance, distance = pcall(function() return (root.Position - cameraPosition).Magnitude end)
                    if okDistance and type(distance) == "number" and distance > playerFarthest then playerFarthest = distance end
                end
            end
        end
        local configured = distances[distanceIndex] == math.huge and "Unlimited" or tostring(distances[distanceIndex])
        return table.concat({
            "Honey Bun Hub visibility report",
            "StreamingEnabled: " .. streaming,
            "Configured distance: " .. configured,
            "Animals discovered: " .. animalsFound,
            "Chests discovered: " .. chestsFound,
            "Eligible chests: " .. eligible,
            "Enabled by filters: " .. enabled,
            "Filtered by controls/state: " .. filtered,
            "Farthest tracked target: " .. math.floor(farthest) .. " studs",
            "Loaded player character roots: " .. playersLoaded,
            "Farthest loaded player root: " .. math.floor(playerFarthest) .. " studs",
            "Queue remaining: " .. queuedCount,
        }, "\n")
    end
    reportButton.Activated:Connect(function()
        local report = visibilityReport()
        if type(setclipboard) == "function" then
            local ok = pcall(setclipboard, report)
            reportButton.Text = ok and "Visibility report copied" or "Report ready in console"
            if not ok then warn(report) end
        else
            reportButton.Text = "Report ready in console"
            warn(report)
        end
    end)
    animalButton.Activated:Connect(function() animals = not animals; refreshControls() end)
    chestButton.Activated:Connect(function() chests = not chests; refreshControls() end)
    rareButton.Activated:Connect(function()
        rareOnly = not rareOnly
        if rareOnly then
            rareTypesDefault = true
            for key in pairs(rareSelections) do rareSelections[key] = true end
        end
        refreshControls()
    end)
    moreButton.Activated:Connect(function() advanced = not advanced; refreshControls() end)
    animalTypesButton.Activated:Connect(function() animalTypesExpanded = not animalTypesExpanded; refreshControls() end)
    rareTypesButton.Activated:Connect(function() rareTypesExpanded = not rareTypesExpanded; refreshControls() end)
    allAnimalsButton.Activated:Connect(function()
        animalTypesDefault = true
        rareTypesDefault = true
        for key in pairs(animalTypes) do animalTypes[key] = true end
        for key in pairs(rareSelections) do rareSelections[key] = true end
        refreshControls()
    end)
    noAnimalsButton.Activated:Connect(function()
        animalTypesDefault = false
        rareTypesDefault = false
        for key in pairs(animalTypes) do animalTypes[key] = false end
        for key in pairs(rareSelections) do rareSelections[key] = false end
        refreshControls()
    end)
    allRareButton.Activated:Connect(function()
        rareTypesDefault = true
        for key in pairs(rareSelections) do rareSelections[key] = true end
        refreshControls()
    end)
    noRareButton.Activated:Connect(function()
        rareTypesDefault = false
        for key in pairs(rareSelections) do rareSelections[key] = false end
        refreshControls()
    end)
    local function addRareButton(key, display)
        if rareButtons[key] then return end
        rareButtonCount = rareButtonCount + 1
        local button = row("  " .. display, 112 + rareButtonCount)
        button.Visible = false
        rareButtonLabels[key] = display
        button.Activated:Connect(function()
            rareSelections[key] = not rareSelections[key]
            refreshControls()
        end)
        rareButtons[key] = button
    end
    for _, variant in ipairs(rareVariantNames) do addRareButton(variant[1], variant[2]) end
    rangeButton.Activated:Connect(function()
        distanceIndex = distanceIndex % #distances + 1
        refreshControls()
    end)

    local species = {horse=true, bear=true, deer=true, bison=true, coyote=true, wolf=true, rabbit=true, boar=true, cow=true, ox=true, goat=true, sheep=true, pig=true, chicken=true, turkey=true, elk=true, moose=true, buffalo=true, fox=true, alligator=true, snake=true, crow=true}
    local function lower(value) return string.lower(tostring(value or "")) end
    local function speciesLabel(value)
        local text = tostring(value or ""):gsub("[%{%(%[].*$", ""):gsub("(%l)(%u)", "%1 %2"):gsub("[_%-]+", " "):gsub("%s+", " ")
        text = text:gsub("%s+[Uu][Uu][Ii][Dd].*", "")
        return text:match("^%s*(.-)%s*$")
    end
    local function canonicalRareKey(value)
        local text = lower(speciesLabel(value))
        for _, variant in ipairs(rareVariantNames) do
            if text == variant[1] then return variant[1] end
        end
    end
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
    local function attributeBool(model, names)
        for _, name in ipairs(names) do
            if model:GetAttribute(name) == true then return true end
        end
        return false
    end
    local function rareName(source)
        local text = tostring(source or ""):gsub("(%l)(%u)", "%1 %2"):gsub("[_%-]+", " ")
        text = lower(text)
        local words = {}
        for word in text:gmatch("[%a]+") do words[word] = true end
        return words.legendary or words.rare or (words.dire and words.wolf) or false
    end
    local function rareAnimal(model, source)
        if rareName(source) or rareName(model.Name) then return true end
        if attributeBool(model, {"Rare", "IsRare", "Legendary", "IsLegendary"}) then return true end
        local rarity = attributeString(model, "Rarity")
        if rarity then
            local rarityText = lower(rarity)
            for word in rarityText:gmatch("[%a]+") do
                if word == "rare" or word == "legendary" then return true end
            end
        end
        return tagged(model, {"Legendary", "RareAnimal", "Rare"})
    end
    local function classify(model)
        if not model or not model:IsA("Model") or playerDescendant(model) then return nil end
        local animal = attributeString(model, "AnimalType") or attributeString(model, "Species")
        local source = (animal and animal ~= "" and animal) or model.Name
        if rareName(model.Name) and not rareName(source) then source = model.Name end
        local animalName = hasSpecies(source)
        if animal and animal ~= "" or animalName or hasSpecies(model.Name) or tagged(model, {"Animal"}) then
            local rare = rareAnimal(model, source)
            local display = speciesLabel(rare and source or animalName or source)
            return "animal", display, lower(animalName or display), rare, canonicalRareKey(display or source)
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
    local function chestLootState(model)
        local hidden, eligible = false, false
        local function read(name, value)
            if type(value) ~= "boolean" then return end
            if name == "Looted" or name == "IsLooted" then
                if value then hidden = true else eligible = true end
            elseif name == "Unlooted" then
                if value then eligible = true else hidden = true end
            elseif name == "Empty" or name == "IsEmpty" then
                if value then hidden = true end
            end
        end
        for _, name in ipairs({"Looted", "IsLooted", "Unlooted", "Empty", "IsEmpty"}) do read(name, model:GetAttribute(name)) end
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BoolValue") then read(child.Name, child.Value) end
        end
        if hidden then return "hidden" end
        if eligible then return "unlooted" end
        return "unknown"
    end
    local function remove(model)
        local item = tracked[model]
        if item then if item.gui then item.gui:Destroy() end; tracked[model] = nil end
    end
    local function add(model)
        if tracked[model] or not model.Parent then return end
        local kind, label, speciesKeyValue, rare, rareKey = classify(model)
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
        speciesKeyValue = kind == "animal" and speciesKeyValue or nil
        if speciesKeyValue and animalTypes[speciesKeyValue] == nil then animalTypes[speciesKeyValue] = animalTypesDefault end
        tracked[model] = {kind=kind, label=label, speciesKey=speciesKeyValue, rare=rare, rareKey=rareKey, part=part, gui=nil, gold=nil, goldChecked=false, nextGoldAt=0, chestState="unknown"}
        if speciesKeyValue and not speciesButtons[speciesKeyValue] then
            speciesButtonCount = speciesButtonCount + 1
            local button = row("  " .. label, 108 + speciesButtonCount)
            button.Visible = false
            speciesButtonLabels[speciesKeyValue] = label
            button.Activated:Connect(function()
                animalTypes[speciesKeyValue] = not animalTypes[speciesKeyValue]
                refreshControls()
            end)
            speciesButtons[speciesKeyValue] = button
        end
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
        local camera = workspaceRoot.CurrentCamera
        if not camera then
            for _, item in pairs(tracked) do if item.gui then item.gui.Enabled = false end end
            return
        end
        if heartbeatClock < 0.1 then return end
        heartbeatClock = 0
        local origin = camera.CFrame.Position
        for model, item in pairs(tracked) do
            if item.kind == "animal" then item.rare = rareAnimal(model, item.label) or item.rare end
            if item.kind == "chest" then
                item.chestState = chestLootState(model)
                if elapsed >= item.nextGoldAt or not item.goldChecked then
                    item.gold = goldFor(model)
                    item.goldChecked = true
                    item.nextGoldAt = elapsed + 1
                end
                if item.gold == 0 then
                    item.chestState = "hidden"
                elseif item.chestState == "unknown" and item.gold and item.gold > 0 then
                    item.chestState = "unlooted"
                end
            end
            local enabled = visibilityEnabled(item)
            if not model.Parent or not item.part.Parent then remove(model)
            elseif not enabled then if item.gui then item.gui.Enabled = false end
            else
                local distance = (item.part.Position - origin).Magnitude
                if distance <= distances[distanceIndex] then
                    if not item.gui then
                        local gui = Instance.new("BillboardGui")
                        gui.Name, gui.AlwaysOnTop, gui.Size = "WorldESP", true, UDim2.fromOffset(190, 26)
                        gui.MaxDistance = distances[distanceIndex] == math.huge and 1000000000 or distances[distanceIndex]
                        gui.StudsOffset = Vector3.new(0, item.part.Size.Y * 0.5 + 2, 0)
                        gui.Adornee, gui.Parent = item.part, playerGui
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
                        label.TextStrokeTransparency = 0.25; label.TextStrokeColor3 = Color3.fromRGB(25, 25, 25)
                        label.Font, label.TextSize = Enum.Font.GothamBold, 13
                        label.Parent = gui
                        item.gui = gui; item.text = label
                    end
                    item.gui.MaxDistance = distances[distanceIndex] == math.huge and 1000000000 or distances[distanceIndex]
                    item.text.Text = item.kind == "animal" and (item.label .. " · " .. math.floor(distance) .. " studs") or ("Treasure chest" .. (item.gold and (" · Gold: " .. tostring(item.gold)) or "") .. " · " .. math.floor(distance) .. " studs")
                        item.text.TextColor3 = item.kind == "animal" and (item.rare and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(180, 255, 180)) or Color3.fromRGB(255, 225, 130)
                    item.gui.Enabled = true
                elseif item.gui then item.gui.Enabled = false end
            end
        end
        if advanced then refreshControls() end
    end))
    refreshControls()
    return cleanup
end

return mount
