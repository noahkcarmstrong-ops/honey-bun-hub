local function signal()
    local s = {listeners = {}}
    function s:Connect(fn)
        local c = {Connected = true, fn = fn}
        function c:Disconnect() self.Connected = false end
        table.insert(self.listeners, c)
        return c
    end
    function s:Fire(...) for _, c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end

local objects, methods = {}, {}
local meta = {__index = function(o, k) return methods[k] or o.props[k] end,
    __newindex = function(o, k, v) o.props[k] = v end}
local function instance(class, parent)
    local o = setmetatable({props={ClassName=class, Name=class, Parent=parent, Destroying=signal(), Activated=signal(), Enabled=true, Visible=true}, attributes={}}, meta)
    table.insert(objects, o); return o
end
Instance = {new = instance}
function methods:IsA(class) return self.ClassName == class or (class == "BasePart" and self.ClassName == "Part") end
function methods:GetChildren()
    local out={}; for _, o in ipairs(objects) do if not o.destroyed and o.Parent == self then table.insert(out,o) end end; return out
end
function methods:GetDescendants()
    local out={}; local function walk(o) for _, c in ipairs(o:GetChildren()) do table.insert(out,c); walk(c) end end; walk(self); return out
end
function methods:FindFirstChild(name) for _, o in ipairs(self:GetChildren()) do if o.Name == name then return o end end end
function methods:FindFirstChildOfClass(class) for _, o in ipairs(self:GetChildren()) do if o:IsA(class) then return o end end end
function methods:FindFirstChildWhichIsA(class) for _, o in ipairs(self:GetDescendants()) do if o:IsA(class) then return o end end end
function methods:FindFirstAncestorOfClass(class)
    local p=self.Parent; while p do if p:IsA(class) then return p end; p=p.Parent end
end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:SetAttribute(name, value) self.attributes[name] = value end
function methods:GetAttributes() return self.attributes end
function methods:GetFullName()
    local names, current = {}, self
    while current do table.insert(names, 1, current.Name); current = current.Parent end
    return table.concat(names, ".")
end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed=true; self.Destroying:Fire(); for _, c in ipairs(self:GetChildren()) do c:Destroy() end; self.Parent=nil
end
local vmeta={__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end end,
    __sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end}
Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vmeta)end}
Vector2={new=Vector3.new}
UDim={new=function(s,o)return {Scale=s,Offset=o}end}
UDim2={new=function(a,b,c,d)return {X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end,
    fromOffset=function(x,y)return UDim2.new(0,x,0,y)end,
    fromScale=function(x,y)return UDim2.new(x,0,y,0)end}
Color3={fromRGB=function(r,g,b)return {R=r,G=g,B=b}end}
local function enum() return setmetatable({}, {__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end
Enum=enum()

local run={Heartbeat=signal()}
local encodedSettings={}
local httpService={}
function httpService:JSONEncode(value) local key="settings-" .. tostring(#encodedSettings + 1); encodedSettings[key]=value; return key end
function httpService:JSONDecode(value) return encodedSettings[value] end
local players={list={}}
players.LocalPlayer=instance("Player")
instance("PlayerGui",players.LocalPlayer)
function players:GetPlayers() return self.list end
function players:GetPlayerFromCharacter(character)
    for _, p in ipairs(self.list) do if p.Character == character then return p end end
end
local collection={signals={}}
function collection:GetInstanceAddedSignal(tag) self.signals[tag]=self.signals[tag] or signal(); return self.signals[tag] end
function collection:HasTag(model, tag) return model.tags and model.tags[tag] or false end
workspace=instance("Workspace")
workspace.CurrentCamera={CFrame={Position=Vector3.new(0,0,0)}}
workspace.DescendantAdded=signal(); workspace.DescendantRemoving=signal()
game={GetService=function(_,name)return ({Players=players,RunService=run,Workspace=workspace,CollectionService=collection,HttpService=httpService})[name] end}
getgenv=function() return {} end

local function model(name, x, attrs)
    local m=instance("Model",workspace); m.Name=name; m.attributes=attrs or {}
    local p=instance("Part",m); p.Name="Root"; p.Position=Vector3.new(x,0,0); p.Size=Vector3.new(2,2,2); m.PrimaryPart=p
    return m
end
local normal=model("Horse",20,{AnimalType="horse"})
local rare=model("Legendary Wolf",30,{AnimalType="wolf",Rare=true})
local chest=model("TreasureChest",40,{Unlooted=true,Gold=100})
local unknownChest=model("UnknownChest",45,{})
local lootedChest=model("LootedChest",50,{Looted=true,Gold=500})
local content=instance("ScrollingFrame")
local clipboard
setclipboard=function(value) clipboard=value end
local module=dofile("games/world.lua")
local cleanup=module(content)
local function fire(text)
    for _, o in ipairs(content:GetChildren()) do
        if o.ClassName=="TextButton" and o.Text==text then o.Activated:Fire(); return end
    end
    error("missing control: "..text)
end
local function control(text)
    for _,o in ipairs(content:GetChildren()) do if o.Text==text then return o end end
    error("missing control: "..text)
end
local function findHighlights()
    local n=0; for _,o in ipairs(objects) do if o.ClassName=="Highlight" and not o.destroyed and o.Enabled then n=n+1 end end; return n
end
run.Heartbeat:Fire(.11)
assert(findHighlights()==0,"chams default off")
fire("Treasure chests: OFF")
run.Heartbeat:Fire(.11)
local function chestMarker(text)
    for _,o in ipairs(objects) do
        if o.ClassName=="BillboardGui" and o.Enabled and o.Adornee==chest.PrimaryPart and o:FindFirstChildOfClass("TextLabel") then
            if not text or o:FindFirstChildOfClass("TextLabel").Text:find(text,1,true) then return o end
        end
    end
end
assert(chestMarker("Gold: 100"),"confirmed unlooted chest is visible")
assert(not (function() for _,o in ipairs(objects) do if o.ClassName=="BillboardGui" and o.Enabled and o.Adornee==unknownChest.PrimaryPart then return true end end end)(),"unknown chest is hidden")
assert(not (function() for _,o in ipairs(objects) do if o.ClassName=="BillboardGui" and o.Enabled and o.Adornee==lootedChest.PrimaryPart then return true end end end)(),"looted chest is hidden")
fire("Animal ESP: OFF")
fire("Animal chams: OFF")
assert(findHighlights()==0,"disabled animals have no chams")
run.Heartbeat:Fire(.11)
assert(findHighlights()==2,"chams follow animal ESP: " .. findHighlights())
local rareHighlight
for _,o in ipairs(objects) do if o.ClassName=="Highlight" and o.Adornee==rare then rareHighlight=o end end
assert(rareHighlight and rareHighlight.DepthMode==Enum.HighlightDepthMode.AlwaysOnTop,"chams stay on top")
assert(rareHighlight.FillColor.R==255 and rareHighlight.FillColor.G==205,"rare chams are gold")
fire("Choose animals");fire("Choose rare animals")
assert(control("Horse: ON").Visible and control("Legendary Wolf: ON").Visible,"expanded lists show choices")
assert(control("Horse: ON").LayoutOrder<control("Hide rare animal choices").LayoutOrder,"normal species stay in their section")
assert(control("Legendary Wolf: ON").LayoutOrder<control("TREASURE").LayoutOrder,"rare species stay before treasure")
fire("Horse: ON");run.Heartbeat:Fire(.11)
assert(findHighlights()==1,"species selection hides matching chams")
fire("Hide animal choices");fire("Choose animals")
assert(control("Horse: OFF"),"opening lists preserves selections")
fire("Horse: OFF");run.Heartbeat:Fire(.11)
local late=model("Bison",25,{AnimalType="bison"})
workspace.DescendantAdded:Fire(late);run.Heartbeat:Fire(.11)
assert(control("Bison: ON").Visible,"newly discovered species appear in open list")
workspace.DescendantRemoving:Fire(late);late:Destroy()
fire("Rare animals only: OFF"); run.Heartbeat:Fire(.11)
assert(findHighlights()==1,"rare filter hides normal chams")
fire("Animal chams: ON"); run.Heartbeat:Fire(.11); assert(findHighlights()==0,"toggle hides chams")
fire("Animal chams: OFF"); fire("More world options"); fire("Distance: Unlimited"); run.Heartbeat:Fire(.11)
fire("Copy visibility report")
assert(clipboard and clipboard:find("Chest ESP: ON",1,true),"report includes chest toggle")
assert(clipboard:find("Chest details",1,true),"report includes chest details")
assert(clipboard:find("state=unlooted",1,true),"report includes chest state")
assert(clipboard:find('Unlooted="true"',1,true),"report includes chest attribute")
normal.PrimaryPart.Position=Vector3.new(9999,0,0); rare.PrimaryPart.Position=Vector3.new(9999,0,0); run.Heartbeat:Fire(.11)
assert(findHighlights()==0,"distance hides chams")
rare.PrimaryPart.Position=Vector3.new(30,0,0);run.Heartbeat:Fire(.11)
assert(findHighlights()==1,"animal inside range restores chams")
workspace.CurrentCamera=nil; run.Heartbeat:Fire(.11); assert(findHighlights()==0,"missing camera hides chams")
workspace.CurrentCamera={CFrame={Position=Vector3.new(0,0,0)}}
rare.PrimaryPart.Position=Vector3.new(30,0,0);run.Heartbeat:Fire(.11)
assert(findHighlights()==1,"restored camera and range restore chams")
workspace.DescendantRemoving:Fire(rare); rare:Destroy(); assert(findHighlights()==0 and rareHighlight.destroyed,"removal destroys chams")
fire("All animals: OFF"); fire("All rare animals: OFF")
local persistedGui=players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
assert(type(persistedGui:GetAttribute("HoneyBunWorldSettings_0"))=="string","settings backup is written to PlayerGui")
content:Destroy(); cleanup(); cleanup()
for _,o in ipairs(objects) do if o.ClassName=="Highlight" then assert(o.destroyed,"cleanup destroys highlights") end end
for _, c in ipairs(run.Heartbeat.listeners) do assert(not c.Connected,"cleanup disconnects heartbeat") end
local remountContent=instance("ScrollingFrame")
local remounted=dofile("games/world.lua")(remountContent)
run.Heartbeat:Fire(.11)
local function remountControl(text)
    for _,o in ipairs(remountContent:GetChildren()) do if o.Text==text then return o end end
    error("missing restored control: " .. text)
end
assert(remountControl("Animal chams: ON"),"chams setting restored")
assert(remountControl("Treasure chests: ON"),"chest setting restored")
assert(remountControl("Rare animals only: ON"),"rare-only setting restored")
assert(remountControl("Hide world options"),"advanced setting restored")
assert(remountControl("Hide animal choices"),"animal list expansion restored")
assert(remountControl("Hide rare animal choices"),"rare list expansion restored")
assert(remountControl("Distance: 500"),"distance setting restored")
assert(remountControl("Horse: OFF"),"false normal species selection restored")
assert(remountControl("Dire Wolf: OFF"),"false rare selection restored")
remountControl("Distance: 500").Activated:Fire()
assert(remountControl("Distance: 1000"),"distance advances from restored index")
remountContent:Destroy(); remounted()
print("World ESP chams, filters, range, removal, and cleanup passed.")
