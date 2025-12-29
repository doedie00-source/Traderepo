-- gui.lua
-- Main GUI Controller - FIXED RIGHT INFO LABEL

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    self.TabsModules = deps.Tabs or {}
    
    self.ScreenGui = nil
    self.MainFrame = nil
    self.ContentArea = nil
    self.ActiveTabInstance = nil
    self.SidebarButtons = {}
    
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    _G.ModernGUI = self

    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        pcall(function() CoreGui[CONFIG.GUI_NAME]:Destroy() end)
    end
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.DisplayOrder = 100
    self.ScreenGui.IgnoreGuiInset = true

    self:CreateMiniIcon()
    
    self.MainFrame = Instance.new("Frame", self.ScreenGui)
    self.MainFrame.Name = "MainWindow"
    self.MainFrame.Size = CONFIG.MAIN_WINDOW_SIZE
    self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    self.MainFrame.BackgroundColor3 = THEME.MainBg
    self.MainFrame.BackgroundTransparency = THEME.MainTransparency
    self.MainFrame.BorderSizePixel = 0
    self.MainFrame.ClipsDescendants = true
    
    self.UIFactory.AddCorner(self.MainFrame, 12)
    self.UIFactory.AddStroke(self.MainFrame, THEME.GlassStroke, 1, 0.6)
    
    self:CreateTitleBar()
    self:CreateSidebar()
    
    self.ContentArea = Instance.new("Frame", self.MainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH - 18, 1, -82) 
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH + 10, 0, 42)
    self.ContentArea.BackgroundTransparency = 1
    self.ContentArea.BorderSizePixel = 0

    -- ✨ Status Bar Container (พื้นหลัง)
    local StatusBarBg = Instance.new("Frame", self.MainFrame)
    StatusBarBg.Name = "StatusBar"
    StatusBarBg.Size = UDim2.new(1, -16, 0, 30)
    StatusBarBg.Position = UDim2.new(0, 8, 1, -36)
    StatusBarBg.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
    StatusBarBg.BackgroundTransparency = 0.5
    StatusBarBg.BorderSizePixel = 0
    StatusBarBg.ZIndex = 100
    
    local topLine = Instance.new("Frame", StatusBarBg)
    topLine.Size = UDim2.new(1, 0, 0, 1)
    topLine.BackgroundColor3 = THEME.GlassStroke
    topLine.BackgroundTransparency = 0.7
    topLine.BorderSizePixel = 0
    topLine.ZIndex = 101

    -- ✨ Status Label (ซ้าย - สำหรับสถานะระบบ)
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = StatusBarBg,
        Text = "🟢 Ready",
        Size = UDim2.new(0.6, 0, 1, 0), -- ใช้พื้นที่ 60% ทางซ้าย
        Position = UDim2.new(0, 12, 0, 0),
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- ✨ Info Label (ขวา - สำหรับ Warning Limits)
    self.InfoLabel = self.UIFactory.CreateLabel({
        Parent = StatusBarBg,
        Text = "",
        Size = UDim2.new(0.4, -12, 1, 0), -- ใช้พื้นที่ 40% ทางขวา
        Position = UDim2.new(1, -12, 0, 0),
        AnchorPoint = Vector2.new(1, 0),
        TextColor = THEME.Warning,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Right -- ชิดขวา
    })

    self:SwitchTab("Players")
    self:StartMonitoring()
    self:SetupKeybind()
end

function GUI:CreateMiniIcon()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    self.MiniIcon = self.UIFactory.CreateButton({
        Size = CONFIG.MINI_ICON_SIZE,
        Position = UDim2.new(0, 20, 0.5, -27),
        BgColor = THEME.MainBg,
        Text = "T",
        TextColor = THEME.AccentPurple,
        Font = Enum.Font.GothamBlack,
        TextSize = 28,
        Parent = self.ScreenGui,
        Corner = true,
        CornerRadius = 14,
        OnClick = function() self:ToggleWindow() end
    })
    self.MiniIcon.Visible = false
    self.MiniIcon.Active = true
    self.UIFactory.AddStroke(self.MiniIcon, THEME.AccentPurple, 2, 0)
    self.UIFactory.MakeDraggable(self.MiniIcon, self.MiniIcon)
end

function GUI:CreateTitleBar()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    local titleBar = Instance.new("Frame", self.MainFrame)
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 38)
    titleBar.BackgroundColor3 = THEME.GlassBg
    titleBar.BackgroundTransparency = THEME.GlassTransparency
    titleBar.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(titleBar, 12)
    
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = titleBar,
        Text = "  ⚡ Universal Trader",
        Size = UDim2.new(0.5, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local versionBadge = Instance.new("Frame", titleBar)
    versionBadge.Size = UDim2.new(0, 60, 0, 20)
    versionBadge.Position = UDim2.new(0, 180, 0.5, -10)
    versionBadge.BackgroundColor3 = THEME.AccentPurple
    versionBadge.BackgroundTransparency = 0.1
    versionBadge.BorderSizePixel = 0
    self.UIFactory.AddCorner(versionBadge, 5)
    
    local versionText = self.UIFactory.CreateLabel({
        Parent = versionBadge,
        Text = "V" .. CONFIG.VERSION:match("(%d+%.%d+)"),
        Size = UDim2.new(1, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 9,
        Font = Enum.Font.GothamBold
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -34, 0, 4),
        Text = "X",
        BgColor = THEME.Fail,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -68, 0, 4),
        Text = "─",
        BgColor = THEME.BtnDefault,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self:ToggleWindow() end
    })
    
    self.UIFactory.MakeDraggable(titleBar, self.MainFrame)
end

function GUI:CreateSidebar()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    local sidebar = Instance.new("Frame", self.MainFrame)
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -82)
    sidebar.Position = UDim2.new(0, 8, 0, 42)
    sidebar.BackgroundColor3 = THEME.GlassBg
    sidebar.BackgroundTransparency = THEME.GlassTransparency
    sidebar.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(sidebar, 10)
    self.UIFactory.AddStroke(sidebar, THEME.GlassStroke, 1, 0.7)
    
    local logoFrame = Instance.new("Frame", sidebar)
    logoFrame.Size = UDim2.new(1, 0, 0, 50)
    logoFrame.BackgroundTransparency = 1
    
    local logoText = self.UIFactory.CreateLabel({
        Parent = logoFrame,
        Text = "⚡",
        Size = UDim2.new(1, 0, 1, 0),
        TextColor = THEME.AccentPurple,
        TextSize = 28,
        Font = Enum.Font.GothamBold
    })
    
    local btnContainer = Instance.new("Frame", sidebar)
    btnContainer.Size = UDim2.new(1, -12, 1, -65)
    btnContainer.Position = UDim2.new(0, 6, 0, 58)
    btnContainer.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.Padding = UDim.new(0, CONFIG.BUTTON_PADDING)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    self:CreateSidebarButton(btnContainer, "Players", "👥 Players")
    self:CreateSidebarButton(btnContainer, "Dupe", "✨ Dupe")
end

function GUI:CreateSidebarButton(parent, tabName, text)
    local THEME = self.Config.THEME
    
    local btn = self.UIFactory.CreateButton({
        Parent = parent,
        Text = text,
        Size = UDim2.new(1, 0, 0, 38),
        BgColor = THEME.BtnDefault,
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        CornerRadius = 8,
        OnClick = function()
            self:SwitchTab(tabName)
        end
    })
    
    self.SidebarButtons[tabName] = btn
end

-- ในไฟล์ gui.lua

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    
    -- ✅ FIX: ถ้าเทรดเปิดอยู่ และพยายามไปหน้า Players → บังคับไป Inventory แทน
    if tabName == "Players" and self.Utils.IsTradeActive() then
        tabName = "Inventory"
        if self.StatusLabel then
            self.StateManager:SetStatus("Trade active → Redirected to Inventory", THEME.Warning, self.StatusLabel)
        end
    end
    
    self.StateManager.currentMainTab = tabName
    
    -- Animation ปุ่มเมนูซ้าย (คงเดิม)
    for name, btn in pairs(self.SidebarButtons) do
        local isSelected = (name == tabName)
        local targetColor = isSelected and THEME.AccentPurple or THEME.BtnDefault
        local targetTextColor = isSelected and THEME.TextWhite or THEME.TextGray
        
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = targetTextColor}):Play()
    end
    
    -- Clear content เก่า
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    self.ActiveTabInstance = nil

    -- ล้าง InfoLabel
    if self.InfoLabel then 
        self.InfoLabel.Text = "" 
    end
    
    -- Load tab ใหม่
    local success, err = pcall(function()
        if tabName == "Players" and self.TabsModules.Players then
            local tab = self.TabsModules.Players.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                TradeManager = self.TradeManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel,
                InfoLabel = self.InfoLabel -- อย่าลืมบรรทัดนี้ ต้องส่ง InfoLabel ไปด้วย
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
                Config = self.Config,
                StatusLabel = self.StatusLabel,
                ScreenGui = self.ScreenGui,
                InfoLabel = self.InfoLabel -- อย่าลืมบรรทัดนี้ ต้องส่ง InfoLabel ไปด้วย
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab
        
        elseif tabName == "Inventory" and self.TabsModules.Inventory then
            local tab = self.TabsModules.Inventory.new({
                UIFactory = self.UIFactory,
                StateManager = self.StateManager,
                InventoryManager = self.InventoryManager,
                TradeManager = self.TradeManager,
                Utils = self.Utils,
                Config = self.Config,
                StatusLabel = self.StatusLabel
            })
            tab:Init(self.ContentArea)
            self.ActiveTabInstance = tab    
        end
    end)

    if not success then
        warn("Failed to load tab " .. tostring(tabName) .. ": " .. tostring(err))
        self.StatusLabel.Text = "⚠️ Error loading tab: " .. tabName
    end
end

function GUI:ToggleWindow()
    if self.MainFrame.Visible then
        self.MainFrame.Visible = false
        self.MiniIcon.Visible = true
    else
        self.MainFrame.Visible = true
        self.MiniIcon.Visible = false
    end
end

function GUI:SetupKeybind()
    local CONFIG = self.Config.CONFIG
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
            self:ToggleWindow()
        end
    end)
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        
        while self.ScreenGui and self.ScreenGui.Parent do
            -- อัพเดทสถานะปุ่มในหน้า Players
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                pcall(function() self.ActiveTabInstance:UpdateButtonStates() end)
            end

            -- ตรวจสอบว่าหน้าต่างเทรดเปิดอยู่ไหม
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            -- ✅ FIX: เมื่อเทรดปิดจริง (เกินเวลาที่กำหนด)
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                
                -- ✅ ตรวจเช็ค: ถ้ามีของค้างในเทรด หรือเรายังอยู่หน้า Inventory ให้ทำการ Reset
                if next(self.StateManager.itemsInTrade) ~= nil or self.StateManager.currentMainTab == "Inventory" then
                    
                    local wasInInventory = (self.StateManager.currentMainTab == "Inventory")
                    
                    self.StateManager:ResetTrade()
                    
                    if self.StatusLabel then
                        self.StateManager:SetStatus("🔄 Trade closed → Reset", THEME.TextGray, self.StatusLabel)
                    end
                    
                    -- รีเฟรชหน้า Dupe (ถ้าเปิดค้างไว้)
                    if self.StateManager.currentMainTab == "Dupe" and self.ActiveTabInstance and self.ActiveTabInstance.RefreshInventory then
                        pcall(function() self.ActiveTabInstance:RefreshInventory() end)
                    end

                    -- ✅ FIX CRITICAL: สลับกลับไปหน้า Players เฉพาะเมื่อ
                    -- 1. เราอยู่หน้า Inventory
                    -- 2. เทรดปิดจริงๆ (missingCounter เกิน threshold แล้ว)
                    if wasInInventory then
                        task.wait(0.2) -- หน่วงเล็กน้อยเพื่อให้ UI update
                        self:SwitchTab("Players")
                    end
                    
                    -- รีเซ็ต counter หลัง reset
                    missingCounter = 0
                end
            end
            
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    -- รีเฟรชรายชื่อคนเมื่อเข้า/ออกเซิร์ฟ
    Players.PlayerAdded:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.RefreshList then
            pcall(function() self.ActiveTabInstance:RefreshList() end)
        end
    end)
    
    Players.PlayerRemoving:Connect(function()
        if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.RefreshList then
            pcall(function() self.ActiveTabInstance:RefreshList() end)
        end
    end)
end

return GUI
