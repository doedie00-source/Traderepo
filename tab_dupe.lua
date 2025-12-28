-- tab_dupe.lua
-- โมดูลจัดการหน้า Inventory และระบบ Dupe (Items, Pets, Secrets)
-- Version: Full Logic with Categories

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TabDupe = {}
TabDupe.__index = TabDupe

function TabDupe.new(deps)
    local self = setmetatable({}, TabDupe)
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    
    self.Parent = nil
    self.CurrentCategory = "Items" -- หมวดหมู่เริ่มต้น
    self.Container = nil
    
    -- ดึงข้อมูลเกม (Crates/Pets)
    self.CratesInfo = self.TradeManager.CratesInfo or {}
    self.PetsInfo = self.TradeManager.PetsInfo or {}
    
    return self
end

function TabDupe:Init(parentFrame)
    self.Parent = parentFrame
    local THEME = self.Config.THEME
    
    -- 1. สร้างแถบหมวดหมู่ด้านบน (Category Bar)
    local topBar = Instance.new("Frame", parentFrame)
    topBar.Name = "CategoryBar"
    topBar.Size = UDim2.new(1, 0, 0, 35)
    topBar.BackgroundTransparency = 1
    
    local listLayout = Instance.new("UIListLayout", topBar)
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.Padding = UDim.new(0, 5)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- สร้างปุ่มเลือกหมวดหมู่
    local categories = {"Items", "Pets", "Secrets", "Accessories"}
    self.CategoryButtons = {}

    for _, cat in ipairs(categories) do
        local btn = self.UIFactory.CreateButton({
            Parent = topBar,
            Text = cat,
            Size = UDim2.new(0, 90, 1, 0),
            BgColor = (self.CurrentCategory == cat) and THEME.BtnSelected or THEME.BtnDefault,
            OnClick = function()
                self:SetCategory(cat)
            end
        })
        self.CategoryButtons[cat] = btn
    end

    -- 2. พื้นที่แสดงรายการของ (Grid Area)
    local scrollContainer = Instance.new("ScrollingFrame", parentFrame)
    scrollContainer.Name = "InventoryContainer"
    scrollContainer.Size = UDim2.new(1, -10, 1, -50) -- หักความสูง TopBar
    scrollContainer.Position = UDim2.new(0, 5, 0, 45)
    scrollContainer.BackgroundTransparency = 1
    scrollContainer.ScrollBarThickness = 4
    scrollContainer.ScrollBarImageColor3 = THEME.BtnSelected
    self.Container = scrollContainer

    local grid = Instance.new("UIGridLayout", scrollContainer)
    grid.CellSize = UDim2.new(0, 140, 0, 150) -- ขนาดการ์ดไอเทม
    grid.CellPadding = UDim2.new(0, 10, 0, 10)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    -- เริ่มต้นแสดงผล
    self:RefreshInventory()
end

function TabDupe:SetCategory(catName)
    local THEME = self.Config.THEME
    self.CurrentCategory = catName
    self.StateManager.currentDupeTab = catName -- Sync กับ Global State

    -- อัปเดตสีปุ่ม
    for name, btn in pairs(self.CategoryButtons) do
        if name == catName then
            btn.BackgroundColor3 = THEME.BtnSelected
        else
            btn.BackgroundColor3 = THEME.BtnDefault
        end
    end

    -- รีเฟรชข้อมูลใหม่
    self:RefreshInventory()
end

function TabDupe:RefreshInventory()
    if not self.Container then return end
    
    -- ล้างของเก่า
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then 
        -- ถ้าโหลดข้อมูลไม่ได้ ให้แสดงข้อความแจ้งเตือน
        self.UIFactory.CreateLabel({
            Parent = self.Container,
            Text = "Loading Data...",
            Size = UDim2.new(1, 0, 0, 30),
            Position = UDim2.new(0, 0, 0, 20),
            TextColor = self.Config.THEME.TextGray
        })
        return 
    end

    -- แยก Logic ตามหมวดหมู่
    if self.CurrentCategory == "Items" then
        self:LoadItems(playerData)
    elseif self.CurrentCategory == "Pets" then
        self:LoadPets(playerData)
    elseif self.CurrentCategory == "Secrets" then
        self:LoadSecrets(playerData)
    elseif self.CurrentCategory == "Accessories" then
        self:LoadAccessories(playerData)
    end
    
    -- ปรับขนาด ScrollingFrame
    local layout = self.Container:FindFirstChild("UIGridLayout")
    if layout then
        self.Container.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end
end

-- ==========================================
-- Logic การโหลดแต่ละหมวดหมู่ (ดึงมาจากต้นฉบับ)
-- ==========================================

function TabDupe:LoadItems(playerData)
    local THEME = self.Config.THEME
    local inventory = playerData.ItemsService and playerData.ItemsService.Inventory or {}
    
    -- ลูปตาม Services (Tickets, Scrolls, etc.)
    for serviceName, items in pairs(inventory) do
        for itemId, amount in pairs(items) do
            if amount > 0 then
                -- หาข้อมูลไอเทม (ชื่อ/รูป)
                local itemName = "Item " .. tostring(itemId)
                local itemImage = "" 
                
                -- พยายามหาชื่อจาก Config (ถ้ามี CratesInfo หรือ Table อื่นๆ)
                -- (ตรงนี้ผมใส่ Logic เบื้องต้นไว้ให้)
                if self.CratesInfo[serviceName] then
                    -- Logic การหาชื่ออาจซับซ้อนตาม Data Structure จริง
                    itemName = serviceName .. " - " .. tostring(itemId)
                end

                -- สร้างการ์ด Item
                self:CreateItemCard({
                    Name = itemName,
                    Amount = amount,
                    Image = itemImage, -- ใส่ ID รูปถ้ามี
                    SubText = serviceName,
                    Key = serviceName .. "_" .. itemId,
                    OnClick = function()
                        -- Logic เมื่อกดเลือกไอเทม (ใส่เข้า Trade List)
                        print("Selected Item: " .. itemName)
                        -- StateManager:AddToTrade(...) 
                        -- ตรงนี้คุณสามารถเชื่อมกับ Trade Logic ได้เลย
                    end
                })
            end
        end
    end
end

function TabDupe:LoadPets(playerData)
    local THEME = self.Config.THEME
    local pets = playerData.PetsService and playerData.PetsService.OwnedPets or {}
    
    for uuid, petData in pairs(pets) do
        local petInfo = self.PetsInfo[petData.ID]
        local petName = petInfo and petInfo.Name or "Unknown Pet"
        local petImage = petInfo and petInfo.Image or "" -- ต้องใส่ prefix rbxassetid://
        
        local isEquipped = self.Utils.CheckIsEquipped(uuid, nil, "Pets", playerData)
        local borderCol = isEquipped and THEME.Success or THEME.BtnDefault

        local card = self:CreateItemCard({
            Name = petName,
            Amount = 1, -- สัตว์เลี้ยงนับเป็นตัว
            Image = petImage,
            SubText = "Lv. " .. (petData.Level or 1),
            Key = uuid,
            BorderColor = borderCol,
            OnClick = function()
                print("Selected Pet: " .. uuid)
                -- เรียก StateManager:TogglePetSelection(uuid)
            end
        })
        
        -- เพิ่มดาว Evolution ถ้ามี
        if petData.Evolution and petData.Evolution > 0 then
            local starLabel = self.UIFactory.CreateLabel({
                Parent = card,
                Text = string.rep("⭐", petData.Evolution),
                Size = UDim2.new(1, 0, 0, 20),
                Position = UDim2.new(0, 0, 1, -40),
                TextColor = self.Config.CONFIG.StarColor or Color3.new(1,1,0),
                TextSize = 14
            })
        end
    end
end

function TabDupe:LoadSecrets(playerData)
    -- Logic โหลด Secrets (คล้าย Pets)
    local secrets = playerData.MonsterService and playerData.MonsterService.OwnedMonsters or {}
    for name, data in pairs(secrets) do
        self:CreateItemCard({
            Name = name,
            Amount = data.Amount or 1,
            SubText = "Secret",
            OnClick = function() print("Selected Secret: " .. name) end
        })
    end
end

function TabDupe:LoadAccessories(playerData)
    -- Logic โหลด Accessories
    local accs = playerData.AccessoryService and playerData.AccessoryService.OwnedAccessories or {}
    for uuid, data in pairs(accs) do
        self:CreateItemCard({
            Name = "Accessory " .. data.ID,
            Amount = 1,
            SubText = "Equip",
            OnClick = function() print("Selected Acc: " .. uuid) end
        })
    end
end

-- ฟังก์ชันช่วยสร้างการ์ด (Item Card Helper)
function TabDupe:CreateItemCard(props)
    local THEME = self.Config.THEME
    local btn = self.UIFactory.CreateButton({
        Parent = self.Container,
        Text = "",
        Size = UDim2.new(0, 140, 0, 150),
        BgColor = THEME.PanelBg,
        OnClick = props.OnClick
    })
    
    -- ใส่เส้นขอบ
    self.UIFactory.AddStroke(btn, props.BorderColor or THEME.BtnDefault, 2)

    -- รูปภาพ
    if props.Image and props.Image ~= "" then
        local img = Instance.new("ImageLabel", btn)
        img.Size = UDim2.new(0, 80, 0, 80)
        img.Position = UDim2.new(0.5, -40, 0, 10)
        img.BackgroundTransparency = 1
        img.Image = props.Image
    end

    -- ชื่อของ
    self.UIFactory.CreateLabel({
        Parent = btn,
        Text = props.Name,
        Position = UDim2.new(0, 5, 0, 95),
        Size = UDim2.new(1, -10, 0, 20),
        TextSize = 12,
        TextColor = THEME.TextWhite,
        Font = Enum.Font.GothamBold
    })

    -- รายละเอียดรอง (เช่น จำนวน หรือ เลเวล)
    self.UIFactory.CreateLabel({
        Parent = btn,
        Text = props.SubText or ("x" .. (props.Amount or 1)),
        Position = UDim2.new(0, 5, 0, 115),
        Size = UDim2.new(1, -10, 0, 15),
        TextSize = 11,
        TextColor = THEME.TextGray
    })

    return btn
end

return TabDupe
