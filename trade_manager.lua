-- trade_manager.lua
-- Trade Manager (FINAL STABLE VERSION)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local TradeController = Knit.GetController("TradeController")
local TradingService = Knit.GetService("TradingService")
local ReplicaListener = Knit.GetController("ReplicaListener")

-- Load Game Info
local SuccessLoadCrates, CratesInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.CratesInfo) 
end)
if not SuccessLoadCrates then CratesInfo = {} end

local SuccessLoadPets, PetsInfo = pcall(function() 
    return require(ReplicatedStorage.GameInfo.PetsInfo) 
end)
if not SuccessLoadPets then PetsInfo = {} end

local TradeManager = {}
TradeManager.IsProcessing = false 
TradeManager.CratesInfo = CratesInfo
TradeManager.PetsInfo = PetsInfo

-- [NEW] ตัวแปรเช็คว่าเราเป็นคนเริ่มเทรดหรือไม่ (Host)
TradeManager.AmIHost = false

-- ฟังก์ชันหา Trade ID แบบ Universal (รองรับทุกภาษา/ทุก Executor)
function TradeManager.GetGameTradeId()
    -- 1. ถ้าเราเป็น Host (กด Force Trade เอง) -> ใช้ ID เรา
    if TradeManager.AmIHost then
        return Players.LocalPlayer.UserId
    end

    -- 2. ถ้าเขาชวนมา -> พยายามดึง ID จาก UI บนหน้าจอ
    local success, partnerId = pcall(function()
        local TradingFrame = LocalPlayer.PlayerGui.Windows:FindFirstChild("TradingFrame")
        if TradingFrame and TradingFrame.Visible then
            
            -- [วิธีหลัก] เจาะดู Link รูปภาพโปรไฟล์คู่ค้า (แม่นยำที่สุด 100%)
            -- Link จะเป็นรูปแบบ rbxthumb://type=...&id=123456...
            local userImage = TradingFrame.UserLogo.ImageLabel.ImageLabel.Image
            local idMatch = string.match(userImage, "id=(%d+)") or string.match(userImage, "userId=(%d+)")
            
            if idMatch then
                return tonumber(idMatch)
            end

            -- [วิธีสำรอง] ถ้าดึงรูปไม่ได้ ค่อยใช้วิธีวนหาชื่อในข้อความ
            local titleText = TradingFrame.TitleB.Text
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    -- เช็คว่ามีชื่อผู้เล่นคนไหนปรากฏอยู่ในข้อความบ้าง
                    if string.find(titleText, p.Name, 1, true) or string.find(titleText, p.DisplayName, 1, true) then
                        return p.UserId
                    end
                end
            end
        end
        return nil
    end)

    if success and partnerId then
        return partnerId
    end

    -- สุดท้ายจริงๆ ถ้าหาไม่เจอ ให้ใช้ ID เรา (Safe Fallback)
    return LocalPlayer.UserId
end

function TradeManager.ForceTradeWith(targetPlayer, statusLabel, StateManager, Utils)
    if not targetPlayer then return end
    if TradeManager.IsProcessing or Utils.IsTradeActive() then return end
    
    TradeManager.IsProcessing = true
    
    -- [สำคัญ] เรากดเริ่มเทรด แปลว่าเราเป็น Host
    TradeManager.AmIHost = true 
    
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        PlayerBtn = Color3.fromRGB(255, 170, 0),
        Success = Color3.fromRGB(85, 255, 127),
        ItemEquip = Color3.fromRGB(255, 80, 80)
    }
    
    StateManager:SetStatus("🚀 Requesting trade...", THEME.PlayerBtn, statusLabel)
    
    TradingService:InitializeNewTrade(targetPlayer.UserId):andThen(function(result)
        TradeManager.IsProcessing = false
        
        if result then
            -- บังคับให้ Client ฝั่งเรารับรู้ว่าเทรดเริ่มแล้ว
            pcall(function() 
                TradeController:OnTradeRequestAccepted(targetPlayer.UserId) 
            end)
            
            StateManager:SetStatus("✅ Request sent!", THEME.Success, statusLabel)
        else
            -- ถ้าเฟล ให้ยกเลิกสถานะ Host
            TradeManager.AmIHost = false
            StateManager:SetStatus("❌ Failed (Cooldown/Busy).", THEME.ItemEquip, statusLabel)
        end
    end)
end

function TradeManager.SendTradeSignal(action, itemData, amount, statusLabel, StateManager, Utils, callbacks)
    -- ฟังก์ชันนี้แก้ไขให้ปลอดภัยจากการ Crash (ไม่ยุ่งกับ UI เกม)
    
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        ItemEquip = Color3.fromRGB(255, 80, 80),
        ItemInv = Color3.fromRGB(100, 255, 140),
        BtnDupe = Color3.fromRGB(170, 0, 255)
    }
    
    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Trade Menu NOT open!", THEME.ItemEquip, statusLabel)
        return
    end
    
    local isDupeMode = (StateManager.currentMainTab == "Dupe")
    local key = itemData.Guid or itemData.Name
    
    -- [FIXED] ตัดส่วนสร้าง fakeBtn ทิ้ง เพื่อป้องกัน Error Log
    
    if action == "Add" then
        -- อัปเดตแค่ใน Hub ของเรา
        StateManager:AddToTrade(key, itemData)
        
        local modePrefix = isDupeMode and "✨ Dupe: " or "✅ Added: "
        StateManager:SetStatus(modePrefix .. itemData.Name, THEME.ItemInv, statusLabel)
        
    elseif action == "Remove" then
        StateManager:RemoveFromTrade(key)
        StateManager:SetStatus("🗑️ Removed: " .. itemData.Name, THEME.ItemEquip, statusLabel)
    end
    
    if callbacks and callbacks.RefreshInventory then 
        callbacks.RefreshInventory() 
    end
end

function TradeManager.ExecuteMagicDupe(recipe, statusLabel, amount, StateManager, Utils, InventoryManager)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        PlayerBtn = Color3.fromRGB(255, 170, 0),
        BtnDupe = Color3.fromRGB(170, 0, 255),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if TradeManager.IsProcessing or not Utils.IsTradeActive() then
        if not Utils.IsTradeActive() then
            StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, statusLabel)
        end
        return
    end
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    if not playerData or not playerData.ItemsService then
        StateManager:SetStatus("❌ Data Error!", THEME.Fail, statusLabel)
        return
    end
    
    local targetTier = tonumber(recipe.Tier)
    local serviceName = recipe.Service
    local itemsInv = playerData.ItemsService.Inventory
    local serviceData = itemsInv and itemsInv[serviceName]
    
    if serviceData then
        local ownedAmt = serviceData[tostring(targetTier)] or serviceData[targetTier] or 0
        if ownedAmt > 0 then
            StateManager:SetStatus("❌ Owned: You already have this!", THEME.Fail, statusLabel)
            return
        end
    end
    
    -- ดึง Trade ID ที่ถูกต้องมาใช้
    local realTradeId = TradeManager.GetGameTradeId()
    
    local tradingService = ReplicatedStorage.Packages.Knit.Services.TradingService
    local remote = tradingService.RF:FindFirstChild("UpdateTradeOffer")
    
    local function sendUpdate(payload)
        local data = {
            MonsterService = {}, 
            CratesService = {}, 
            Currencies = {},
            PetsService = {}, 
            AccessoryService = {},
            ItemsService = { [serviceName] = payload }
        }
        
        -- ส่งข้อมูลไปที่ Server โดยตรง (Safe & Fast)
        pcall(function() 
            remote:InvokeServer(realTradeId, data) 
        end)
    end
    
    TradeManager.IsProcessing = true
    local WAIT_TIME = 1.3
    
    task.spawn(function()
        if recipe.Name == "White Strawberry" then
            StateManager:SetStatus("⏳ Step 1: Baiting (T2 x2)...", THEME.PlayerBtn, statusLabel)
            sendUpdate({ [2] = 2 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("🧪 Step 2: Injecting (T1 x" .. amount .. ")...", THEME.BtnDupe, statusLabel)
            sendUpdate({ amount, 1 })
        elseif string.find(string.lower(recipe.Service), "potion") or string.find(string.lower(recipe.Name), "potion") then
            sendUpdate({1, 1, amount})
            StateManager:SetStatus("✅ Potion Dupe Sent!", THEME.Success, statusLabel)
            TradeManager.IsProcessing = false
            return
        else
            local availableBaits = {}
            if serviceData then
                for _, reqTier in ipairs(recipe.RequiredTiers) do
                    local tNum = tonumber(reqTier)
                    if tNum > 2 and tNum ~= targetTier then
                        local amt = serviceData[tostring(tNum)] or serviceData[tNum] or 0
                        if amt > 0 then 
                            table.insert(availableBaits, tNum) 
                        end
                    end
                end
            end
            table.sort(availableBaits, function(a, b) return a > b end)
            
            if #availableBaits < 2 then
                StateManager:SetStatus("❌ Need 2 Baits (T3+)", THEME.Fail, statusLabel)
                TradeManager.IsProcessing = false
                return
            end
            
            local t1, t2 = availableBaits[1], availableBaits[2]
            StateManager:SetStatus("⏳ 1/4: Place T" .. t1, THEME.PlayerBtn, statusLabel)
            sendUpdate({ [t1] = 1 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("⏳ 2/4: Add T" .. t2, THEME.PlayerBtn, statusLabel)
            sendUpdate({ [t1] = 1, [t2] = 1 })
            task.wait(WAIT_TIME)
            StateManager:SetStatus("✨ 3/4: SWAP to Target", THEME.BtnDupe, statusLabel)
            sendUpdate({ [targetTier] = amount, [t2] = 1 })
            task.wait(WAIT_TIME + 0.2)
            StateManager:SetStatus("🔥 4/4: Finishing...", THEME.Success, statusLabel)
            sendUpdate({ [targetTier] = amount })
        end
        
        StateManager:SetStatus("✅ Execution Complete!", THEME.Success, statusLabel)
        TradeManager.IsProcessing = false
    end)
end

function TradeManager.ExecutePetDupe(statusLabel, StateManager, Utils)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        BtnDupe = Color3.fromRGB(170, 0, 255),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if TradeManager.IsProcessing then return end
    if not Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, statusLabel)
        return
    end
    
    local replica = ReplicaListener:GetReplica()
    local myPets = replica.Data.PetsService.Pets
    
    local selectedUUIDs = {}
    local hasEvo2 = false
    
    for uuid, selected in pairs(StateManager.selectedPets) do
        if selected then
            local petData = myPets[uuid]
            if petData and (petData.Evolution or 0) >= 2 then
                hasEvo2 = true
                break
            end
            table.insert(selectedUUIDs, uuid)
        end
    end
    
    if hasEvo2 then
        StateManager:SetStatus("❌ Cannot Dupe Evo 2 pets! (Unselect them)", THEME.Fail, statusLabel)
        return
    end
    
    if #selectedUUIDs == 0 then
        StateManager:SetStatus("⚠️ Select pets (Evo 0-1) to dupe!", THEME.Fail, statusLabel)
        return
    end
    
    if not replica or not replica.Data then
        StateManager:SetStatus("❌ Data Error!", THEME.Fail, statusLabel)
        return
    end
    
    local playerData = replica.Data
    local availableBaitCrates = {}
    
    for internalId, info in pairs(CratesInfo) do
        if type(info) == "table" then
            local displayName = info.Name or internalId
            local hasNameKey = (playerData.CratesService.Crates[displayName] ~= nil)
            local hasIdKey = (playerData.CratesService.Crates[internalId] ~= nil)
            
            if not hasNameKey and not hasIdKey and displayName ~= "KeKa Crate" then
                table.insert(availableBaitCrates, displayName)
            end
        end
    end
    
    if #availableBaitCrates == 0 then
        StateManager:SetStatus("❌ No 'Pure Nil' crates found!", THEME.Fail, statusLabel)
        TradeManager.IsProcessing = false
        return
    end
    
    local baitCrateName = availableBaitCrates[math.random(1, #availableBaitCrates)]
    
    local petPayload = {}
    for _, uuid in ipairs(selectedUUIDs) do
        local petData = myPets[uuid]
        if petData then
            petPayload[uuid] = {
                Name = petData.Name,
                Evolution = 2
            }
        end
    end
    
    -- ดึง Trade ID ที่ถูกต้อง
    local realTradeId = TradeManager.GetGameTradeId()
    
    TradeManager.IsProcessing = true
    StateManager:SetStatus("✨ Executing Pet Dupe...", THEME.BtnDupe, statusLabel)
    
    local remote = ReplicatedStorage.Packages.Knit.Services.TradingService.RF:FindFirstChild("UpdateTradeOffer")
    
    task.spawn(function()
        local data = {
            MonsterService = {},
            CratesService = {
                [baitCrateName] = 10
            },
            Currencies = {},
            PetsService = petPayload,
            ItemsService = {},
            AccessoryService = {}
        }
        
        local success, err = pcall(function()
            return remote:InvokeServer(realTradeId, data)
        end)
        
        if success then
            StateManager:SetStatus("✅ Dupe Success (Evo 2 Applied)!", THEME.Success, statusLabel)
        else
            StateManager:SetStatus("❌ Dupe Failed: Server Error", THEME.Fail, statusLabel)
        end
        
        task.wait(1)
        TradeManager.IsProcessing = false
    end)
end

function TradeManager.DeleteSelectedPets(statusLabel, callback, StateManager, Utils)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        Fail = Color3.fromRGB(255, 85, 85),
        Success = Color3.fromRGB(85, 255, 127)
    }
    
    if Utils.IsTradeActive() then
        StateManager:SetStatus("⚠️ Close trade menu before deleting!", THEME.Fail, statusLabel)
        return
    end
    
    local selectedUUIDs = {}
    for uuid, selected in pairs(StateManager.selectedPets) do
        if selected then 
            table.insert(selectedUUIDs, uuid) 
        end
    end
    
    if #selectedUUIDs == 0 then return end
    
    StateManager:SetStatus("🗑️ Deleting pets...", THEME.Fail, statusLabel)
    
    local success, err = pcall(function()
        local Remote = ReplicatedStorage.Packages.Knit.Services.PetsService.RF.Delete
        return Remote:InvokeServer(selectedUUIDs)
    end)
    
    if success then
        StateManager.selectedPets = {}
        StateManager:SetStatus("✅ Deleted successfully!", THEME.Success, statusLabel)
        if callback then callback() end
    else
        StateManager:SetStatus("❌ Delete failed: " .. tostring(err), THEME.Fail, statusLabel)
    end
end

function TradeManager.ExecuteEvolution(statusLabel, callback, StateManager)
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        BtnSelected = Color3.fromRGB(0, 140, 255),
        Success = Color3.fromRGB(85, 255, 127),
        Fail = Color3.fromRGB(255, 85, 85)
    }
    
    local selectedUUIDs = {}
    for uuid, order in pairs(StateManager.selectedPets) do
        table.insert(selectedUUIDs, {UUID = uuid, Order = order})
    end
    
    table.sort(selectedUUIDs, function(a, b) 
        return a.Order < b.Order 
    end)
    
    local finalPayload = {}
    for _, item in ipairs(selectedUUIDs) do
        table.insert(finalPayload, item.UUID)
    end
    
    StateManager:SetStatus("🧬 Evolving Pets...", THEME.BtnSelected, statusLabel)
    
    local success, err = pcall(function()
        return ReplicatedStorage.Packages.Knit.Services.PetsService.RF.Evolve:InvokeServer(finalPayload)
    end)
    
    if success then
        StateManager:SetStatus("✅ Evolution Success!", THEME.Success, statusLabel)
        StateManager.selectedPets = {}
        if callback then callback() end
    else
        StateManager:SetStatus("❌ Evo Failed: " .. tostring(err), THEME.Fail, statusLabel)
    end
end

return TradeManager
