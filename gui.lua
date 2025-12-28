-- gui.lua
-- Main GUI Controller (Refactored)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    -- รับ Dependencies ทั้งหมด
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    -- รับ Modules ย่อย (Tabs)
    self.TabsModules = deps.Tabs or {} 
    
    self.ActiveTabInstance = nil -- เก็บ Instance ของ Tab ปัจจุบัน
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME

    -- 1. สร้าง Main ScreenGui
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

    -- 2. สร้าง Main Window (Frame หลัก)
    local mainFrame = Instance.new("Frame", self.ScreenGui)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = CONFIG.MAIN_WINDOW_SIZE
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = THEME.MainBg
    mainFrame.BackgroundTransparency = THEME.MainTransparency
    self.UIFactory.AddStroke(mainFrame, THEME.BtnSelected, 2, 0.5)
    
    -- ทำให้ลากได้
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Size = UDim2.new(1, 0, 0, 30)
    topBar.BackgroundTransparency = 1
    self.UIFactory.MakeDraggable(topBar, mainFrame)

    -- 3. สร้าง Sidebar (เมนูซ้าย)
    local sidebar = Instance.new("Frame", mainFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, 0)
    sidebar.BackgroundColor3 = THEME.PanelBg
    
    local title = self.UIFactory.CreateLabel({
        Parent = sidebar,
        Text = "TradeSys",
        Size = UDim2.new(1, 0, 0, 40),
        TextColor = THEME.BtnSelected,
        TextSize = 18,
        Font = Enum.Font.GothamBold
    })

    -- 4. พื้นที่เนื้อหา (Content Area)
    self.ContentArea = Instance.new("Frame", mainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH - 20, 1, -20)
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH + 10, 0, 10)
    self.ContentArea.BackgroundTransparency = 1

    -- สร้างปุ่มเมนู
    self:CreateSidebarButton(sidebar, "Players", "Players", 50)
    self:CreateSidebarButton(sidebar, "Dupe", "Inventory/Dupe", 100)
    
    -- Status Bar ด้านล่าง
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = mainFrame,
        Text = "Ready.",
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 1, -25),
        TextColor = THEME.TextGray,
        TextXAlign = Enum.TextXAlignment.Right
    })

    -- เปิดหน้าแรก
    self:SwitchTab("Players")
    self:StartMonitoring()
end

function GUI:CreateSidebarButton(parent, tabName, text, yOffset)
    self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Position = UDim2.new(0, 5, 0, yOffset),
        Size = UDim2.new(1, -10, 0, 40),
        OnClick = function()
            self:SwitchTab(tabName)
        end
    })
end

function GUI:SwitchTab(tabName)
    self.StateManager.currentMainTab = tabName
    
    -- ล้างหน้าเก่า
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    
    -- โหลด Tab ใหม่
    if tabName == "Players" and self.TabsModules.Players then
        -- สร้าง Instance ของ Tab Players
        self.ActiveTabInstance = self.TabsModules.Players.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        self.ActiveTabInstance:Init(self.ContentArea)
        
    elseif tabName == "Dupe" and self.TabsModules.Dupe then
        -- สร้าง Instance ของ Tab Dupe
        self.ActiveTabInstance = self.TabsModules.Dupe.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            InventoryManager = self.InventoryManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config
        })
        self.ActiveTabInstance:Init(self.ContentArea)
    end
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    
    task.spawn(function()
        local missingCounter = 0
        while self.ScreenGui.Parent do
            -- ถ้าอยู่หน้า Players ให้อัปเดตสถานะปุ่ม
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                self.ActiveTabInstance:UpdateButtonStates()
            end

            -- ระบบเช็ค Trade หลุด (Logic เดิม)
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("Trade closed -> Reset.", self.Config.THEME.TextGray, self.StatusLabel)
                    
                    -- ถ้ารีเซ็ตแล้วอยู่หน้า Dupe ให้รีเฟรชของกลับคืนมา
                    if self.StateManager.currentMainTab == "Dupe" and self.ActiveTabInstance then
                        self.ActiveTabInstance:RefreshInventory()
                    end
                end
            end
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
end

return GUI
