-- gui.lua
-- GUI Controller แบบ Refactored (Main Shell)
-- จัดการแค่โครงสร้างหน้าต่างและเมนู ส่วนเนื้อหาให้ Tabs จัดการ

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    -- รับ Dependencies
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    -- รับ Modules Tabs (ที่ส่งมาจาก main.lua)
    self.TabsModules = deps.Tabs or {} 
    
    self.ScreenGui = nil
    self.ContentArea = nil
    self.ActiveTabInstance = nil -- เก็บตัวแปรของ Tab ปัจจุบันที่กำลังแสดงผล
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME

    -- 1. ล้าง GUI เก่าและสร้าง ScreenGui ใหม่
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.DisplayOrder = 100

    -- 2. สร้าง Main Window Frame
    local mainFrame = Instance.new("Frame", self.ScreenGui)
    mainFrame.Name = "MainWindow"
    mainFrame.Size = CONFIG.MAIN_WINDOW_SIZE
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = THEME.MainBg
    mainFrame.BackgroundTransparency = THEME.MainTransparency
    
    -- ใส่เส้นขอบสวยๆ
    self.UIFactory.AddStroke(mainFrame, THEME.BtnSelected, 2, 0.5)
    
    -- ทำ title bar สำหรับลากหน้าต่าง
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    self.UIFactory.MakeDraggable(titleBar, mainFrame)

    -- 3. สร้าง Sidebar (เมนูซ้าย)
    local sidebar = Instance.new("Frame", mainFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, 0)
    sidebar.BackgroundColor3 = THEME.PanelBg
    sidebar.BorderSizePixel = 0
    
    -- โลโก้/ชื่อโปรแกรม
    self.UIFactory.CreateLabel({
        Parent = sidebar,
        Text = "TradeSys",
        Size = UDim2.new(1, 0, 0, 50),
        TextColor = THEME.BtnSelected,
        TextSize = 20,
        Font = Enum.Font.GothamBold
    })

    -- 4. พื้นที่เนื้อหา (Content Area)
    self.ContentArea = Instance.new("Frame", mainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH, 1, 0)
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 0, 0)
    self.ContentArea.BackgroundTransparency = 1

    -- สร้างปุ่มเมนู Sidebar
    self:CreateSidebarButton(sidebar, "Players", "👥 Players", 60)
    self:CreateSidebarButton(sidebar, "Dupe", "🎒 Inventory", 110)
    
    -- Status Label (ด้านล่างขวา)
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = mainFrame,
        Text = "Ready.",
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 1, -25),
        TextColor = THEME.TextGray,
        TextXAlign = Enum.TextXAlignment.Right
    })

    -- เปิดหน้าแรกทันที
    self:SwitchTab("Players")
    
    -- เริ่มระบบ Monitor
    self:StartMonitoring()
end

function GUI:CreateSidebarButton(parent, tabName, text, yOffset)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Position = UDim2.new(0, 10, 0, yOffset),
        Size = UDim2.new(1, -20, 0, 40),
        BgColor = THEME.BtnDefault,
        OnClick = function()
            self:SwitchTab(tabName)
        end
    })
    
    return btn
end

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    self.StateManager.currentMainTab = tabName
    
    -- 1. เคลียร์พื้นที่แสดงผล
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    self.ActiveTabInstance = nil -- Reset

    -- 2. เลือกโหลด Module ตามชื่อ Tab
    if tabName == "Players" and self.TabsModules.Players then
        local tab = self.TabsModules.Players.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        tab:Init(self.ContentArea)
        self.ActiveTabInstance = tab
        
    elseif tabName == "Dupe" and self.TabsModules.Dupe then
        local tab = self.TabsModules.Dupe.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            InventoryManager = self.InventoryManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        tab:Init(self.ContentArea)
        self.ActiveTabInstance = tab
    end
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        while self.ScreenGui.Parent do
            -- 1. อัปเดตสถานะปุ่มในหน้า Players (ถ้าเปิดอยู่)
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                self.ActiveTabInstance:UpdateButtonStates()
            end

            -- 2. เช็ค Trade หลุด (Logic เดิม)
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                -- ถ้ามีของค้างใน Trade state ให้รีเซ็ต
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("Trade closed -> Reset.", THEME.TextGray, self.StatusLabel)
                    
                    -- ถ้ารีเซ็ตแล้วเราอยู่หน้า Inventory ให้โหลดของใหม่
                    if self.StateManager.currentMainTab == "Dupe" and self.ActiveTabInstance then
                        self.ActiveTabInstance:RefreshInventory()
                    end
                end
            end
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    -- Auto Refresh เมื่อมีคนเข้าออก (ถ้าอยู่หน้า Players)
    Players.PlayerAdded:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance then
            self.ActiveTabInstance:RefreshList()
        end
    end)
    Players.PlayerRemoving:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance then
            self.ActiveTabInstance:RefreshList()
        end
    end)
end

return GUI-- gui.lua
-- GUI Controller แบบ Refactored (Main Shell)
-- จัดการแค่โครงสร้างหน้าต่างและเมนู ส่วนเนื้อหาให้ Tabs จัดการ

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    -- รับ Dependencies
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    -- รับ Modules Tabs (ที่ส่งมาจาก main.lua)
    self.TabsModules = deps.Tabs or {} 
    
    self.ScreenGui = nil
    self.ContentArea = nil
    self.ActiveTabInstance = nil -- เก็บตัวแปรของ Tab ปัจจุบันที่กำลังแสดงผล
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME

    -- 1. ล้าง GUI เก่าและสร้าง ScreenGui ใหม่
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.DisplayOrder = 100

    -- 2. สร้าง Main Window Frame
    local mainFrame = Instance.new("Frame", self.ScreenGui)
    mainFrame.Name = "MainWindow"
    mainFrame.Size = CONFIG.MAIN_WINDOW_SIZE
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = THEME.MainBg
    mainFrame.BackgroundTransparency = THEME.MainTransparency
    
    -- ใส่เส้นขอบสวยๆ
    self.UIFactory.AddStroke(mainFrame, THEME.BtnSelected, 2, 0.5)
    
    -- ทำ title bar สำหรับลากหน้าต่าง
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundTransparency = 1
    self.UIFactory.MakeDraggable(titleBar, mainFrame)

    -- 3. สร้าง Sidebar (เมนูซ้าย)
    local sidebar = Instance.new("Frame", mainFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, 0)
    sidebar.BackgroundColor3 = THEME.PanelBg
    sidebar.BorderSizePixel = 0
    
    -- โลโก้/ชื่อโปรแกรม
    self.UIFactory.CreateLabel({
        Parent = sidebar,
        Text = "TradeSys",
        Size = UDim2.new(1, 0, 0, 50),
        TextColor = THEME.BtnSelected,
        TextSize = 20,
        Font = Enum.Font.GothamBold
    })

    -- 4. พื้นที่เนื้อหา (Content Area)
    self.ContentArea = Instance.new("Frame", mainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH, 1, 0)
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 0, 0)
    self.ContentArea.BackgroundTransparency = 1

    -- สร้างปุ่มเมนู Sidebar
    self:CreateSidebarButton(sidebar, "Players", "👥 Players", 60)
    self:CreateSidebarButton(sidebar, "Dupe", "🎒 Inventory", 110)
    
    -- Status Label (ด้านล่างขวา)
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = mainFrame,
        Text = "Ready.",
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 1, -25),
        TextColor = THEME.TextGray,
        TextXAlign = Enum.TextXAlignment.Right
    })

    -- เปิดหน้าแรกทันที
    self:SwitchTab("Players")
    
    -- เริ่มระบบ Monitor
    self:StartMonitoring()
end

function GUI:CreateSidebarButton(parent, tabName, text, yOffset)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Position = UDim2.new(0, 10, 0, yOffset),
        Size = UDim2.new(1, -20, 0, 40),
        BgColor = THEME.BtnDefault,
        OnClick = function()
            self:SwitchTab(tabName)
        end
    })
    
    return btn
end

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    self.StateManager.currentMainTab = tabName
    
    -- 1. เคลียร์พื้นที่แสดงผล
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    self.ActiveTabInstance = nil -- Reset

    -- 2. เลือกโหลด Module ตามชื่อ Tab
    if tabName == "Players" and self.TabsModules.Players then
        local tab = self.TabsModules.Players.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        tab:Init(self.ContentArea)
        self.ActiveTabInstance = tab
        
    elseif tabName == "Dupe" and self.TabsModules.Dupe then
        local tab = self.TabsModules.Dupe.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            InventoryManager = self.InventoryManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        tab:Init(self.ContentArea)
        self.ActiveTabInstance = tab
    end
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        while self.ScreenGui.Parent do
            -- 1. อัปเดตสถานะปุ่มในหน้า Players (ถ้าเปิดอยู่)
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                self.ActiveTabInstance:UpdateButtonStates()
            end

            -- 2. เช็ค Trade หลุด (Logic เดิม)
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                -- ถ้ามีของค้างใน Trade state ให้รีเซ็ต
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("Trade closed -> Reset.", THEME.TextGray, self.StatusLabel)
                    
                    -- ถ้ารีเซ็ตแล้วเราอยู่หน้า Inventory ให้โหลดของใหม่
                    if self.StateManager.currentMainTab == "Dupe" and self.ActiveTabInstance then
                        self.ActiveTabInstance:RefreshInventory()
                    end
                end
            end
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    -- Auto Refresh เมื่อมีคนเข้าออก (ถ้าอยู่หน้า Players)
    Players.PlayerAdded:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance then
            self.ActiveTabInstance:RefreshList()
        end
    end)
    Players.PlayerRemoving:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance then
            self.ActiveTabInstance:RefreshList()
        end
    end)
end

return GUI
