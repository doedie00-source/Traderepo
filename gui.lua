-- gui.lua
-- Main GUI Controller (Modular Version)

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    
    -- Dependencies
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.InventoryManager = deps.InventoryManager
    self.TradeManager = deps.TradeManager
    
    -- Injected Tabs
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

    -- Cleanup Old GUI
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end
    
    -- ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.DisplayOrder = 100
    self.ScreenGui.IgnoreGuiInset = true

    -- Mini Icon
    self:CreateMiniIcon()
    
    -- Main Window
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
    
    -- Title Bar
    self:CreateTitleBar()
    
    -- Sidebar
    self:CreateSidebar()
    
    -- Content Area
    self.ContentArea = Instance.new("Frame", self.MainFrame)
    self.ContentArea.Name = "ContentArea"
    self.ContentArea.Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH - 18, 1, -52)
    self.ContentArea.Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH + 10, 0, 42)
    self.ContentArea.BackgroundTransparency = 1
    self.ContentArea.BorderSizePixel = 0

    -- Status Bar
    self.StatusLabel = self.UIFactory.CreateLabel({
        Parent = self.MainFrame,
        Text = "🟢 Ready",
        Size = UDim2.new(1, -16, 0, 32),  -- ความสูง 32px
        Position = UDim2.new(0, 8, 1, -36),  -- ล่างสุดของหน้าต่าง
        TextColor = THEME.TextGray,
        TextSize = 11,
        Font = Enum.Font.GothamMedium,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    self.StatusLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
    self.StatusLabel.BackgroundTransparency = 0.5
    self.StatusLabel.BorderSizePixel = 0
    
    -- เส้นบนแบ่ง zone
    local topLine = Instance.new("Frame", self.StatusLabel)
    topLine.Size = UDim2.new(1, 0, 0, 1)
    topLine.Position = UDim2.new(0, 0, 0, 0)
    topLine.BackgroundColor3 = THEME.GlassStroke
    topLine.BackgroundTransparency = 0.7
    topLine.BorderSizePixel = 0
    
    -- Padding ซ้ายนิดหน่อย
    local padding = Instance.new("UIPadding", self.StatusLabel)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    
    -- ✨ จัดการข้อความยาว - ขึ้นบรรทัดใหม่แบบ dynamic
    self.StatusLabel.TextWrapped = true
    self.StatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    -- ถ้าข้อความยาว จะขยายความสูงอัตโนมัติ (ไม่เกิน 2 บรรทัด)
    self.StatusLabel.AutomaticSize = Enum.AutomaticSize.Y
    self.StatusLabel.Size = UDim2.new(1, -16, 0, 32)
    
    -- Start
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
    
    -- Title
    local titleLabel = self.UIFactory.CreateLabel({
        Parent = titleBar,
        Text = "  ⚡ Universal Trader",
        Size = UDim2.new(0.5, 0, 1, 0),
        TextColor = THEME.TextWhite,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Version Badge
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
    
    -- Close Button
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -34, 0, 4),
        Text = "✕",
        BgColor = THEME.Fail,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })
    
    -- Minimize Button
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
    sidebar.Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -50)
    sidebar.Position = UDim2.new(0, 8, 0, 42)
    sidebar.BackgroundColor3 = THEME.GlassBg
    sidebar.BackgroundTransparency = THEME.GlassTransparency
    sidebar.BorderSizePixel = 0
    
    self.UIFactory.AddCorner(sidebar, 10)
    self.UIFactory.AddStroke(sidebar, THEME.GlassStroke, 1, 0.7)
    
    -- Logo Area
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
    
    -- Buttons Container
    local btnContainer = Instance.new("Frame", sidebar)
    btnContainer.Size = UDim2.new(1, -12, 1, -65)
    btnContainer.Position = UDim2.new(0, 6, 0, 58)
    btnContainer.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.Padding = UDim.new(0, CONFIG.BUTTON_PADDING)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    -- Create Tab Buttons
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

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    
    self.StateManager.currentMainTab = tabName
    
    -- Update Button States
    for name, btn in pairs(self.SidebarButtons) do
        local isSelected = (name == tabName)
        
        -- Tween Color
        local targetColor = isSelected and THEME.AccentPurple or THEME.BtnDefault
        local targetTextColor = isSelected and THEME.TextWhite or THEME.TextGray
        
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = targetColor
        }):Play()
        
        TweenService:Create(btn, TweenInfo.new(0.2), {
            TextColor3 = targetTextColor
        }):Play()
    end
    
    -- Clear Content
    for _, child in pairs(self.ContentArea:GetChildren()) do
        child:Destroy()
    end
    self.ActiveTabInstance = nil
    
    -- Load New Tab
    if tabName == "Players" and self.TabsModules.Players then
        local tab = self.TabsModules.Players.new({
            UIFactory = self.UIFactory,
            StateManager = self.StateManager,
            TradeManager = self.TradeManager,
            Utils = self.Utils,
            Config = self.Config,
            StatusLabel = self.StatusLabel
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
            ScreenGui = self.ScreenGui
        })
        tab:Init(self.ContentArea)
        self.ActiveTabInstance = tab
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
        
        while self.ScreenGui.Parent do
            -- Update Players Tab Buttons
            if self.StateManager.currentMainTab == "Players" and self.ActiveTabInstance and self.ActiveTabInstance.UpdateButtonStates then
                self.ActiveTabInstance:UpdateButtonStates()
            end

            -- Trade Monitor
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("🔄 Trade closed → Reset", THEME.TextGray, self.StatusLabel)
                    
                    if self.StateManager.currentMainTab == "Dupe" and self.ActiveTabInstance then
                        self.ActiveTabInstance:RefreshInventory()
                    end
                end
            end
            
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    -- Player Events
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
