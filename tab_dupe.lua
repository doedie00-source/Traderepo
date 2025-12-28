-- tab_dupe.lua
-- โมดูลจัดการหน้า Dupe (Inventory, Items, Pets)

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
    self.CurrentCategory = "Items" -- Items, Pets, Secrets, Accessories
    return self
end

function TabDupe:Init(parentFrame)
    self.Parent = parentFrame
    local THEME = self.Config.THEME
    
    -- 1. สร้างแถบหมวดหมู่ (Category Bar) ด้านบน
    local topBar = Instance.new("Frame", parentFrame)
    topBar.Size = UDim2.new(1, 0, 0, 35)
    topBar.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", topBar)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local categories = {"Items", "Pets", "Secrets", "Accessories"}
    for _, cat in ipairs(categories) do
        self.UIFactory.CreateButton({
            Parent = topBar,
            Text = cat,
            Size = UDim2.new(0, 80, 1, 0),
            BgColor = (self.CurrentCategory == cat) and THEME.BtnSelected or THEME.BtnDefault,
            OnClick = function()
                self.CurrentCategory = cat
                self.StateManager.currentDupeTab = cat -- อัปเดต State กลางด้วย
                self:RefreshInventory() -- รีเฟรชหน้าจอ
                
                -- อัปเดตสีปุ่ม
                for _, child in pairs(topBar:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.BackgroundColor3 = (child.Text == cat) and THEME.BtnSelected or THEME.BtnDefault
                    end
                end
            end
        })
    end

    -- 2. พื้นที่แสดงของ (Grid Area)
    local container = Instance.new("ScrollingFrame", parentFrame)
    container.Name = "InventoryContainer"
    container.Size = UDim2.new(1, 0, 1, -45) -- หักพื้นที่ TopBar
    container.Position = UDim2.new(0, 0, 0, 45)
    container.BackgroundTransparency = 1
    container.ScrollBarThickness = 4
    self.Container = container

    local grid = Instance.new("UIGridLayout", container)
    grid.CellSize = UDim2.new(0, 140, 0, 160) -- การ์ดแนวตั้ง
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    
    -- 3. ปุ่ม Action ด้านล่าง (Dupe / Delete / Evolve)
    -- (สามารถเพิ่ม Panel ด้านล่างสุดได้ถ้าต้องการ)

    self:RefreshInventory()
end

function TabDupe:RefreshInventory()
    if not self.Container then return end
    
    -- ล้างของเก่า
    for _, child in pairs(self.Container:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then child:Destroy() end
    end

    local playerData = self.InventoryManager.GetPlayerData()
    if not playerData then return end

    local THEME = self.Config.THEME
    local items = {} -- Logic ดึงของจะอยู่ที่นี่ (คล้ายโค้ดเดิมใน gui.lua)

    -- [ตัวอย่าง Logic ย่อ - ของจริงให้ก๊อป Logic การ Loop จาก gui.lua เดิมมาใส่]
    -- สมมติว่าดึงรายการของมาใส่ table 'items' แล้ว
    
    if self.CurrentCategory == "Items" then
        -- Loop items...
        -- ใช้ self.UIFactory.CreateCard(...) ถ้ามี หรือสร้าง Frame เอง
    elseif self.CurrentCategory == "Pets" then
        -- Loop pets...
    end

    -- Update Scrolling Size
    local layout = self.Container:FindFirstChild("UIGridLayout")
    local contentSize = layout.AbsoluteContentSize
    self.Container.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

return TabDupe
