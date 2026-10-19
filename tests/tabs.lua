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
tabTest={espMounts=0,espCleanups=0,farmRequests=0,failLoader=false}
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
        if tabTest.failLoader then error('Simulated refresh failure') end
        return '__test_loader__'
    end
    if url:find('/games/farm.lua',1,true) then
        tabTest.farmRequests=tabTest.farmRequests+1
        error('Farm must not be requested')
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
assert(espPage.Visible and not farmPage,'ESP opens first without a Farm page')
assert(not farm,'Stale farmPath metadata does not create a Farm tab')
assert(tabTest.farmRequests==0,'Stale farmPath metadata does not request farm.lua')
local refresh
for _,child in ipairs(panel:GetChildren()) do if child.Text=='Refresh' then refresh=child end end
assert(refresh);refresh.Activated:Fire()
local refreshedGui,refreshedPanel=ui()
local refreshedRefresh
for _,child in ipairs(refreshedPanel:GetChildren()) do if child.Text=='Refresh' then refreshedRefresh=child end end
assert(refreshedRefresh,'Refresh succeeds and restores its label')
assert(tabTest.espCleanups==1,'Actual Refresh cleans up the old ESP page')
assert(tabTest.espMounts==2,'Actual Refresh reloads the hub')
assert(tabTest.farmRequests==0,'Refresh never requests farm.lua')
tabTest.failLoader=true;refresh=refreshedRefresh;refresh.Activated:Fire()
assert(refresh.Text=='Retry refresh','Failed Refresh offers a retry')
tabTest.failLoader=false;refresh.Activated:Fire()
assert(tabTest.espCleanups==2 and tabTest.espMounts==3,'Refresh retry reloads ESP and cleans up the previous page')
assert(tabTest.farmRequests==0,'Refresh retry never requests farm.lua')
local newGui=ui();newGui:Destroy()
for _,connection in ipairs(input.InputBegan.listeners) do assert(not connection.Connected,'Old input listeners are removed') end
print('ESP navigation, Refresh SHA lookup, retry, and cleanup passed.')
