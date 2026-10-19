local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={Connected=true,fn=fn};function c:Disconnect()self.Connected=false end;table.insert(self.listeners,c);return c end
    function s:Fire(...)for _,c in ipairs(s.listeners)do if c.Connected then c.fn(...)end end end
    return s
end
local objects, methods = {}, {}
local meta={__index=function(o,k) if methods[k] then return methods[k] end; local value=rawget(o.props,k); if value ~= nil then return value end; for _,child in ipairs(objects) do if not rawget(child,"destroyed") and rawget(child.props,"Parent")==o and rawget(child.props,"Name")==k then return child end end end,__newindex=function(o,k,v)o.props[k]=v; if k=="CFrame" and v.Position then o.props.Position=v.Position; if o.props.afterMove then o.props.afterMove(v) end end end}
local function inst(class,parent)
    local o=setmetatable({destroyed=false,props={ClassName=class,Name=class,Parent=parent,Destroying=signal(),Activated=signal(),Enabled=true,Visible=true},attributes={}},meta);table.insert(objects,o);return o
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
function methods:GetPivot()return self.PrimaryPart and self.PrimaryPart.CFrame or CFrame.new(0,0,0)end
function methods:Destroy()if self.destroyed then return end;self.destroyed=true;self.Destroying:Fire();for _,c in ipairs(self:GetChildren())do c:Destroy()end;self.Parent=nil end
local vm={__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end,__index=function(v,k)if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end}
RaycastParams={new=function()return {} end};OverlapParams={new=function()return {} end}
CFrame={new=function(x,y,z)return {Position=Vector3.new(x,y,z)} end}
Vector3={new=function(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm)end}
UDim={new=function(s,o)return{Scale=s,Offset=o}end};UDim2={new=function(a,b,c,d)return{X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end,fromOffset=function(x,y)return UDim2.new(0,x,0,y)end}
Color3={fromRGB=function(r,g,b)return{R=r,G=g,B=b}end};local function enum()return setmetatable({}, {__index=function(t,k)local v=enum();rawset(t,k,v);return v end})end;Enum=enum()
local run={Heartbeat=signal()};local player=inst("Player");local gui=inst("PlayerGui",player);local players={LocalPlayer=player,list={player}}
function players:GetPlayers()return self.list end
local char=inst("Model");char.Parent=workspace;local hum=inst("Humanoid",char);hum.HealthChanged=signal();hum.Died=signal();hum.Health=100;local root=inst("Part",char);root.Name="HumanoidRootPart";root.Size=Vector3.new(2,2,1);root.Position=Vector3.new(0,0,0);root.CFrame={Position=root.Position};char.PrimaryPart=root;player.Character=char
local states=inst("Folder",player);states.Name="States";local bag=inst("NumberValue",states);bag.Name="Bag";bag.Value=0
local stats=inst("Folder",player);stats.Name="Stats";local bagLevel=inst("Folder",stats);bagLevel.Name="BagSizeLevel";local capacity=inst("NumberValue",bagLevel);capacity.Name="CurrentAmount";capacity.Value=10
local workspaceRoot=inst("Workspace");workspace=workspaceRoot;workspace.DescendantAdded=signal();workspace.DescendantRemoving=signal()
workspace.CurrentCamera={CFrame={Position=Vector3.new(0,0,0)}}
local events=inst("Folder");events.Name="GeneralEvents";local rob=inst("RemoteEvent",events);rob.Name="Rob";rob.calls={};function rob:FireServer(...)table.insert(self.calls,{...})end
local register=inst("Model",workspace);register.Name="CashRegister";local open=inst("Part",register);open.Name="Open";open.Position=Vector3.new(5,0,0);open.CFrame={Position=open.Position};local union=inst("Part",register);union.Name="Union";local active=inst("BoolValue",register);active.Name="Active";active.Value=true
local safe=inst("Model",workspace);safe.Name="Safe";local amount=inst("NumberValue",safe);amount.Name="Amount";amount.Value=20;local safePart=inst("Part",safe);safePart.Name="Safe";safePart.Position=Vector3.new(6,0,0);safePart.CFrame={Position=safePart.Position};local openSafe=inst("BoolValue",safe);openSafe.Name="Open";openSafe.Value=false;local openRemote=inst("RemoteEvent",safe);openRemote.Name="OpenSafe";openRemote.calls={};function openRemote:FireServer(...)table.insert(self.calls,{...})end
local ground=inst("Part",workspace);ground.CanCollide=true;ground.Anchored=true
local campFar=inst("Part",workspace);campFar.Name="OutlawCamp2";campFar.Position=Vector3.new(100,0,0);campFar.CFrame={Position=campFar.Position};campFar.CanCollide=true;campFar.Anchored=true
local camp=inst("Part",workspace);camp.Name="OutlawCampCashIn";camp.Position=Vector3.new(7,0,0);camp.CFrame={Position=camp.Position};camp.CanCollide=true;camp.Anchored=true
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
local function ensureMode(text)for _=1,6 do for _,o in ipairs(content:GetChildren())do if o.ClassName=="TextButton" and o.Text==text then return end end;for _,o in ipairs(content:GetChildren())do if o.ClassName=="TextButton" and o.Text:sub(1,5)=="Mode:" then o.Activated:Fire();break end end end;error("mode unavailable: "..text)end
local function labelText(prefix)for _,o in ipairs(content:GetChildren())do if o.ClassName=="TextLabel" and o.Text:sub(1,#prefix)==prefix then return o.Text end end end
run.Heartbeat:Fire(.2);assert(#rob.calls==0,"idle farm makes no calls")
local originalFrame=root.CFrame
capacity.Value=0;fire("Start");assert(labelText("Cannot start: bag data unavailable"),"capacity guard");capacity.Value=10;fire("Start");run.Heartbeat:Fire(.2); assert(root.CFrame==originalFrame,"farm must never teleport into target")
run.Heartbeat:Fire(.4);assert(#rob.calls==1 and rob.calls[1][1]=="Register" and rob.calls[1][2].Part==union,"register payload")
run.Heartbeat:Fire(.4);assert(#rob.calls==1,"observation does not repeat remote calls")
bag.Value=3;run.Heartbeat:Fire(.2);assert(labelText("Bag: 3/10"),"positive bag delta observed")
fire("Stop");local calls=#rob.calls;run.Heartbeat:Fire(2);assert(#rob.calls==calls,"stop cancels late calls")
active.Value=false;fire("Mode: Registers + safes");fire("Start");run.Heartbeat:Fire(.4);assert(#rob.calls==calls,"inactive registers are ignored");fire("Stop");active.Value=true;fire("Mode: Registers");fire("Mode: Safes");
register:Destroy();workspace.DescendantRemoving:Fire(register);bag.Value=0;fire("Start");run.Heartbeat:Fire(.2);run.Heartbeat:Fire(.4);assert(#openRemote.calls==1 and openRemote.calls[1][1]=="Completed","closed safe opens once");run.Heartbeat:Fire(.4);assert(#rob.calls==1,"safe robbery waits for replicated open state");openSafe.Value=true;run.Heartbeat:Fire(.4);assert(#rob.calls==2 and rob.calls[2][1]=="Safe","safe payload")
bag.Value=5;run.Heartbeat:Fire(.2);fire("Stop");content:Destroy();cleanup();cleanup();assert(not run.Heartbeat.listeners[1].Connected,"cleanup disconnects heartbeat")
-- Mode and cash-in persist, but a fresh module must remain stopped.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
calls=#rob.calls;run.Heartbeat:Fire(2);assert(#rob.calls==calls,"reload never auto-starts")
fire("Mode: Registers + safes");fire("Mode: Registers")
content:Destroy();cleanup();content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
fire("Mode: Safes");fire("Mode: Registers + safes");fire("Mode: Registers")
-- Full bags select the nearest loaded camp, wait for empty bag, then resume.
bag.Value=10;fire("Start");run.Heartbeat:Fire(.2)
assert(root.CFrame==originalFrame,"nearby camp needs no teleport")
assert(labelText("Returning to Workspace.OutlawCampCashIn"),"closest recognized camp selected")
assert(labelText("Cash-in") or labelText("Deposit") or labelText("Waiting") or labelText("Returning"),"full bag waits at camp")
assert(#rob.calls==calls,"full bag never triggers robbery requests")
bag.Value=5;run.Heartbeat:Fire(.4);assert(#rob.calls==calls,"partial bag does not resume farming")
bag.Value=0
for _=1,5 do run.Heartbeat:Fire(.2) end
assert(#rob.calls==calls+1,"empty bag resumes farming after deposit")
fire("Stop");calls=#rob.calls;bag.Value=0
content:Destroy();cleanup();content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
bag.Value=10;root.CFrame=originalFrame;local depositCalls=#rob.calls;fire("Start");run.Heartbeat:Fire(.2);content:Destroy();cleanup();bag.Value=0;run.Heartbeat:Fire(2)
assert(#rob.calls==depositCalls and root.CFrame==originalFrame,"cleanup cancels an active cash-in")
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);bag.Value=0
-- A reached camp that does not empty the bag times out and selects the next one.
local previousFarPosition=campFar.Position
campFar.Position=Vector3.new(9,0,0);root.CFrame=originalFrame;bag.Value=10
fire("Start");run.Heartbeat:Fire(.2);run.Heartbeat:Fire(.2)
assert(labelText("Waiting for bag to empty at Workspace.OutlawCampCashIn"),"first camp reached")
run.Heartbeat:Fire(10.1);run.Heartbeat:Fire(.2)
assert(labelText("Returning to Workspace.OutlawCamp2"),"cash-in timeout selects next nearest camp")
run.Heartbeat:Fire(.2);bag.Value=0;run.Heartbeat:Fire(.3)
assert(labelText("Bag emptied; continuing route"),"alternate camp empty bag resumes route")
assert(#rob.calls==depositCalls,"camp timeout never issues robbery requests")
fire("Stop");campFar.Position=previousFarPosition;content:Destroy();cleanup()
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
-- Failed first camp times out without issuing a robbery request.
local campPosition,farCampPosition=camp.Position,campFar.Position
camp.Position=Vector3.new(20,0,0);campFar.Position=Vector3.new(25,0,0);floorAvailable=false;bag.Value=10
root.CFrame=originalFrame;fire("Start");for _=1,24 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==depositCalls and labelText("Cash-in unavailable"),"failed camps time out without robbery")
floorAvailable=true;camp.Position=campPosition;campFar.Position=farCampPosition;bag.Value=0;content:Destroy();cleanup()
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
-- Far targets with no grounded landing never move or make requests.
local savedPosition=safePart.Position;safePart.Position=Vector3.new(100,0,0)
floorAvailable=false;fire("Start");run.Heartbeat:Fire(2);run.Heartbeat:Fire(1)
assert(root.CFrame==originalFrame and #rob.calls==calls,"distant targets cannot teleport or rob")
fire("Stop");floorAvailable=true;safePart.Position=savedPosition
-- Taking damage cancels a pending action.
fire("Start");run.Heartbeat:Fire(.2);hum.Health=90;run.Heartbeat:Fire(.4)
assert(labelText("Stopped: damage detected"),"damage stops pending action")
assert(#rob.calls==calls,"damage cancels pending request")
hum.Health=100
-- Collection errors and missing bag gains back off per target without stopping the run.
openSafe.Value=true
local normalFire=rob.FireServer
function rob:FireServer(...) table.insert(self.calls,{...});error("simulated rejection") end
fire("Start")
run.Heartbeat:Fire(.2);local errorCalls=#rob.calls
for _=1,28 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==errorCalls,"retry backoff delays second collection attempt")
run.Heartbeat:Fire(1);assert(#rob.calls==errorCalls+1,"retry occurs after 15 second delay")
for _=1,58 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==errorCalls+1,"second retry uses 30 second delay")
for _=1,4 do run.Heartbeat:Fire(.5) end
assert(#rob.calls==errorCalls+2,"second retry occurs after 30 second delay")
assert(not labelText("Repeated collection failures"),"collection errors do not stop the run")
rob.FireServer=normalFire;fire("Stop");calls=#rob.calls;fire("Start")
for _=1,20 do run.Heartbeat:Fire(.5) end
assert(not labelText("No collection confirmed"),"no payout does not stop the run")
fire("Stop")
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
-- A server correction skips the rejected target without stopping the route.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
local secondSafe=inst("Model",workspace);secondSafe.Name="Safe";local secondAmount=inst("NumberValue",secondSafe);secondAmount.Name="Amount";secondAmount.Value=20;local secondPart=inst("Part",secondSafe);secondPart.Name="Safe";secondPart.Position=Vector3.new(106,0,0);secondPart.CFrame={Position=secondPart.Position};secondPart.CanCollide=true;secondPart.Anchored=true;local secondOpen=inst("BoolValue",secondSafe);secondOpen.Name="Open";secondOpen.Value=true
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);calls=#rob.calls
root.CFrame=originalFrame;run.Heartbeat:Fire(.9)
assert(labelText("Skipping failed target") and #rob.calls==calls,"server correction backs off target")
for _=1,8 do run.Heartbeat:Fire(.3) end
assert(#rob.calls==calls+1 and rob.calls[#rob.calls][1]=="Safe","next grounded target collects after correction")
calls=#rob.calls;fire("Stop");secondSafe:Destroy();content:Destroy();cleanup()
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
assert((labelText("Returning") or labelText("Waiting")) and #rob.calls==calls,"full bag during landing starts cash-in")
content:Destroy();cleanup();bag.Value=0
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);safePart.Parent=nil;run.Heartbeat:Fire(.9)
assert(#rob.calls==calls,"removed target cannot trigger pending request")
content:Destroy();cleanup();safePart.Parent=safe;safe.Parent=workspace
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
-- A streamed shop scout should rescan newly loaded targets and resume farming.
local streamShops=inst("Folder",workspace);streamShops.Name="Shops";local streamAnchor=inst("Part",streamShops);streamAnchor.Name="OutlawGeneralStore9";streamAnchor.Position=Vector3.new(40,0,0);streamAnchor.CFrame={Position=streamAnchor.Position}
local streamedRegister
workspace.StreamingEnabled=true;task={spawn=function(fn)fn()end}
function player:RequestStreamAroundAsync()safe.Parent=workspace;openSafe.Value=true;streamedRegister=inst("Model",workspace);streamedRegister.Name="CashRegister";local streamedOpen=inst("Part",streamedRegister);streamedOpen.Name="Open";streamedOpen.Position=Vector3.new(5,0,0);streamedOpen.CFrame={Position=streamedOpen.Position};local streamedUnion=inst("Part",streamedRegister);streamedUnion.Name="Union";local streamedActive=inst("BoolValue",streamedRegister);streamedActive.Name="Active";streamedActive.Value=true end
safe.Parent=nil;bag.Value=0;root.Position=Vector3.new(0,0,0);root.CFrame={Position=root.Position}
safe.Parent=workspace;openSafe.Value=false;openRemote.Parent=nil;ensureMode("Mode: Registers + safes")
bag.Value=0;root.CFrame=originalFrame;local streamCalls=#rob.calls;fire("Start");for _=1,8 do run.Heartbeat:Fire(.3) end
assert(streamedRegister and #rob.calls==streamCalls+1 and rob.calls[#rob.calls][1]=="Register","shop streaming recovers from only a blocked safe and resumes register farming")
fire("Stop");streamedRegister:Destroy();openRemote.Parent=safe;openSafe.Value=true;safe.Parent=workspace;workspace.StreamingEnabled=false;streamShops:Destroy();content:Destroy();cleanup()
-- A canceled stream callback cannot move or restart the route.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);local queued
local cancelShops=inst("Folder",workspace);cancelShops.Name="Shops";local cancelAnchor=inst("Part",cancelShops);cancelAnchor.Name="OutlawGeneralStore10";cancelAnchor.Position=Vector3.new(40,0,0);cancelAnchor.CFrame={Position=cancelAnchor.Position}
workspace.StreamingEnabled=true;task.spawn=function(fn)queued=fn end;safe.Parent=nil;local cancelCalls=#rob.calls;root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);content:Destroy();cleanup();assert(queued,"stream request was queued");queued();run.Heartbeat:Fire(2)
assert(#rob.calls==cancelCalls and root.CFrame==originalFrame,"canceled shop stream cannot restart farming")
workspace.StreamingEnabled=false;cancelShops:Destroy();safe.Parent=workspace
-- A death during a pending teleport cancels the request and persists an incident.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);safePart.Position=Vector3.new(100,0,0);openSafe.Value=true;openRemote.Parent=safe;ensureMode("Mode: Safes");local deathCalls=#rob.calls;root.CFrame=originalFrame;fire("Start");run.Heartbeat:Fire(.2);hum.Died:Fire();run.Heartbeat:Fire(.2)
assert(#rob.calls==deathCalls and gui:GetAttribute("HoneyBunFarmIncident_123"),"death cancels pending teleport and saves incident")
content:Destroy();cleanup();content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);assert(gui:GetAttribute("HoneyBunFarmIncident_123"),"incident survives remount");safePart.Position=Vector3.new(6,0,0);content:Destroy();cleanup()
-- The idle report identifies the rejected safe contract instead of guessing cooldowns.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
openSafe.Value=false;openRemote.Parent=nil;copied=nil;fire("Copy farm report")
assert(copied:find("closed safe missing OpenSafe RemoteEvent=1",1,true),"safe rejection reason is reported")
assert(copied:find("OpenSafe=missing",1,true) and copied:find("Safe=Part=present",1,true),"safe part and opening remote are reported")
-- Live-reported outlaw merchant names are candidate camp areas.
local shopFolder=inst("Folder",workspace);shopFolder.Name="Shops"
local shop=inst("Part",shopFolder);shop.Name="OutlawGeneralStore4";shop.Position=Vector3.new(7,0,0);shop.CFrame={Position=shop.Position}
camp.Parent=nil;campFar.Parent=nil;root.CFrame=originalFrame;bag.Value=10
fire("Start");run.Heartbeat:Fire(.2)
assert(labelText("Returning to Workspace.Shops.OutlawGeneralStore4"),"actual outlaw store name is recognized as camp-area candidate")
run.Heartbeat:Fire(.2);bag.Value=0;run.Heartbeat:Fire(.3)
assert(labelText("Bag emptied; continuing route"),"shop-area return requires empty bag before resuming")
content:Destroy();cleanup();shopFolder:Destroy();camp.Parent=workspace;campFar.Parent=workspace;openRemote.Parent=safe
-- Synchronous death during the move must prevent a pending robbery from being revived.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);safePart.Position=Vector3.new(100,0,0);openSafe.Value=true;floorAvailable=true;ensureMode("Mode: Safes");root.Position=Vector3.new(0,0,0);root.CFrame={Position=root.Position};root.afterMove=function()hum.Died:Fire()end;local moveCalls=#rob.calls;fire("Start");run.Heartbeat:Fire(.2);run.Heartbeat:Fire(.5);assert(#rob.calls==moveCalls and labelText("Stopped"),"death during move cancels robbery");root.afterMove=nil;safePart.Position=Vector3.new(6,0,0);content:Destroy();cleanup()
-- A valid shop region with ground still must never become a scouting teleport.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content);local scoutShop=inst("Folder",workspace);scoutShop.Name="Shops";local scoutAnchor=inst("Part",scoutShop);scoutAnchor.Name="OutlawGeneralStore99";scoutAnchor.Position=Vector3.new(40,0,0);scoutAnchor.CFrame={Position=scoutAnchor.Position};safe.Parent=nil;floorAvailable=true;root.Position=Vector3.new(0,0,0);root.CFrame={Position=root.Position};local scoutMoves=0;root.afterMove=function()scoutMoves=scoutMoves+1 end;fire("Start");for _=1,8 do run.Heartbeat:Fire(.3) end;assert(scoutMoves==0,"shop scouting never teleports on valid ground");root.afterMove=nil;safe.Parent=workspace;scoutShop:Destroy();content:Destroy();cleanup()
-- A distant loaded target must request its own streamed ground before landing.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
local targetStreamRequests,targetStreamPosition=0,nil
local priorStreamRequest=player.RequestStreamAroundAsync
function player:RequestStreamAroundAsync(position)
    targetStreamRequests=targetStreamRequests+1;targetStreamPosition=position
    if position and position.X >= 90 then floorAvailable=true end
end
workspace.StreamingEnabled=true;task={spawn=function(fn)fn()end}
safe.Parent=workspace;safePart.Parent=safe;safePart.Name="SafePart";safePart.Position=Vector3.new(100,0,0);safePart.CFrame={Position=safePart.Position}
openSafe.Parent=safe;openSafe.Value=true;openRemote.Parent=safe
floorAvailable=false;bag.Value=0;root.CFrame=originalFrame;ensureMode("Mode: Safes")
local distantStreamCalls=#rob.calls;fire("Start")
for _=1,10 do run.Heartbeat:Fire(.3) end
assert(targetStreamRequests>0 and targetStreamPosition and targetStreamPosition.X>=90,"distant target requests streaming near its position")
assert(#rob.calls==distantStreamCalls+1 and rob.calls[#rob.calls][1]=="Safe","streamed ground lets distant target collect")
fire("Stop");workspace.StreamingEnabled=false;floorAvailable=true
player.RequestStreamAroundAsync=priorStreamRequest
safePart.Name="Safe";safePart.Position=Vector3.new(6,0,0);safePart.CFrame={Position=safePart.Position};content:Destroy();cleanup()
-- Previously seen target locations remain discovery anchors after streaming unloads them.
content=inst("ScrollingFrame");cleanup=dofile("games/farm.lua")(content)
safePart.Position=Vector3.new(100,0,0);bag.Value=0;fire("Start");fire("Stop");safe.Parent=nil
local rememberedRequest
function player:RequestStreamAroundAsync(position)rememberedRequest=position end
workspace.StreamingEnabled=true;fire("Start");run.Heartbeat:Fire(.3)
assert(rememberedRequest and rememberedRequest.X==100,"unloaded target region remains discoverable")
fire("Stop");workspace.StreamingEnabled=false;player.RequestStreamAroundAsync=priorStreamRequest
safe.Parent=workspace;safePart.Position=Vector3.new(6,0,0);content:Destroy();cleanup()
print("Grounded teleport routing, clearance, streaming gaps, server correction, damage, nested targets, cooldown backoff passed.")
print("Farm payloads, confirmed safe opening, collection observation, full bags, bounded failures, stop, and cleanup passed.")
