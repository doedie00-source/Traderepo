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
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then return end

    local HIDDEN = self.Config.HIDDEN_LISTS
    local itemsToRender = {}

    -- 1. เช็ค Pets (เอาดาวและเลเวลมาด้วย)
    if playerData.PetsService and playerData.PetsService.Pets then
        for uuid, data in pairs(playerData.PetsService.Pets) do
            if self:CheckHidden(data.Name, HIDDEN.Pets) then
                table.insert(itemsToRender, {
                    Name = data.Name, UUID = uuid, Category = "Pets", Service = "PetsService", 
                    Raw = data, Image = PetsInfo[data.Name] and PetsInfo[data.Name].Image
                })
            end
        end
    end

    -- 2. เช็ค Monsters (รองรับทั้งแบบ String และ Table)
    if playerData.MonsterService and playerData.MonsterService.SavedMonsters then
        for uuid, data in pairs(playerData.MonsterService.SavedMonsters) do
            local mName = (type(data) == "table") and data.Name or data
            if self:CheckHidden(mName, HIDDEN.Secrets) then
                table.insert(itemsToRender, {
                    Name = mName, UUID = uuid, Category = "Secrets", Service = "MonsterService", 
                    Raw = (type(data) == "table") and data or {Name = mName}, 
                    Image = MonsterInfo[mName] and MonsterInfo[mName].Image
                })
            end
        end
    end

    -- 3. เช็ค Accessories
    if playerData.AccessoryService and playerData.AccessoryService.Accessories then
        for uuid, data in pairs(playerData.AccessoryService.Accessories) do
            if self:CheckHidden(data.Name, HIDDEN.Accessories) then
                table.insert(itemsToRender, {
                    Name = data.Name, UUID = uuid, Category = "Accessories", Service = "AccessoryService", 
                    Raw = data, Image = AccessoryInfo[data.Name] and AccessoryInfo[data.Name].Image
                })
            end
        end
    end

    -- 4. เช็ค Crates
    if playerData.CratesService and playerData.CratesService.Crates then
        for name, amount in pairs(playerData.CratesService.Crates) do
            if amount > 0 and self:CheckHidden(name, HIDDEN.Crates) then
                table.insert(itemsToRender, {
                    Name = name, Amount = amount, Category = "Crates", Service = "CratesService", 
                    Image = CratesInfo[name] and CratesInfo[name].Image
                })
            end
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

    -- ไอคอน
    local icon = Instance.new("ImageLabel", Card)
    icon.Size = UDim2.new(0, 60, 0, 60)
    icon.Position = UDim2.new(0.5, -30, 0, 8)
    icon.BackgroundTransparency = 1
    icon.Image = "rbxassetid://" .. tostring(item.Image or 0)
    icon.ScaleType = Enum.ScaleType.Fit

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
            s.Image = "rbxassetid://3926305904" -- ไอคอนดาว
            s.ImageColor3 = THEME.StarColor or Color3.fromRGB(255, 215, 0)
        end
    end

    -- ชื่อและเลเวล
    local levelText = (item.Raw and item.Raw.Level) and (" [Lv."..item.Raw.Level.."]") or ""
    local nameLbl = self.UIFactory.CreateLabel({
        Parent = Card,
        Text = item.Name .. levelText,
        Size = UDim2.new(1, -8, 0, 25),
        Position = UDim2.new(0, 4, 1, -30),
        TextSize = 9,
        Font = Enum.Font.GothamBold,
        TextColor = THEME.TextWhite
    })
    nameLbl.TextWrapped = true

    -- ปุ่มส่ง
    local btn = Instance.new("TextButton", Card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        if not self.Utils.IsTradeActive() then return end
        self.TradeManager.SendTradeSignal("Add", {
            Name = item.Name, Guid = item.UUID, Service = item.Service, Category = item.Category, RawInfo = item.Raw
        }, 1, self.StatusLabel, self.StateManager, self.Utils)
        self.UIFactory.AddStroke(Card, THEME.Success, 2, 0)
    end)
end

return InventoryTab
