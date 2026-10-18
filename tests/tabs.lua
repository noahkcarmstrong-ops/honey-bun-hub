-- Exercise the actual loader and Refresh callback using the existing Roblox stand-ins.
dofile('tests/player-esp.lua')
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={Connected=true,fn=fn}
        function c:Disconnect() self.Connected=false end
        table.insert(self.listeners,c);return c
    end
    function s:Fire(...) for _,c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end
local input={InputBegan=signal(),GetFocusedTextBox=function()return nil end}
local originalService=game.GetService
function game:GetService(name) if name=='UserInputService' then return input end; if name=='HttpService' then return {JSONDecode=function(_,value) assert(value=='latest-revision');return {sha=string.rep('a',40)} end} end;return originalService(self,name) end
local new=Instance.new
Instance.new=function(class,parent)
    local object=new(class,parent)
    function object:Clone()
        local clone=Instance.new(self.ClassName)
        for key,value in pairs(self.props) do
            if key~='Parent' and key~='Activated' and key~='Destroying' then clone[key]=value end
        end
        for _,child in ipairs(self:GetChildren()) do child:Clone().Parent=clone end
        return clone
    end
    return object
end
tabTest={espMounts=0,espCleanups=0,farmMounts=0,farmCleanups=0,failFarm=true}
game.GameId=873703865
loadstring=function(source)
    if source=='__test_loader__' then return function() dofile('loader.lua') end end
    return load(source)
end
function game:HttpGet(url)
    if url:find('api.github.com/repos/',1,true) then
        tabTest.revisionChecked=true
        return 'latest-revision'
    end
    if url:find('/loader.lua',1,true) then
        assert(tabTest.revisionChecked,'Refresh checks GitHub revision first')
        assert(url:find('/'..string.rep('a',40)..'/loader.lua',1,true),'Refresh fetches exact latest commit')
        return '__test_loader__'
    end
    if url:find('/games/farm.lua',1,true) then
        if tabTest.failFarm then error('Simulated farm load failure') end
        if tabTest.staleFarm then return 'return function() error("stale farm executed") end' end
        assert(url:find('/'..string.rep('a',40)..'/games/farm.lua',1,true),'Farm uses latest immutable revision')
        return '-- HoneyBunFarmRouteV3\nreturn function(page) tabTest.farmMounts=tabTest.farmMounts+1; return function() tabTest.farmCleanups=tabTest.farmCleanups+1 end end'
    end
    return 'return {name="WESTBOUND",description="",farmPath="games/farm.lua",mount=function(page) tabTest.espMounts=tabTest.espMounts+1; return function() tabTest.espCleanups=tabTest.espCleanups+1 end end}'
end
local playerGui=game:GetService('Players').LocalPlayer:FindFirstChildOfClass('PlayerGui')
local function ui()
    local gui=assert(playerGui:FindFirstChild('HoneyBunHub'))
    local panel=assert(gui:FindFirstChildOfClass('Frame'))
    local tabs=assert(panel:FindFirstChild('Tabs'))
    return gui,panel,tabs:FindFirstChild('ESP'),tabs:FindFirstChild('Farm'),panel:FindFirstChild('ESPPage'),panel:FindFirstChild('FarmPage')
end
dofile('loader.lua')
local gui,panel,esp,farm,espPage,farmPage=ui()
assert(espPage.Visible and not farmPage.Visible,'ESP opens first')
assert(tabTest.farmMounts==0,'Farm is not loaded until selected')
farm.Activated:Fire()
assert(farmPage.Visible and not espPage.Visible,'Farm tab selects its own page')
tabTest.failFarm=false;tabTest.staleFarm=true;farm.Activated:Fire()
assert(tabTest.farmMounts==0,'Outdated farm source is blocked before execution')
tabTest.staleFarm=false;farm.Activated:Fire();farm.Activated:Fire()
assert(tabTest.farmMounts==1,'Failed farm loading can retry and successful loading is reused')
esp.Activated:Fire();assert(espPage.Visible and not farmPage.Visible,'ESP remains accessible')
local refresh
for _,child in ipairs(panel:GetChildren()) do if child.Text=='Refresh' then refresh=child end end
assert(refresh);refresh.Activated:Fire()
assert(tabTest.espCleanups==1 and tabTest.farmCleanups==1,'Actual Refresh cleans up both pages')
assert(tabTest.espMounts==2,'Actual Refresh reloads the hub')
local newGui=ui();newGui:Destroy()
for _,connection in ipairs(input.InputBegan.listeners) do assert(not connection.Connected,'Old input listeners are removed') end
print('Farm/ESP navigation, lazy loading, retry, actual Refresh, and cleanup passed.')
