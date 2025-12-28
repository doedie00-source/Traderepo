-- trade_manager.lua
-- Trade Manager (CORE LOGIC - PRESERVED)

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

function TradeManager.ForceTradeWith(targetPlayer, statusLabel, StateManager, Utils)
    if not targetPlayer then return end
    if TradeManager.IsProcessing or Utils.IsTradeActive() then return end
    
    TradeManager.IsProcessing = true
    
    -- ใช้ค่าจาก StateManager's Config
    local THEME = StateManager.Config and StateManager.Config.THEME or {
        PlayerBtn = Color3.fromRGB(255, 170, 0),
        Success = Color3.fromRGB(85, 255, 127),
        ItemEquip = Color3.fromRGB(255, 80, 80)
    }
    
    StateManager:SetStatus("🚀 Requesting trade...", THEME.PlayerBtn, statusLabel)
    
    TradingService:InitializeNewTrade(targetPlayer.UserId):andThen(function(result)
        TradeManager.IsProcessing = false
        
        if result then
            pcall(function() 
                TradeController:OnTradeRequestAccepted(targetPlayer.UserId) 
            end)
            
            if debug and debug.setupvalue then
                pcall(function()
                    local func = TradeController.AddToTradeData
                    debug.setupvalue(func, 4, LocalPlayer.UserId)
                end)
            end
            
            StateManager:SetStatus("✅ Request sent!", THEME.Success, statusLabel)
        else
            StateManager:SetStatus("❌ Failed (Cooldown/Busy).", THEME.ItemEquip, statusLabel)
        end
    end)
end

function TradeManager.SendTradeSignal(action, itemData, amount, statusLabel, StateManager, Utils, callbacks)
    -- WARNING: This function is critical for Dupe System. Do NOT remove.
    
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
    
    local success, fakeBtn = pcall(function()
        local btn = Instance.new("ImageButton")
        local uniqueId = itemData.Guid or (itemData.Name .. "_" .. tick())
        btn.Name = "TradeItem_" .. uniqueId
        btn.Visible = false
        btn.Size = UDim2.new(0, 100, 0, 100)
        btn.BackgroundTransparency = 1
        
        btn:SetAttribute("Service", itemData.Service)
        btn:SetAttribute("Index", itemData.Name)
        btn:SetAttribute("Quantity", amount)
        btn:SetAttribute("IsEquipped", false)
        
        if itemData.Category == "Crates" then
            btn:SetAttribute("ItemName", itemData.Name)
            btn:SetAttribute("Name", itemData.Name)
            btn:SetAttribute("Amount", amount)
            btn:SetAttribute("Service", "CratesService")
            btn:SetAttribute("IsFakeDupe", true)
        end
        
        if itemData.Guid and itemData.Category ~= "Crates" then
            btn:SetAttribute("Guid", tostring(itemData.Guid))
        end
        
        if itemData.RawInfo then
            if itemData.RawInfo.Evolution then 
                btn:SetAttribute("Evolution", itemData.RawInfo.Evolution) 
            end
            if itemData.RawInfo.Shiny then 
                btn:SetAttribute("Shiny", true) 
            end
            if itemData.RawInfo.Golden then 
                btn:SetAttribute("Golden", true) 
            end
        end
        
        game:GetService("CollectionService"):AddTag(btn, "Tradeable")
        btn.Parent = LocalPlayer:WaitForChild("PlayerGui")
        return btn
    end)
    
    if not success or not fakeBtn then
        StateManager:SetStatus("❌ Failed to create signal!", THEME.ItemEquip, statusLabel)
        return
    end
    
    pcall(function()
        local key = itemData.Guid or itemData.Name
        if action == "Add" then
            TradeController:AddToTradeData(fakeBtn, amount)
            StateManager:AddToTrade(key, itemData)
            local modePrefix = isDupeMode and "✨ Dupe: " or "✅ Added: "
            StateManager:SetStatus(modePrefix .. itemData.Name, THEME.ItemInv, statusLabel)
        elseif action == "Remove" then
            TradeController:RemoveFromTradeData(fakeBtn, amount)
            StateManager:RemoveFromTrade(key)
            StateManager:SetStatus("🗑️ Removed: " .. itemData.Name, THEME.ItemEquip, statusLabel)
        end
    end)
    
    task.delay(0.5, function() 
        if fakeBtn and fakeBtn.Parent then 
            fakeBtn:Destroy() 
        end 
    end)
    
    if callbacks then
        if callbacks.RefreshInventory then 
            callbacks.RefreshInventory() 
        end
    end
end

function TradeManager.GetGameTradeId()
    local success, tradeId = pcall(function()
        if debug and debug.getupvalues then
            local upvalues = debug.getupvalues(TradeController.AddToTradeData)
            for i, v in pairs(upvalues) do
                if type(v) == "number" and v > 1000 then 
                    return v 
                end
            end
        end
    end)
    return (success and tradeId) or nil
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
    
    local realTradeId = TradeManager.GetGameTradeId()
    if not realTradeId then
        local targetIds = {LocalPlayer.UserId}
        pcall(function()
            local TradingFrame = LocalPlayer.PlayerGui.Windows:FindFirstChild("TradingFrame")
            if TradingFrame then
                for _, v in pairs(TradingFrame:GetDescendants()) do
                    if v:IsA("TextLabel") and v.Visible and #v.Text > 2 then
                        for _, p in pairs(game.Players:GetPlayers()) do
                            if p ~= LocalPlayer and (v.Text:find(p.Name) or v.Text:find(p.DisplayName)) then
                                table.insert(targetIds, p.UserId)
                                break
                            end
                        end
                    end
                end
            end
        end)
        realTradeId = targetIds
    end
    
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
        
        if type(realTradeId) == "table" then
            for _, id in pairs(realTradeId) do
                task.spawn(function() 
                    pcall(function() 
                        remote:InvokeServer(id, data) 
                    end) 
                end)
            end
        else
            pcall(function() 
                remote:InvokeServer(realTradeId, data) 
            end)
        end
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
        elseif StateManager.currentDupeTab == "Potions" then
            local baits = {}
            for _, req in ipairs(recipe.RequiredTiers) do 
                baits[tonumber(req)] = 1 
            end
            local finalPayload = {}
            for k, v in pairs(baits) do 
                finalPayload[k] = v 
            end
            finalPayload[targetTier] = amount
            
            StateManager:SetStatus("⏳ Step 1: Baiting...", THEME.PlayerBtn, statusLabel)
            sendUpdate(baits)
            task.wait(WAIT_TIME)
            StateManager:SetStatus("🧪 Step 2: Injecting...", THEME.BtnDupe, statusLabel)
            sendUpdate(finalPayload)
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
    
    local realTradeId = TradeManager.GetGameTradeId()
    if not realTradeId then
        for _, p in pairs(game.Players:GetPlayers()) do
            if p ~= LocalPlayer then
                realTradeId = p.UserId
                break
            end
        end
    end
    
    if not realTradeId then
        StateManager:SetStatus("❌ Trade ID not found!", THEME.Fail, statusLabel)
        return
    end
    
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