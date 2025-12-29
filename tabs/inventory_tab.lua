-- tabs/inventory_tab.lua
-- Hidden Inventory Tab (All Categories in One Page)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Load Info Modules (สำหรับเอารูปไอคอน)
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
    
    local sub = self.UIFactory.CreateLabel({
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
    
    -- ตั้งค่า Grid ให้สวยเหมือนหน้า Dupe
    local layout = self.Container:FindFirstChild("UIGridLayout")
    if layout then
        layout.CellSize = UDim2.new(0, 92, 0, 115)
        layout.CellPadding = UDim2.new(0, 8, 0, 8)
    end

    self:RefreshInventory()
end

function InventoryTab:RefreshInventory()
    -- Clear เก่า
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then return end

    local HIDDEN = self.Config.CONFIG.HIDDEN_LISTS -- ต้องมีใน config.lua
    local itemsToRender = {}

    -- 1. เช็ค Pets
    for uuid, data in pairs(playerData.PetsService.Pets or {}) do
        if self:CheckHidden(data.Name, HIDDEN.Pets) then
            table.insert(itemsToRender, {
                Name = data.Name, UUID = uuid, Category = "Pets", Service = "PetsService", 
                Raw = data, Image = PetsInfo[data.Name] and PetsInfo[data.Name].Image
            })
        end
    end

    -- 2. เช็ค Monsters (Secrets)
    for uuid, data in pairs(playerData.MonsterService.SavedMonsters or {}) do
        local mName = type(data) == "table" and data.Name or data
        if self:CheckHidden(mName, HIDDEN.Secrets) then
            table.insert(itemsToRender, {
                Name = mName, UUID = uuid, Category = "Secrets", Service = "MonsterService", 
                Raw = data, Image = MonsterInfo[mName] and MonsterInfo[mName].Image
            })
        end
    end

    -- 3. เช็ค Accessories
    for uuid, data in pairs(playerData.AccessoryService.Accessories or {}) do
        if self:CheckHidden(data.Name, HIDDEN.Accessories) then
            table.insert(itemsToRender, {
                Name = data.Name, UUID = uuid, Category = "Accessories", Service = "AccessoryService", 
                Raw = data, Image = AccessoryInfo[data.Name] and AccessoryInfo[data.Name].Image
            })
        end
    end

    -- 4. เช็ค Crates
    for name, amount in pairs(playerData.CratesService.Crates or {}) do
        if amount > 0 and self:CheckHidden(name, HIDDEN.Crates) then
            table.insert(itemsToRender, {
                Name = name, Amount = amount, Category = "Crates", Service = "CratesService", 
                Image = CratesInfo[name] and CratesInfo[name].Image
            })
        end
    end

    -- Render การ์ด
    for _, item in ipairs(itemsToRender) do
        self:CreateItemCard(item)
    end
end

function InventoryTab:CheckHidden(name, list)
    if not list then return false end
    for _, h in pairs(list) do if h == name then return true end end
    return false
end

function InventoryTab:CreateItemCard(item)
    local THEME = self.Config.THEME
    
    local Card = Instance.new("Frame", self.Container)
    Card.BackgroundColor3 = THEME.CardBg
    Card.BackgroundTransparency = 0.2
    self.UIFactory.AddCorner(Card, 10)
    self.UIFactory.AddStroke(Card, THEME.GlassStroke, 1, 0.5)

    -- รูปไอคอน
    local imgId = item.Image or 0
    local icon = Instance.new("ImageLabel", Card)
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://" .. tostring(imgId)
    icon.ScaleType = Enum.ScaleType.Fit

    -- ชื่อและรายละเอียด
    local details = self.Utils.GetItemDetails(item.Raw, item.Category)
    local nameLbl = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = item.Name .. details,
        Size = UDim2.new(1, -8, 0, 35),
        Position = UDim2.new(0, 4, 1, -40),
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextColor = THEME.TextWhite
    })
    nameLbl.TextWrapped = true
    nameLbl.RichText = true

    -- ถ้าเป็น Crates แสดงจำนวน
    if item.Amount then
        local amtLbl = self.UIFactory.CreateLabel({
            Parent = Card,
            Text = "x" .. item.Amount,
            Size = UDim2.new(0, 30, 0, 15),
            Position = UDim2.new(1, -35, 0, 5),
            TextColor = THEME.AccentBlue,
            Font = Enum.Font.Code,
            TextSize = 10
        })
    end

    -- ปุ่มกดส่ง Trade
    local btn = Instance.new("TextButton", Card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""

    btn.MouseButton1Click:Connect(function()
        if not self.Utils.IsTradeActive() then
            self.StateManager:SetStatus("⚠️ Open Trade first!", THEME.Fail, self.StatusLabel)
            return
        end
        
        -- ส่งของ (ถ้าเป็น Crate อาจจะต้องทำ Popup ถามจำนวน แต่เบื้องต้นส่ง 1)
        self.TradeManager.SendTradeSignal("Add", {
            Name = item.Name,
            Guid = item.UUID,
            Service = item.Service,
            Category = item.Category,
            RawInfo = item.Raw
        }, 1, self.StatusLabel, self.StateManager, self.Utils)
        
        -- เปลี่ยนสีขอบให้รู้ว่าส่งไปแล้ว
        self.UIFactory.AddStroke(Card, THEME.Warning, 2, 0)
    end)
end

return InventoryTab
