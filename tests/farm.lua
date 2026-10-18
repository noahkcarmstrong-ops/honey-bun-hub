local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end;table.insert(self.listeners,c);return c end
    function s:Fire(...)for _,c in ipairs(s.listeners)do if c.Connected then c.fn(...)end end end
    return s
end
local objects, methods = {}, {}
local meta={__index=function(o,k) if methods[k] then return methods[k] end; local value=rawget(o.props,k); if value ~= nil then return value end; for _,child in ipairs(objects) do if not rawget(child,"destroyed") and rawget(child.props,"Parent")==o and rawget(child.props,"Name")==k then return child end end end,__newindex=function(o,k,v)o.props[k]=v; if k=="CFrame" and v.Position then o.props.Position=v.Position end end}
local function inst(class,parent)
    local o=setmetatable({props={ClassName=class,Name=class,Parent=parent,Destroying=signal(),Activated=signal(),Enabled=true,Visible=true},attributes={}},meta);table.insert(objects,o);return o
end
Instance={new=inst}
function methods:IsA(c)return self.ClassName==c or c=="BasePart" and self.ClassName=="Part" end
function methods:GetChildren()local r={};for _,o in ipairs(objects)do if not o.destroyed and o.Parent==self then table.insert(r,o)end end;return r end
function methods:GetDescendants()local r={};local function walk(o)for _,c in ipairs(o:GetChildren())do table.insert(r,c);walk(c)end end;walk(self);return r end
function methods:FindFirstChild(n)for _,o in ipairs(self:GetChildren())do if o.Name==n then return o end end end
function methods:FindFirstChildOfClass(c)for _,o in ipairs(self:GetChildren())do if o:IsA(c)then return o end end end
function methods:FindFirstChildWhichIsA(c)for _,o in ipairs(self:GetDescendants())do if o:IsA(c)then return o end end end
function methods:IsDescendantOf(other)local node=self.Parent;while node do if node==other then return true end;node=node.Parent end;return false end
function methods:GetFullName()return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function methods:GetAttribute(n)return self.attributes[n]end
function methods:SetAttribute(n,v)self.attributes[n]=v end
function methods:Destroy()if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire();for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil end
local vm={__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end,__index=function(v,k)if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end}
RaycastParams={new=function()return {} end};OverlapParams={new=function()return {} end}
CFrame={new=function(x,y,z)return {Position=Vector3.new(x,y,z)} end}
Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm)end}
UDim={new=function(s,o)return{Scale=s,Offset=o}end};UDim2={new=function(a,b,c,d)return{X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end,fromOffset=function(x,y)return UDim2.new(0,x,0,y)end}
Color3={fromRGB=function(r,g,b)return{R=r,G=g,B=b}end};local function enum()return setmetatable({}, {__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end;Enum=enum()
local run={Heartbeat=signal()};local player=inst("Player");local gui=inst("PlayerGui",player);local players={LocalPlayer=player,list={player}}
function players:GetPlayers()return self.list end
local char=inst("Model");char.Parent=workspace;local hum=inst("Humanoid",char);hum.Health=100;local root=inst("Part",char);root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1);root.Position=Vector3.new(0,0,0);root.CFrame={Position=root.Position};char.PrimaryPart=root;player.Character=char
local states=inst("Folder",player);states.Name="States";local bag=inst("NumberValue",states);bag.Name="Bag";bag.Value=0
local stats=inst("Folder",player);stats.Name="Stats";local bagLevel=inst("Folder",stats);bagLevel.Name="BagSizeLevel";local capacity=inst("NumberValue",bagLevel);capacity.Name="CurrentAmount";capacity.Value=10
local workspaceRoot=inst("Workspace");workspace=workspaceRoot;workspace.DescendantAdded=signal();workspace.DescendantRemoving=signal()
workspace.CurrentCamera={CFrame={Position=Vector3.new(0,0,0)}}
local events=inst("Folder");events.Name="GeneralEvents";local rob=inst("RemoteEvent",events);rob.Name="Rob";rob.calls={};function rob:FireServer(...)table.insert(self.calls,{...})end
local register=inst("Model",workspace);register.Name="CashRegister";local open=inst("Part",register);open.Name="Open";open.Position=Vector3.new(5,0,0);open.CFrame={Position=open.Position};local union=inst("Part",register);union.Name="Union";local active=inst("BoolValue",register);active.Name="Active";active.Value=true
local safe=inst("Model",workspace);safe.Name="Safe";local amount=inst("NumberValue",safe);amount.Name="Amount";amount.Value=20;local safePart=inst("Part",safe);safePart.Name="Safe";safePart.Position=Vector3.new(6,0,0);safePart.CFrame={Position=safePart.Position};local openSafe=inst("BoolValue",safe);openSafe.Name="Open";openSafe.Value=false;local openRemote=inst("RemoteEvent",safe);openRemote.Name="OpenSafe";openRemote.calls={};function openRemote:FireServer(...)table.insert(self.calls,{...})end
local ground=inst("Part",workspace);ground.CanCollide=true;ground.Anchored=true
local floorAvailable,blocked,slope,water,edge=false,false,1,false,false
function workspace:Raycast(origin,direction,params)
    assert(params.RespectCanCollide and params.FilterDescendantsInstances[1]==char,"ground ray excludes character")
    if not floorAvailable or (edge and direction.Y == -4) then return nil end
    return {Position=Vector3.new(origin.X,0,origin.Z),Normal=Vector3.new(0,slope,0),Material=water and Enum.Material.Water or Enum.Material.Grass,Instance=ground}
end
function workspace:GetPartBoundsInBox(cf,size,params)
    assert(size.X>=4 and size.Y>=6 and params.RespectCanCollide,"clearance checks full standing body")
    return blocked and {ground} or {}
end
local rep=inst("ReplicatedStorage");events.Parent=rep
game={GameId=123,GetService=function(_,n)return({Players=players,RunService=run,ReplicatedStorage=rep,Workspace=workspace})[n]end}
local content=inst("ScrollingFrame");local module=dofile("games/farm.lua");local cleanup=module(content)
local function fire(text)for _,o in ipairs(content:GetChildren())do if o.ClassName=="TextButton" and o.Text==text then o.Activated:Fire();return end end;error("missing "..text)end
local function labelText(prefix)for _,o in ipairs(content:GetChildren())do if o.ClassName=="TextLabel" and o.Text:sub(1,#prefix)==prefix then return o.Text end end end
run.Heartbeat:Fire(.2);assert(#rob.calls==0,"idle farm makes no calls")
local originalFrame=root.CFrame
capacity.Value=0;fire("Start");assert(labelText("Cannot start: bag data unavailable"),"capacity guard");capacity.Value=10;fire("Start");run.Heartbeat:Fire(.2); assert(root.CFrame==originalFrame,"farm must never teleport into target")
run.Heartbeat:Fire(.4);assert(#rob.calls==1 and rob.calls[1][1]=="Register" and rob.calls[1][2].Part==union,"register payload")
run.Heartbeat:Fire(.4);assert(#rob.calls==1,"observation does not repeat remote calls")
bag.Value=3;run.Heartbeat:Fire(.2);assert(labelText("Bag: 3/10"),"positive bag delta observed")
fire("Stop");local calls=#rob.calls;run.Heartbeat:Fire(2);assert(#rob.calls==calls,"stop cancels late calls")
register:Destroy();workspace.DescendantRemoving:Fire(register);bag.Value=0;fire("Start");run.Heartbeat:Fire(.2);run.Heartbeat:Fire(.4);assert(#openRemote.calls==1 and openRemote.calls[1][1]=="Completed","closed safe opens once");run.Heartbeat:Fire(.4);assert(#rob.calls==1,"safe robbery waits for replicated open state");openSafe.Value=true;run.Heartbeat:Fire(.4);assert(#rob.calls==2 and rob.calls[2][1]=="Safe","safe payload")
bag.Value=5;run.Heartbeat:Fire(.2);fire("Stop");content:Destroy();cleanup();cleanup();assert(not run.Heartbeat.listeners[1].Connected,"cleanup disconnects heartbeat")
-- Mode and cash-in persist, but a fresh module must remain stopped.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
calls=#rob.calls;run.Heartbeat:Fire(2);assert(#rob.calls==calls,"reload never auto-starts")
fire("Mode: Registers + safes");fire("Mode: Registers")
content:Destroy();cleanup();content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
fire("Mode: Safes");fire("Mode: Registers + safes");fire("Mode: Registers")
-- Full bags stop without teleporting to an unverified drop-off.
bag.Value=10;fire("Start");run.Heartbeat:Fire(.2)
assert(root.CFrame==originalFrame,"full bag cannot teleport")
assert(labelText("Bag full:"),"full bag stops for normal cash-in")
assert(#rob.calls==calls,"full bag never triggers robbery requests")
bag.Value=0
-- Far targets with no grounded landing never move or make requests.
local savedPosition=safePart.Position;safePart.Position=Vector3.new(100,0,0)
fire("Start");run.Heartbeat:Fire(2);run.Heartbeat:Fire(1)
assert(root.CFrame==originalFrame and #rob.calls==calls,"distant targets cannot teleport or rob")
fire("Stop");safePart.Position=savedPosition
-- Taking damage cancels a pending action.
fire("Start");run.Heartbeat:Fire(.2);hum.Health=90;run.Heartbeat:Fire(.4)
assert(labelText("Stopped: damage detected"),"damage stops pending action")
assert(#rob.calls==calls,"damage cancels pending request")
hum.Health=100
-- Exception and rejection paths must both have finite attempt budgets.
openSafe.Value=true
local normalFire=rob.FireServer
function rob:FireServer(...) table.insert(self.calls,{...});error("simulated rejection") end
fire("Start")
for _=1,150 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==calls+3,"remote errors stop after three attempts")
assert(labelText("Repeated collection failures"),"remote errors produce stopped state")
rob.FireServer=normalFire;calls=#rob.calls;fire("Start")
for _=1,150 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==calls+3,"unconfirmed collection stops after three attempts")
assert(labelText("No collection confirmed"),"no payout produces stopped state")
content:Destroy();cleanup();content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
bag.Value=0;fire("Start");run.Heartbeat:Fire(.2)
calls=#rob.calls;content:Destroy();cleanup();run.Heartbeat:Fire(1)
assert(#rob.calls==calls,"cleanup cancels a pending request")
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
fire("Start");run.Heartbeat:Fire(.2);capacity.Value=0;run.Heartbeat:Fire(.4)
assert(labelText("Stopped: bag data unavailable"),"lost bag data stops a pending action")
assert(#rob.calls==calls,"invalid bag data cannot trigger a request")
capacity.Value=10;fire("Start");hum.Health=0;run.Heartbeat:Fire(.5)
assert(labelText("Stopped: character unavailable"),"death stops the farm")
hum.Health=100
local copied;setclipboard=function(value)copied=value end
fire("Copy farm report");assert(copied and copied:find("Safe",1,true),"report includes live target details")
content:Destroy();cleanup()
-- Loaded distant targets use a clear grounded offset, then wait for the landing.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
local folder=inst("Folder",workspace);safe.Parent=folder
safePart.Position=Vector3.new(100,0,0);root.CFrame=originalFrame
floorAvailable=true;bag.Value=0;hum.Health=100;openSafe.Value=true
calls=#rob.calls;fire("Start");run.Heartbeat:Fire(.2)
assert(root.Position.X==106 and root.Position.Y>3,"distant nested target lands beside target above ground")
assert(#rob.calls==calls,"teleport never fires robbery immediately")
run.Heartbeat:Fire(.4);assert(#rob.calls==calls,"landing must settle before request")
run.Heartbeat:Fire(.4);assert(#rob.calls==calls+1,"settled landing can rob")
bag.Value=1;run.Heartbeat:Fire(.2);run.Heartbeat:Fire(2)
assert(#rob.calls==calls+1,"successful targets back off instead of repeated robbing")
fire("Stop");content:Destroy();cleanup()
-- Unsafe geometry is skipped, not teleported into.
local function rejectedLanding(reason)
    content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
    root.CFrame=originalFrame;calls=#rob.calls;fire("Start");run.Heartbeat:Fire(.2);run.Heartbeat:Fire(1)
    assert(root.CFrame==originalFrame and #rob.calls==calls,reason)
    content:Destroy();cleanup()
end
edge=true;rejectedLanding("cliff edge prevents teleport");edge=false
blocked=true;rejectedLanding("blocked body clearance prevents teleport");blocked=false
slope=.5;rejectedLanding("steep ground prevents teleport");slope=1
water=true;rejectedLanding("water prevents teleport");water=false
floorAvailable=false;rejectedLanding("unloaded ground prevents teleport");floorAvailable=true
-- A server correction or damage during landing stops before any request.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);calls=#rob.calls
root.CFrame=originalFrame;run.Heartbeat:Fire(.9)
assert(labelText("Stopped: landing rejected") and #rob.calls==calls,"server correction stops route")
content:Destroy();cleanup()
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);hum.Health=99;run.Heartbeat:Fire(.01)
assert(labelText("Stopped: damage detected") and #rob.calls==calls,"damage stops without waiting for next action tick")
content:Destroy();cleanup();hum.Health=100
-- Falling/unsettled landings time out; never rob in midair.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2)
hum.FloorMaterial=Enum.Material.Air
for _=1,8 do run.Heartbeat:Fire(.5) end
assert(labelText("Stopped: landing did not settle") and #rob.calls==calls,"airborne landing times out without request")
content:Destroy();cleanup();hum.FloorMaterial=Enum.Material.Grass
-- Bag changes and streamed/replaced parts cancel collection safely.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);bag.Value=10;run.Heartbeat:Fire(.9)
assert(labelText("Bag full:") and #rob.calls==calls,"full bag during landing prevents robbery")
content:Destroy();cleanup();bag.Value=0
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);safePart.Parent=nil;run.Heartbeat:Fire(.9)
assert(#rob.calls==calls,"removed target cannot trigger pending request")
content:Destroy();cleanup();safePart.Parent=safe
print("Grounded teleport routing, clearance, streaming gaps, server correction, damage, nested targets, cooldown backoff passed.")
print("Farm payloads, confirmed safe opening, collection observation, full bags, bounded failures, stop, and cleanup passed.")
