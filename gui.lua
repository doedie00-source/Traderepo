-- gui.lua (Clean Controller)
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local GUI = {}
GUI.__index = GUI

function GUI.new(deps)
    local self = setmetatable({}, GUI)
    self.Config = deps.Config
    self.Utils = deps.Utils
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.TradeManager = deps.TradeManager
    
    self.Tabs = {} -- เก็บรายชื่อ Tab
    self.TabButtons = {}
    self.ActiveTab = nil
    
    return self
end

function GUI:RegisterTab(name, icon, module)
    table.insert(self.Tabs, {Name = name, Icon = icon, Module = module})
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    -- Clear Old GUI
    if CoreGui:FindFirstChild(CONFIG.GUI_NAME) then
        CoreGui[CONFIG.GUI_NAME]:Destroy()
    end
    
    -- Create ScreenGui
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.IgnoreGuiInset = true

    -- Main Frame
    self.MainFrame = self.UIFactory.CreateFrame({
        Size = CONFIG.MAIN_WINDOW_SIZE,
        Position = UDim2.new(0.5, -425, 0.5, -275),
        BgColor = THEME.MainBg,
        BgTransparency = THEME.MainTransparency,
        Parent = self.ScreenGui,
        Stroke = true
    })
    
    -- Title Bar
    self:CreateTitleBar()
    
    -- Layout Containers
    self.Sidebar = self.UIFactory.CreateFrame({
        Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BgColor = Color3.fromRGB(15, 15, 20),
        Parent = self.MainFrame
    })
    
    self.ContentFrame = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, -CONFIG.SIDEBAR_WIDTH, 1, -40),
        Position = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 0, 40),
        BgTransparency = 1,
        Parent = self.MainFrame,
        ClipsDescendants = true
    })

    -- Render Sidebar Buttons
    self:RenderSidebar()
    
    -- Status Bar (ด้านล่าง)
    self.StatusLabel = self.UIFactory.CreateLabel({
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 1, -25),
        Text = "Ready.",
        TextXAlign = Enum.TextXAlignment.Right,
        TextColor = THEME.TextGray,
        TextSize = 10,
        Parent = self.ContentFrame,
        ZIndex = 10
    })

    -- Select First Tab
    if #self.Tabs > 0 then
        self:SwitchTab(self.Tabs[1].Name)
    end
    
    -- Toggle Keybind
    UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == CONFIG.TOGGLE_KEY then
            self.ScreenGui.Enabled = not self.ScreenGui.Enabled
        end
    end)
end

function GUI:CreateTitleBar()
    local THEME = self.Config.THEME
    local titleBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 0, 40),
        BgColor = Color3.fromRGB(10, 10, 12),
        Parent = self.MainFrame
    })
    
    self.UIFactory.CreateLabel({
        Text = "  ⚡ Universal Trader " .. self.Config.CONFIG.VERSION,
        Size = UDim2.new(0.5, 0, 1, 0),
        TextXAlign = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        Parent = titleBar
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        Text = "✕",
        BgColor = THEME.Fail,
        CornerRadius = 4,
        Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })
    
    self.UIFactory.MakeDraggable(titleBar, self.MainFrame)
end

function GUI:RenderSidebar()
    local THEME = self.Config.THEME
    local list = Instance.new("UIListLayout", self.Sidebar)
    list.Padding = UDim.new(0, 5)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    
    local pad = Instance.new("UIPadding", self.Sidebar)
    pad.PaddingTop = UDim.new(0, 10)

    for _, tab in ipairs(self.Tabs) do
        local btn = self.UIFactory.CreateButton({
            Size = UDim2.new(0.9, 0, 0, 35),
            Text = tab.Icon .. "  " .. tab.Name,
            Font = Enum.Font.GothamMedium,
            TextXAlign = Enum.TextXAlignment.Left,
            BgColor = THEME.BtnDefault,
            Parent = self.Sidebar,
            OnClick = function() self:SwitchTab(tab.Name) end
        })
        -- Padding Text
        local p = Instance.new("UIPadding", btn)
        p.PaddingLeft = UDim.new(0, 10)
        
        self.TabButtons[tab.Name] = btn
    end
end

function GUI:SwitchTab(tabName)
    local THEME = self.Config.THEME
    
    -- Update Sidebar Visuals
    for name, btn in pairs(self.TabButtons) do
        if name == tabName then
            btn.BackgroundColor3 = THEME.BtnSelected
            btn.TextColor3 = Color3.new(1,1,1)
        else
            btn.BackgroundColor3 = THEME.BtnDefault
            btn.TextColor3 = THEME.TextGray
        end
    end
    
    -- Update State
    self.StateManager.currentMainTab = tabName
    
    -- Clear Content
    for _, child in pairs(self.ContentFrame:GetChildren()) do
        if child ~= self.StatusLabel then -- เก็บ StatusLabel ไว้
            child:Destroy()
        end
    end
    
    -- Render New Tab
    local targetTab = nil
    for _, t in ipairs(self.Tabs) do
        if t.Name == tabName then targetTab = t break end
    end
    
    if targetTab and targetTab.Module then
        self.ActiveTab = targetTab.Module
        -- Pass ContentFrame and StatusLabel to Module
        targetTab.Module:Render(self.ContentFrame, self.StatusLabel)
    end
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        while self.ScreenGui.Parent do
            -- 1. Check Trade Status
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            
            -- 2. Auto Reset logic
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("Trade closed -> Reset.", THEME.TextGray, self.StatusLabel)
                    
                    -- Refresh Active Tab if needed
                    if self.ActiveTab and self.ActiveTab.Refresh then
                        self.ActiveTab:Refresh()
                    end
                end
            end
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
end

return GUI
