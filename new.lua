--[[
    NEBULA HUB | TRADE & ESP EDITION
    - Fitur Tersisa: Trade & Esp Visual
    - Ukuran: Ringan & Teroptimasi
]]

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local http = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Players = game.Players
local lp = Players.LocalPlayer
local CS = game:GetService("CollectionService")

-- Replicated Modules
local DataService = require(RS.Modules.DataService)
local ItemRarityFinder = require(RS.Modules.ItemRarityFinder)
local GGStaticData = require(RS.Modules.GardenGuideModules.DataModules.GGStaticData)

-- ================= PET NAME FIX =================
local eggPets = {}
local function updateEggPets()
    pcall(function()
        local remote = RS.GameEvents:FindFirstChild("PetEggService")
        if remote then
            local con = getconnections(remote.OnClientEvent)[1]
            if con and con.Function then
                local hatchFunc = getupvalue(getupvalue(con.Function, 1), 2)
                eggPets = getupvalue(hatchFunc, 2) or {}
            end
        end
    end)
end
task.spawn(updateEggPets)

local Window = Fluent:CreateWindow({
    Title = "NEBULA HUB | Trade & ESP",
    SubTitle = "Minimalist Version",
    Icon = "eye",
    TabWidth = 160,
    Size = UDim2.fromOffset(510, 360),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl 
})

-- Config
local Config = {
    TradeTargetPetName = "", TradeMaxPetWeight = 2.0, TradePetAmount = 12,
    TradeSubmitDelay = 0.15, AutoAcceptTrade = false, AutoAcceptRequest = false,
    AutoAddPetLoop = false, IsTradeProcessing = false,
    EspEgg = false
}

-- Tabs
local Tabs = {
    EspVisual = Window:AddTab({ Title = "Esp Visual", Icon = "eye" }),
    Trade = Window:AddTab({ Title = "Trade", Icon = "shopping-bag" })
}

-- ================= BASE WEIGHT LOGIC =================
local EggBW = {_cache = {}, _isUpdating = false}
local function buildBW()
    if EggBW._isUpdating then return end
    EggBW._isUpdating = true
    pcall(function()
        local data = DataService:GetData()
        if not data then return end
        local function scan(t)
            for k, v in pairs(t) do
                if type(v) == "table" then
                    if v.Data and v.Data.BaseWeight then 
                        EggBW._cache[tostring(k)] = v.Data.BaseWeight
                    else scan(v) end
                end
            end
        end
        scan(data)
    end)
    EggBW._isUpdating = false
end

local function getBW(uuid)
    if not EggBW._cache[uuid] then buildBW() end
    return EggBW._cache[uuid]
end

local function __round(n, d)
    local m = 10^(d or 2)
    return math.floor(n * m + 0.5) / m
end

local function getSizeInfo(kg)
    if kg >= 7 then return "Titanic", "#FF2A2A"
    elseif kg >= 6 then return "Semi Titanic", "#FF8C00"
    elseif kg >= 3 then return "Huge", "#FFD400"
    elseif kg >= 1 then return "Small", "#3CFF3C"
    end
    return "Unknown", "#FFFFFF"
end

local function formatTime(sec)
    sec = math.max(0, math.floor(sec or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

--------------------------------------------------------------------------------
-- ESP VISUAL TAB
--------------------------------------------------------------------------------
local function makeESP(obj, text)
    local target = obj:FindFirstChildWhichIsA("BasePart", true)
    if not target then return end
    
    local bb = obj:FindFirstChild("EggESP_UI")
    if not bb then
        bb = Instance.new("BillboardGui")
        bb.Name = "EggESP_UI"
        bb.Adornee = target
        bb.Size = UDim2.fromOffset(200, 80)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        
        local txt = Instance.new("TextLabel", bb)
        txt.Name = "Text"
        txt.Size = UDim2.fromScale(1, 1)
        txt.BackgroundTransparency = 1
        txt.RichText = true
        txt.TextSize = 17
        txt.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
        txt.TextColor3 = Color3.new(1,1,1)
        txt.TextStrokeTransparency = 0
        bb.Parent = obj
    end
    if bb.Text.Text ~= text then
        bb.Text.Text = text
    end
end

local EspSec = Tabs.EspVisual:AddSection("Egg Visuals")
EspSec:AddToggle("EnableEspEgg", { 
    Title = "Enable All Egg ESP", 
    Description = "Show weight and size for all your eggs",
    Default = false, 
    Callback = function(v) Config.EspEgg = v end 
})

task.spawn(function()
    while task.wait(0.5) do
        if Config.EspEgg then
            for _, egg in ipairs(CS:GetTagged("PetEggServer")) do
                if egg:GetAttribute("OWNER") == lp.Name then
                    local uuid = tostring(egg:GetAttribute("OBJECT_UUID"))
                    local bw = getBW(uuid)
                    
                    if bw then
                        local eggName = egg:GetAttribute("EggName") or egg.Name
                        local petName = eggPets[uuid] or "Pet"
                        local ready = egg:GetAttribute("READY")
                        local timeLeft = egg:GetAttribute("TimeToHatch")
                        
                        local text = ""
                        if not ready then
                            text = string.format('<font color="#FFD400">%s</font>\n<font color="#FF5E00">%s</font>\n<font size="12" color="#BBBBBB">BW: %skg</font>', eggName, formatTime(timeLeft), bw)
                        else
                            local est = __round(bw * 1.10, 2)
                            local size, sColor = getSizeInfo(est)
                            text = string.format('<font color="#FFD400">%s</font>\n<font color="#FFFFFF">%s (%skg)</font>\n<font color="%s">[%s]</font>', eggName, petName, est, sColor, size)
                        end
                        makeESP(egg, text)
                    end
                end
            end
            task.spawn(buildBW)
        else
            for _, egg in ipairs(CS:GetTagged("PetEggServer")) do
                if egg:FindFirstChild("EggESP_UI") then egg.EggESP_UI:Destroy() end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- TRADE SECTION
--------------------------------------------------------------------------------
local TrdSec = Tabs.Trade:AddSection("Auto Trade Controls")
TrdSec:AddInput("TrdName", { Title = "Target Pet Name", Callback = function(v) Config.TradeTargetPetName = v end })
TrdSec:AddInput("TrdMaxWeight", { Title = "Max Pet Weight", Default = "2.0", Callback = function(v) Config.TradeMaxPetWeight = tonumber(v) or 2.0 end })
TrdSec:AddToggle("AutoAccReq", { Title = "Auto Accept Request", Default = false, Callback = function(v) Config.AutoAcceptRequest = v end })
TrdSec:AddToggle("AutoAddPet", { Title = "Auto Add Pet Loop (Max 12)", Default = false, Callback = function(v) Config.AutoAddPetLoop = v end })
TrdSec:AddToggle("AutoAccTrd", { Title = "Auto Accept & Confirm", Default = false, Callback = function(v) Config.AutoAcceptTrade = v end })

task.spawn(function()
    local TradeEvents = RS.GameEvents.TradeEvents
    local TradingController = require(RS.Modules.TradeControllers.TradingController)
    TradeEvents.SendRequest.OnClientEvent:Connect(function(id)
        if Config.AutoAcceptRequest then task.wait(0.3) TradeEvents.RespondRequest:FireServer(id, true) end
    end)
    while task.wait(0.1) do
        if Config.AutoAddPetLoop and TradingController.CurrentTradeReplicator and not Config.IsTradeProcessing then
            Config.IsTradeProcessing = true
            local added = 0
            for _, item in pairs(lp.Backpack:GetChildren()) do
                if added >= 12 or not Config.AutoAddPetLoop then break end
                if item.Name:lower():find(Config.TradeTargetPetName:lower()) then
                    local weight = tonumber(string.match(item.Name, "%d+%.?%d*")) or 0
                    if weight <= Config.TradeMaxPetWeight then
                        TradeEvents.AddItem:FireServer("Pet", tostring(item:GetAttribute("PET_UUID")))
                        added += 1
                        task.wait(0.15)
                    end
                end
            end
            Config.IsTradeProcessing = false
        end
        if Config.AutoAcceptTrade and TradingController.CurrentTradeReplicator then
            pcall(function()
                local data = TradingController.CurrentTradeReplicator:GetData()
                local myIdx = table.find(data.players, lp)
                if myIdx then
                    if data.states[myIdx] == "None" then TradingController:Accept()
                    elseif data.states[myIdx] == "Accepted" then TradingController:Confirm() end
                end
            end)
        end
    end
end)

--------------------------------------------------------------------------------
-- UI TOGGLE
--------------------------------------------------------------------------------
if game.CoreGui:FindFirstChild("NebulaToggle") then game.CoreGui.NebulaToggle:Destroy() end
local ToggleGui = Instance.new("ScreenGui", game.CoreGui)
local ToggleButton = Instance.new("TextButton", ToggleGui)
ToggleGui.Name = "NebulaToggle"
ToggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ToggleButton.Position = UDim2.new(0, 15, 0.5, 0)
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Text = "N"; ToggleButton.TextColor3 = Color3.fromRGB(120, 117, 242)
ToggleButton.Draggable = true
Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(1, 0)
ToggleButton.MouseButton1Click:Connect(function() Window:Minimize() end)

Window:SelectTab(1)
