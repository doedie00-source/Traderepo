-- tabs/inventory_tab.lua
-- Hidden Inventory Tab (All Categories in One Page) - FIXED VERSION

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Load Info Modules
local function SafeRequire(path)
    local success, result = pcall(function() return require(path) end)
    return success and result or {}
end

local PetsInfo = SafeRequire(ReplicatedStorage.GameInfo.PetsInfo)
local CratesInfo = SafeRequire(ReplicatedStorage.GameInfo.CratesInfo)
local MonsterInfo = SafeRequire(ReplicatedStorage.GameInfo.MonsterInfo)
local AccessoryInfo = SafeRequire(ReplicatedStorage.GameInfo.AccessoryInfo)

local InventoryTab = {}
InventoryTab.__index = InventoryTab

function InventoryTab.new(deps)
    local self = setmetatable({}, InventoryTab)
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    self.Container = nil
    return self
end

function InventoryTab:Init(parent)
    local THEME = self.Config.THEME
    
    -- Header
    self.UIFactory.CreateLabel({
        Parent = parent,
        Text = "💎 Hidden Treasures",
        Size = UDim2.new(1, -8, 0, 24),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.AccentGreen,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.UIFactory.CreateLabel({
        Parent = parent,
        Text = "Items currently in your inventory (Hidden List only)",
        Size = UDim2.new(1, -8, 0, 14),
        Position = UDim2.new(0, 8, 0, 22),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })

    -- Grid Container
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 45),
        UseGrid = true 
    })
    
    -- ✅ เพิ่ม Padding ให้ Container (เหมือนหน้า Dupe)
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 12)
    
    -- ตั้งค่า Grid ให้สวยเหมือนหน้า Dupe
    local layout = self.Container:FindFirstChild("UIGridLayout")
    if layout then
        layout.CellSize = UDim2.new(0, 92, 0, 115)
        layout.CellPadding = UDim2.new(0, 8, 0, 8)
    end

    self:RefreshInventory()
end

function InventoryTab:RefreshInventory()
    -- Clear old items
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then return end

    local HIDDEN = self.Config.HIDDEN_LISTS
    local itemsToRender = {}

    -- ✅ FIX 1: เช็ค Pets (เอาดาวและเลเวลมาด้วย)
    if playerData.PetsService and playerData.PetsService.Pets then
        for uuid, data in pairs(playerData.PetsService.Pets) do
            if self:CheckHidden(data.Name, HIDDEN.Pets) then
                table.insert(itemsToRender, {
                    Name = data.Name, 
                    UUID = uuid, 
                    Category = "Pets", 
                    Service = "PetsService", 
                    Raw = data, 
                    Image = PetsInfo[data.Name] and PetsInfo[data.Name].Image
                })
            end
        end
    end

    -- ✅ FIX 2: เช็ค Monsters (ทั้ง SavedMonsters และ MonstersUnlocked)
    if playerData.MonsterService then
        -- เช็ค SavedMonsters (มี UUID)
        if playerData.MonsterService.SavedMonsters then
            for uuid, data in pairs(playerData.MonsterService.SavedMonsters) do
                local mName = (type(data) == "table") and data.Name or data
                if self:CheckHidden(mName, HIDDEN.Secrets) then
                    table.insert(itemsToRender, {
                        Name = mName, 
                        UUID = uuid, 
                        Category = "Secrets", 
                        Service = "MonsterService",
                        ElementData = "SavedMonsters",
                        Raw = (type(data) == "table") and data or {Name = mName}, 
                        Image = MonsterInfo[mName] and MonsterInfo[mName].Image
                    })
                end
            end
        end
        
        -- ✅ เพิ่ม: เช็ค MonstersUnlocked (ไม่มี UUID)
        if playerData.MonsterService.MonstersUnlocked then
            for _, mName in pairs(playerData.MonsterService.MonstersUnlocked) do
                if self:CheckHidden(mName, HIDDEN.Secrets) then
                    -- เช็คว่ายังไม่ได้เพิ่มไปแล้วจาก SavedMonsters
                    local alreadyAdded = false
                    for _, item in ipairs(itemsToRender) do
                        if item.Category == "Secrets" and item.Name == mName and item.UUID then
                            alreadyAdded = true
                            break
                        end
                    end
                    
                    if not alreadyAdded then
                        table.insert(itemsToRender, {
                            Name = mName,
                            UUID = nil, -- MonstersUnlocked ไม่มี UUID
                            Category = "Secrets",
                            Service = "MonsterService",
                            ElementData = "MonstersUnlocked",
                            Raw = {Name = mName},
                            Image = MonsterInfo[mName] and MonsterInfo[mName].Image
                        })
                    end
                end
            end
        end
    end

    -- ✅ FIX 3: เช็ค Accessories
    if playerData.AccessoryService and playerData.AccessoryService.Accessories then
        for uuid, data in pairs(playerData.AccessoryService.Accessories) do
            if self:CheckHidden(data.Name, HIDDEN.Accessories) then
                table.insert(itemsToRender, {
                    Name = data.Name, 
                    UUID = uuid, 
                    Category = "Accessories", 
                    Service = "AccessoryService", 
                    Raw = data, 
                    Image = AccessoryInfo[data.Name] and AccessoryInfo[data.Name].Image
                })
            end
        end
    end

    -- ✅ FIX 4: เช็ค Crates
    if playerData.CratesService and playerData.CratesService.Crates then
        for name, amount in pairs(playerData.CratesService.Crates) do
            if amount > 0 and self:CheckHidden(name, HIDDEN.Crates) then
                table.insert(itemsToRender, {
                    Name = name, 
                    Amount = amount, 
                    Category = "Crates", 
                    Service = "CratesService", 
                    Image = CratesInfo[name] and CratesInfo[name].Image
                })
            end
        end
    end

    -- Render การ์ด
    for _, item in ipairs(itemsToRender) do
        self:CreateItemCard(item, playerData)
    end
end

function InventoryTab:CheckHidden(name, list)
    if not list then return false end
    for _, h in pairs(list) do 
        if h == name then return true end 
    end
    return false
end

function InventoryTab:CreateItemCard(item, playerData)
    local THEME = self.Config.THEME
    
    -- ✅ FIX: เช็คสถานะสวมใส่
    local isEquipped = false
    if item.Category ~= "Crates" then
        isEquipped = self.Utils.CheckIsEquipped(item.UUID, item.Name, item.Category, playerData)
    end
    
    -- ✅ FIX: เช็คว่าอยู่ใน trade หรือไม่
    local key = item.UUID or item.Name
    local isInTrade = self.StateManager:IsInTrade(key)
    
    local Card = Instance.new("Frame", self.Container)
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    Card.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(Card, 10)
    
    -- ✅ FIX: เปลี่ยนสี stroke ตามสถานะ
    local strokeColor = THEME.GlassStroke
    local strokeThickness = 1
    
    if isInTrade then
        strokeColor = THEME.Success
        strokeThickness = 2
    elseif isEquipped then
        strokeColor = THEME.Fail
        strokeThickness = 2
    end
    
    self.UIFactory.AddStroke(Card, strokeColor, strokeThickness, 0.5)

    -- ไอคอน
    local icon = Instance.new("ImageLabel", Card)
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0, 8)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://" .. tostring(item.Image or 0)
    icon.ScaleType = Enum.ScaleType.Fit
    
    -- ✅ แสดง EQUIP tag ถ้าสวมใส่อยู่
    if isEquipped then
        local eqTag = Instance.new("TextLabel", Card)
        eqTag.Text = "EQUIP"
        eqTag.Size = UDim2.new(0, 42, 0, 12)
        eqTag.Position = UDim2.new(1, -44, 0, 4)
        eqTag.BackgroundTransparency = 1
        eqTag.TextColor3 = THEME.Fail
        eqTag.Font = Enum.Font.GothamBlack
        eqTag.TextSize = 7
        eqTag.TextXAlignment = Enum.TextXAlignment.Right
    end

    -- ✨ แสดงดาว (Evolution) สำหรับ Pet/Monster
    if item.Raw and item.Raw.Evolution and tonumber(item.Raw.Evolution) > 0 then
        local starContainer = Instance.new("Frame", Card)
        starContainer.Size = UDim2.new(1, 0, 0, 15)
        starContainer.Position = UDim2.new(0, 0, 0, 68)
        starContainer.BackgroundTransparency = 1
        
        local layout = Instance.new("UIListLayout", starContainer)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Padding = UDim.new(0, -2)

        for i = 1, tonumber(item.Raw.Evolution) do
            local s = Instance.new("ImageLabel", starContainer)
            s.Size = UDim2.new(0, 12, 0, 12)
            s.BackgroundTransparency = 1
            s.Image = "rbxassetid://3926305904"
            s.ImageColor3 = THEME.StarColor or Color3.fromRGB(255, 215, 0)
        end
    end

    -- ชื่อและเลเวล
    local levelText = (item.Raw and item.Raw.Level) and (" [Lv."..item.Raw.Level.."]") or ""
    local amountText = (item.Amount and item.Amount > 1) and (" x"..item.Amount) or ""
    
    local nameLbl = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = item.Name .. levelText .. amountText,
        Size = UDim2.new(1, -8, 0, 25),
        Position = UDim2.new(0, 4, 1, -30),
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextColor = isInTrade and THEME.Success or THEME.TextWhite
    })
    nameLbl.TextWrapped = true

    -- ✅ FIX: ปุ่มส่ง (รองรับ toggle)
    local btn = Instance.new("TextButton", Card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    
    btn.MouseButton1Click:Connect(function()
        if not self.Utils.IsTradeActive() then 
            self.StateManager:SetStatus("⚠️ Trade Menu NOT open!", THEME.Fail, self.StatusLabel)
            return 
        end
        
        -- ✅ ห้าม add ถ้าสวมใส่อยู่
        if isEquipped then
            self.StateManager:SetStatus("🔒 Cannot trade equipped items!", THEME.Fail, self.StatusLabel)
            return
        end
        
        -- ✅ FIX: Toggle logic
        if isInTrade then
            -- ลบออกจาก trade
            local amount = (item.Category == "Crates") and (item.Amount or 1) or 1
            
            self.TradeManager.SendTradeSignal("Remove", {
                Name = item.Name, 
                Guid = item.UUID, 
                Service = item.Service, 
                Category = item.Category,
                ElementData = item.ElementData,
                RawInfo = item.Raw
            }, amount, self.StatusLabel, self.StateManager, self.Utils)
            
        else
            -- เพิ่มเข้า trade
            local amount = (item.Category == "Crates") and (item.Amount or 1) or 1
            
            self.TradeManager.SendTradeSignal("Add", {
                Name = item.Name, 
                Guid = item.UUID, 
                Service = item.Service, 
                Category = item.Category,
                ElementData = item.ElementData,
                RawInfo = item.Raw
            }, amount, self.StatusLabel, self.StateManager, self.Utils)
        end
        
        -- รีเฟรชทันที
        task.wait(0.1)
        self:RefreshInventory()
    end)
end

return InventoryTab
