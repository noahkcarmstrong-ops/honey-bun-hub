-- Lightweight Roblox stand-ins: checks lifecycle and toggle behavior without a live game.
local function signal()
    local s = {listeners = {}}
    function s:Connect(fn)
        local c = {Connected = true, fn = fn}
        function c:Disconnect() self.Connected = false end
        table.insert(self.listeners, c)
        return c
    end
    function s:Fire(...)
        for _, c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end
    end
    return s
end
local vector = {}
vector.__index = function(v, key)
    if key == 'Magnitude' then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
    return vector[key]
end
local function vec(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vector) end
vector.__sub = function(a,b) return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vector.__add = function(a,b) return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vector.__div = function(a,b) return vec(a.X/b,a.Y/b,a.Z/b) end
Vector2 = {new=vec}; Vector3 = {new=vec}
local cf = {}; cf.__index = cf
cf.__mul = function(a,b) return setmetatable({Position=a.Position+b.Position},cf) end
CFrame = {new=function(x,y,z) return setmetatable({Position=vec(x,y,z)},cf) end}
UDim = {new=function(s,o) return {Scale=s,Offset=o} end}
UDim2 = {new=function(a,b,c,d) return {X=UDim.new(a,b),Y=UDim.new(c,d)} end}
UDim2.fromOffset=function(x,y)return UDim2.new(0,x,0,y)end
Color3 = {fromRGB=function(r,g,b)return {r=r,g=g,b=b}end,new=function(r,g,b)return {r=r,g=g,b=b}end}
local function enum() return setmetatable({}, {__index=function(t,k)local v=enum();rawset(t,k,v);return v end}) end
Enum=enum(); RaycastParams={new=function() return {} end}
math.atan2=math.atan
local objects={}
local methods={}
local objectMeta={__index=function(t,k)return methods[k] or t.props[k]end,
    __newindex=function(t,k,v)t.props[k]=v end}
Instance={new=function(class,parent)
    local o=setmetatable({props={ClassName=class,Name=class,Parent=parent,Visible=true,Enabled=true,Activated=signal(),Destroying=signal()}},objectMeta)
    table.insert(objects,o);return o
end}
function methods:GetChildren()
    local children={};for _,o in ipairs(objects)do if o.Parent==self then table.insert(children,o)end end;return children
end
function methods:FindFirstChild(name)
    for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end
end
function methods:FindFirstChildOfClass(class)
    for _,o in ipairs(self:GetChildren())do if o.ClassName==class then return o end end
end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:IsA(class)return self.ClassName==class end
function methods:GetAttribute(name)return self.attributes and self.attributes[name] end
function methods:IsDescendantOf(parent)
    local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false
end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed=true;self.Destroying:Fire()
    for _,o in ipairs(self:GetChildren())do o:Destroy()end
    self.Parent=nil
end
function methods:GetBoundingBox()return CFrame.new(self:FindFirstChild('HumanoidRootPart').Position.X,0,20),vec(4,6,3)end
local playerGui=Instance.new('PlayerGui')
local localPlayer=Instance.new('Player');localPlayer.Name='Local';playerGui.Parent=localPlayer
local enemy=Instance.new('Player');enemy.Name='TestOutlaw';enemy.DisplayName='Test Outlaw';enemy.Team={Name='Outlaws'};enemy.CharacterAdded=signal()
local players={LocalPlayer=localPlayer,PlayerAdded=signal(),PlayerRemoving=signal(),list={localPlayer,enemy}}
function players:GetPlayers()return self.list end
local run={RenderStepped=signal()}
workspace=Instance.new('Workspace')
local camera={CFrame=CFrame.new(0,0,0),ViewportSize=vec(800,600)}
function camera:WorldToViewportPoint(p)return vec(p.X+400,300-p.Y,p.Z),true end
workspace.CurrentCamera=camera
function workspace:Raycast()return nil end
game={GetService=function(_,name)return assert(({Players=players,RunService=run})[name],name)end}
DateTime={now=function()return {UnixTimestampMillis=1000}end}
loadstring=load
function game:HttpGet()return 'return function() return function() end end' end
warn=print
local content=Instance.new('ScrollingFrame')
local module=dofile('games/westbound.lua')
local cleanup=module.mount(content)
assert(type(cleanup)=='function')
local function toggle(title)
    for _,row in ipairs(content:GetChildren())do
        local match=false
        for _,o in ipairs(row:GetChildren())do if o.ClassName=='TextLabel' and o.Text==title then match=true end end
        if match then for _,o in ipairs(row:GetChildren())do if o.ClassName=='TextButton'then o.Activated:Fire();return end end end
    end
    error('Missing control: '..title)
end
local function find(class)
    for _,o in ipairs(objects)do if o.ClassName==class and not o.destroyed then return o end end
end
local function findTracer()
    for _,o in ipairs(objects)do
        if o.ClassName=='Frame' and not o.destroyed and o.Parent and o.Parent.Name=='HoneyBunWestboundESP' and o.Size and o.Size.X then return o end
    end
end
run.RenderStepped:Fire(.1)
assert(not find('Highlight').Enabled,'ESP must default off')
local character=Instance.new('Model',workspace);enemy.Character=character;enemy.CharacterAdded:Fire(character)
toggle('Player ESP');toggle('Chams');toggle('Tracers');toggle('Visual hitbox')
run.RenderStepped:Fire(.1) -- respawn has no parts yet
local root=Instance.new('Part',character);root.Name='HumanoidRootPart';root.Position=vec(0,0,20);root.Size=vec(2,2,1)
local humanoid=Instance.new('Humanoid',character);humanoid.Health=100
run.RenderStepped:Fire(.1)
assert(find('Highlight').Enabled,'Late-spawned character should acquire parts')
assert(find('SelectionBox').Visible,'Visual hitbox toggle should show outline')
local tracer=findTracer()
assert(tracer and tracer.Visible,'Tracer toggle should show a tracer')
assert(tracer.Position.X.Offset==400 and tracer.Position.Y.Offset==450,'Tracer must be positioned at the midpoint')
assert(tracer.Size.X.Offset==300,'Tracer length should span the two endpoints')
assert(tracer.AnchorPoint.X==.5 and tracer.AnchorPoint.Y==.5,'Tracer rotation must use a centered anchor')
root.Position=vec(0,0,20000);run.RenderStepped:Fire(.1)
assert(find('Highlight').Enabled and tracer.Visible,'Unlimited default must show distant players')
root.Position=vec(0,0,20)
assert(root.Size.X==2 and root.Size.Y==2,'Visuals must not alter actual hitboxes')

local function label()
    for _,o in ipairs(objects)do
        if o.ClassName=='TextLabel' and o.Parent and o.Parent.Name=='HoneyBunWestboundESP' then return o end
    end
end
toggle('Outlaw bounty');run.RenderStepped:Fire(.2)
assert(label().Text:find('Bounty unavailable',1,true),'Missing bounty must not become zero')
local stats=Instance.new('Folder',enemy);stats.Name='leaderstats'
local bounty=Instance.new('IntValue',stats);bounty.Name='Bounty';bounty.Value=1250
run.RenderStepped:Fire(.2)
assert(label().Text:find('Bounty $1250',1,true),'Read replicated bounty')
bounty.Value=0;run.RenderStepped:Fire(.2)
assert(label().Text:find('Bounty $0',1,true),'A real zero bounty must display')
bounty.Value=-1;run.RenderStepped:Fire(.2)
assert(label().Text:find('Bounty unavailable',1,true),'Invalid bounty must not display')
enemy.attributes={Bounty='$2,500'};run.RenderStepped:Fire(.2)
assert(label().Text:find('Bounty $2500',1,true),'Read and format bounty attributes')
toggle('Names');toggle('Distance');toggle('Health');run.RenderStepped:Fire(.2)
assert(label().Visible,'Bounty must work with other label fields off')
enemy.Team={Name='Cowboys'};run.RenderStepped:Fire(.2)
assert(not label().Visible,'Bounty-only labels must not show for Cowboys')
enemy.Team={Name='Outlaws'}
toggle('Names');toggle('Distance');toggle('Health');toggle('Outlaw bounty');run.RenderStepped:Fire(.2)
assert(not label().Text:find('Bounty',1,true),'Bounty toggle must remove amount')
toggle('Team filter');run.RenderStepped:Fire(.1)
assert(not find('Highlight').Enabled,'Outlaw filter must hide Outlaws')
toggle('Team filter');enemy.Team={Name='Cowboys'};run.RenderStepped:Fire(.1)
assert(not find('Highlight').Enabled,'Team change must obey Cowboys filter')
toggle('Team filter');run.RenderStepped:Fire(.1)
assert(find('Highlight').Enabled)
workspace.CurrentCamera=nil;run.RenderStepped:Fire(.1)
assert(not find('Highlight').Enabled,'Missing camera must hide stale visuals')
workspace.CurrentCamera=camera
players.PlayerRemoving:Fire(enemy)
assert(not find('Highlight'),'Leaving player must remove overlays')
for _,c in ipairs(enemy.CharacterAdded.listeners)do assert(not c.Connected,'Player removal must disconnect character listener')end
toggle('Team filter');toggle('Style');toggle('Names');toggle('Outlaw bounty');toggle('Max distance')
for _,o in ipairs(content:GetChildren())do if o.Text=='More player options' then o.Activated:Fire() end end
content:Destroy();cleanup();cleanup()
for _,c in ipairs(run.RenderStepped.listeners)do assert(not c.Connected,'Cleanup must stop rendering')end
content=Instance.new('ScrollingFrame')
cleanup=dofile('games/westbound.lua').mount(content)
local function control(title)
    for _,frame in ipairs(content:GetChildren())do
        for _,o in ipairs(frame:GetChildren())do
            if o.ClassName=='TextLabel' and o.Text==title then
                for _,item in ipairs(frame:GetChildren())do if item.ClassName=='TextButton' then return item end end
            end
        end
    end
    error('Missing control '..title)
end
assert(control('Player ESP').Text=='ON','Player ESP survives loader re-execution')
assert(control('Team filter').Text=='Cowboys' and control('Style').Text=='Outline','Filters and style restore')
assert(control('Names').Text=='OFF' and control('Outlaw bounty').Text=='ON','False and true switches restore')
assert(control('Max distance').Text=='500 studs' and control('Max distance').Parent.Visible,'Range and expanded options restore')
run.RenderStepped:Fire(.2)
assert(find('Highlight').Enabled,'Restored settings enable actual visuals')
toggle('Max distance');assert(control('Max distance').Text=='1000 studs','Distance cycles from restored choice')
content:Destroy();cleanup()
print('Player ESP lifecycle, filters, respawns, toggles, and cleanup passed.')


