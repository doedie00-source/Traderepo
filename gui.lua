-- gui.lua - Complete GUI Controller
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Knit = require(ReplicatedStorage.Packages.Knit)
local ReplicaListener = Knit.GetController("ReplicaListener")

-- Load Game Info
local SuccessLoadCrates, CratesInfo = pcall(function() return require(ReplicatedStorage.GameInfo.CratesInfo) end)
if not SuccessLoadCrates then CratesInfo = {} end

local SuccessLoadPets, PetsInfo = pcall(function() return require(ReplicatedStorage.GameInfo.PetsInfo) end)
if not SuccessLoadPets then PetsInfo = {} end

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
    return self
end

function GUI:Initialize()
    local CONFIG = self.Config.CONFIG
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = CONFIG.GUI_NAME
    self.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    self.ScreenGui.Parent = CoreGui
    self.ScreenGui.DisplayOrder = 100
    self.ScreenGui.IgnoreGuiInset = true
    
    self:CreateMiniIcon()
    self:CreateMainWindow()
    self:SetupKeybind()
    self:StartMonitoring()
end

function GUI:CreateMiniIcon()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    self.MiniIcon = self.UIFactory.CreateButton({
        Size = CONFIG.MINI_ICON_SIZE,
        Position = UDim2.new(0, 20, 0.5, -25),
        BgColor = THEME.MainBg,
        Text = "T",
        TextColor = THEME.BtnSelected,
        Font = Enum.Font.GothamBold,
        TextSize = 32,
        Parent = self.ScreenGui,
        Corner = true,
        CornerRadius = 10,
        OnClick = function() self:ToggleWindow("Open") end
    })
    self.MiniIcon.Visible = false
    self.MiniIcon.Active = true
    self.UIFactory.AddStroke(self.MiniIcon, THEME.BtnSelected, 2)
    self.UIFactory.MakeDraggable(self.MiniIcon, self.MiniIcon)
end

function GUI:CreateMainWindow()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    self.MainFrame = self.UIFactory.CreateFrame({
        Size = CONFIG.MAIN_WINDOW_SIZE,
        Position = UDim2.new(0.5, -400, 0.5, -250),
        BgColor = THEME.MainBg,
        BgTransparency = THEME.MainTransparency,
        Parent = self.ScreenGui,
        Stroke = true
    })
    self.MainFrame.Active = true
    
    self:CreateTitleBar()
    self:CreateStatusBar()
    self:CreateSidebar()
    self:CreateCenterPanel()
    self:CreatePopup()
    self:CreateConfirmOverlay()
    self:UpdateUIState()
end

function GUI:CreateTitleBar()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    local titleBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 0, 40),
        BgColor = Color3.fromRGB(0, 0, 0),
        BgTransparency = 0.7,
        Parent = self.MainFrame,
        CornerRadius = 12
    })
    
    self.UIFactory.CreateLabel({
        Text = "  🎯 Universal Trader (V" .. CONFIG.VERSION .. ")",
        Size = UDim2.new(0.6, 0, 1, 0),
        TextXAlign = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Parent = titleBar
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        Text = "X",
        BgColor = THEME.ItemEquip,
        Font = Enum.Font.GothamBold,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self.ScreenGui:Destroy() end
    })
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -70, 0, 5),
        Text = "-",
        BgColor = THEME.BtnMainTab,
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        CornerRadius = 6,
        Parent = titleBar,
        OnClick = function() self:ToggleWindow("Minimize") end
    })
    
    self.UIFactory.MakeDraggable(titleBar, self.MainFrame)
end

function GUI:CreateStatusBar()
    local THEME = self.Config.THEME
    
    self.StatusLabel = self.UIFactory.CreateLabel({
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.new(0, 10, 1, -25),
        Text = "Select a mode.",
        TextColor = THEME.TextGray,
        TextSize = 12,
        TextXAlign = Enum.TextXAlignment.Left,
        Parent = self.MainFrame
    })
end

function GUI:CreateSidebar()
    local CONFIG = self.Config.CONFIG
    
    local sidebar = self.UIFactory.CreateFrame({
        Size = UDim2.new(0, CONFIG.SIDEBAR_WIDTH, 1, -80),
        Position = UDim2.new(0, 10, 0, 50),
        Parent = self.MainFrame
    })
    
    local mainMenuContainer = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 0, 120),
        BgTransparency = 1,
        Parent = sidebar,
        Corner = false
    })
    
    local mainLayout = Instance.new("UIListLayout", mainMenuContainer)
    mainLayout.Padding = UDim.new(0, CONFIG.BUTTON_PADDING)
    mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local padding = Instance.new("UIPadding", mainMenuContainer)
    padding.PaddingTop = UDim.new(0, 10)
    
    self.SubMenuFrame = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 1, -130),
        Position = UDim2.new(0, 0, 0, 130),
        BgTransparency = 1,
        Parent = sidebar,
        Corner = false
    })
    self.SubMenuFrame.Visible = false
    
    local subLayout = Instance.new("UIListLayout", self.SubMenuFrame)
    subLayout.Padding = UDim.new(0, CONFIG.BUTTON_PADDING)
    subLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0.8, 0, 0, 1)
    line.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    line.BorderSizePixel = 0
    line.Position = UDim2.new(0.1, 0, 0, 125)
    line.Parent = sidebar
    
    self:CreateMainTabs(mainMenuContainer)
end

function GUI:CreateMainTabs(parent)
    self.MainTabButtons = {}
    local tabs = {
        {name = "Players", icon = "👥"},
        {name = "Dupe", icon = "✨"}
    }
    
    for _, tab in ipairs(tabs) do
        local btn = self.UIFactory.CreateButton({
            Size = UDim2.new(0, 100, 0, 30),
            Text = tab.icon .. " " .. tab.name,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            CornerRadius = 6,
            Parent = parent,
            OnClick = function()
                self.StateManager.selectedPets = {} 
                self.StateManager.selectedCrates = {}
                self.StateManager.currentMainTab = tab.name
                self:UpdateUIState()
            end
        })
        self.MainTabButtons[tab.name] = btn
    end
end

function GUI:UpdateSubTabs()
    local THEME = self.Config.THEME
    
    for _, child in pairs(self.SubMenuFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    self.SubTabButtons = {}
    
    local tabs = {}
    if self.StateManager.currentMainTab == "Dupe" then
        tabs = {"Items", "Crates", "Pets"} 
    end
    
    for _, tabName in ipairs(tabs) do
        local isSelected = (self.StateManager.currentMainTab == "Dupe" and self.StateManager.currentDupeTab == tabName)
        
        local btn = self.UIFactory.CreateButton({
            Size = UDim2.new(0, 100, 0, 25),
            Text = tabName,
            TextSize = 12,
            CornerRadius = 6,
            Parent = self.SubMenuFrame,
            OnClick = function()
                self.StateManager.selectedPets = {}
                self.StateManager.selectedCrates = {}
                if self.StateManager.currentMainTab == "Dupe" then
                    self.StateManager.currentDupeTab = tabName
                end
                self:UpdateUIState()
            end
        })
        
        btn.BackgroundColor3 = isSelected and THEME.BtnSelected or THEME.BtnDefault
        btn.TextColor3 = isSelected and Color3.new(1,1,1) or THEME.TextGray
        self.SubTabButtons[tabName] = btn
    end
end

function GUI:CreateCenterPanel()
    self.InvFrame = self.UIFactory.CreateFrame({
        Size = UDim2.new(0.79, 0, 1, -80),
        Position = UDim2.new(0, 140, 0, 50),
        Parent = self.MainFrame
    })
    
    self.InvHeader = self.UIFactory.CreateLabel({
        Size = UDim2.new(1, 0, 0, 30),
        Text = "List",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Parent = self.InvFrame
    })
    
    self.InvContainer = self.UIFactory.CreateScrollingFrame({
        Parent = self.InvFrame,
        Size = UDim2.new(1, -10, 1, -35)
    })
    
    self:CreatePetActionBar()
    self:CreateCrateActionBar()
    self:CreateDupeWarning()
end

function GUI:CreatePetActionBar()
    local THEME = self.Config.THEME
    
    self.PetActionBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 1, -40),
        BgTransparency = 0.2,
        BgColor = Color3.fromRGB(0, 0, 0),
        Parent = self.InvFrame,
        Corner = false
    })
    self.PetActionBar.Visible = false
    
    self.BtnDeletePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(0, 10, 0, 5),
        Text = "DELETE",
        BgColor = THEME.Fail,
        Parent = self.PetActionBar,
        OnClick = function()
            if self.Utils.IsTradeActive() then
                self.StateManager:SetStatus("🔒 Close Trade first!", THEME.Fail, self.StatusLabel)
                return
            end
            local count = 0
            for _ in pairs(self.StateManager.selectedPets) do count = count + 1 end
            if count == 0 then return end
            
            self:ShowConfirm("Delete " .. count .. " Pets?", function()
                self.TradeManager.DeleteSelectedPets(self.StatusLabel, function()
                    task.wait(0.5)
                    self.StateManager.selectedPets = {} 
                    self:RefreshInventory()
                end, self.StateManager, self.Utils)
            end)
        end
    })
    
    self.BtnEvoPet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 120, 0, 30),
        Position = UDim2.new(0.5, -60, 0, 5),
        Text = "EVOLVE",
        BgColor = Color3.fromRGB(40, 40, 40),
        Parent = self.PetActionBar,
        OnClick = function()
            if self.BtnEvoPet:GetAttribute("IsValid") then
                self.TradeManager.ExecuteEvolution(self.StatusLabel, function()
                    task.wait(0.6)
                    self:RefreshInventory()
                    self:UpdateEvoButtonState()
                end, self.StateManager)
            end
        end
    })
    
    self.BtnDupePet = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 80, 0, 30),
        Position = UDim2.new(1, -90, 0, 5),
        Text = "DUPE",
        BgColor = THEME.BtnDupe,
        Parent = self.PetActionBar,
        OnClick = function()
            self.TradeManager.ExecutePetDupe(self.StatusLabel, self.StateManager, self.Utils)
        end
    })
end

function GUI:CreateCrateActionBar()
    local THEME = self.Config.THEME
    
    self.CrateActionBar = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 1, -40),
        BgTransparency = 0.2,
        BgColor = Color3.fromRGB(0, 0, 0),
        Parent = self.InvFrame,
        Corner = false
    })
    self.CrateActionBar.Visible = false
    
    self.BtnAddAll1k = self.UIFactory.CreateButton({
        Size = UDim2.new(0, 140, 0, 30),
        Position = UDim2.new(1, -150, 0, 5),
        Text = "ADD 1K ALL",
        BgColor = Color3.fromRGB(0, 140, 255),
        Parent = self.CrateActionBar
    })
    self.UIFactory.AddStroke(self.BtnAddAll1k, Color3.new(1,1,1), 1, 0.5)
end

function GUI:CreateDupeWarning()
    self.DupeWarning = self.UIFactory.CreateLabel({
        Size = UDim2.new(1, -20, 0, 55),
        Position = UDim2.new(0, 10, 1, -60),
        Text = "",
        TextColor = Color3.fromRGB(255, 100, 100),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        Parent = self.InvFrame,
        Visible = false
    })
    self.DupeWarning.TextWrapped = true
end

function GUI:CreatePopup()
    local THEME = self.Config.THEME
    local CONFIG = self.Config.CONFIG
    
    self.PopupFrame = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 1, 0),
        BgColor = Color3.new(0, 0, 0),
        BgTransparency = 0.4,
        Parent = self.MainFrame,
        Corner = false
    })
    self.PopupFrame.Visible = false
    self.PopupFrame.ZIndex = 3000
    
    local popupBox = self.UIFactory.CreateFrame({
        Size = UDim2.new(0, 240, 0, 150),
        Position = UDim2.new(0.5, -120, 0.5, -75),
        BgColor = Color3.fromRGB(30, 30, 35),
        BgTransparency = 0,
        Parent = self.PopupFrame,
        CornerRadius = 8
    })
    popupBox.ZIndex = 3001
    self.UIFactory.AddStroke(popupBox, THEME.BtnSelected, 2, 0)
    
    self.UIFactory.CreateLabel({
        Text = "ENTER AMOUNT",
        Size = UDim2.new(1, 0, 0, 40),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor = Color3.new(1, 1, 1),
        Parent = popupBox
    }).ZIndex = 3002
    
    self.PopupInput = Instance.new("TextBox")
    self.PopupInput.Size = UDim2.new(0.8, 0, 0, 35)
    self.PopupInput.Position = UDim2.new(0.1, 0, 0.35, 0)
    self.PopupInput.Text = "1000"
    self.PopupInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    self.PopupInput.BackgroundTransparency = 0
    self.PopupInput.TextColor3 = Color3.new(1, 1, 1)
    self.PopupInput.Font = Enum.Font.Code
    self.PopupInput.TextSize = 18
    self.PopupInput.ClearTextOnFocus = false
    self.PopupInput.Parent = popupBox
    self.PopupInput.ZIndex = 3002
    self.UIFactory.AddCorner(self.PopupInput, 4)
    self.UIFactory.AddStroke(self.PopupInput, Color3.fromRGB(80, 80, 80), 1, 0)
    
    self.PopupConfirm = self.UIFactory.CreateButton({
        Size = UDim2.new(0.8, 0, 0, 35),
        Position = UDim2.new(0.1, 0, 0.7, 0),
        Text = "CONFIRM",
        BgColor = THEME.BtnSelected,
        CornerRadius = 6,
        Parent = popupBox
    })
    self.PopupConfirm.ZIndex = 3002
    
    self.UIFactory.CreateButton({
        Size = UDim2.new(0, 25, 0, 25),
        Position = UDim2.new(1, -30, 0, 5),
        Text = "X",
        BgColor = THEME.ItemEquip,
        CornerRadius = 4,
        Parent = popupBox,
        OnClick = function() self.PopupFrame.Visible = false end
    }).ZIndex = 3002
end

function GUI:CreateConfirmOverlay()
    local THEME = self.Config.THEME
    
    self.ConfirmOverlay = self.UIFactory.CreateFrame({
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BgColor = Color3.new(0, 0, 0),
        BgTransparency = 0.15,
        Parent = self.MainFrame,
        Corner = false
    })
    self.ConfirmOverlay.ZIndex = 2000
    self.ConfirmOverlay.Visible = false
    
    local box = self.UIFactory.CreateFrame({
        Size = UDim2.new(0, 320, 0, 160),
        Position = UDim2.new(0.5, -160, 0.5, -80),
        BgColor = Color3.fromRGB(30, 30, 35),
        BgTransparency = 0,
        Parent = self.ConfirmOverlay
    })
    box.ZIndex = 2001
    self.UIFactory.AddStroke(box, THEME.Fail, 2, 0)
    
    self.ConfirmTitle = self.UIFactory.CreateLabel({
        Text = "CONFIRM DELETE",
        Size = UDim2.new(1, 0, 0, 50),
        Position = UDim2.new(0, 0, 0, 10),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor = THEME.Fail,
        Parent = box
    })
    self.ConfirmTitle.ZIndex = 2002
    
    local subTitle = self.UIFactory.CreateLabel({
        Text = "Are you sure? This cannot be undone!",
        Size = UDim2.new(1, -20, 0, 40),
        Position = UDim2.new(0, 10, 0, 50),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor = Color3.new(0.8, 0.8, 0.8),
        Parent = box
    })
    subTitle.ZIndex = 2002
    subTitle.TextWrapped = true
    
    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, 0, 0, 45)
    btnContainer.Position = UDim2.new(0, 0, 1, -55)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = box
    btnContainer.ZIndex = 2002
    
    local layout = Instance.new("UIListLayout", btnContainer)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 15)
    
    local cancelBtn = self.UIFactory.CreateButton({
        Text = "CANCEL",
        Size = UDim2.new(0, 100, 0, 35),
        BgColor = Color3.fromRGB(60, 60, 65),
        Parent = btnContainer,
        OnClick = function()
            if self.currentConfirmConn then self.currentConfirmConn:Disconnect() end
            self.ConfirmOverlay.Visible = false
        end
    })
    cancelBtn.ZIndex = 2003
    
    self.ConfirmYesBtn = self.UIFactory.CreateButton({
        Text = "YES, DELETE",
        Size = UDim2.new(0, 120, 0, 35),
        BgColor = THEME.Fail,
        Parent = btnContainer
    })
    self.ConfirmYesBtn.ZIndex = 2003
end

function GUI:ShowConfirm(text, onYes)
    if self.currentConfirmConn then
        self.currentConfirmConn:Disconnect()
        self.currentConfirmConn = nil
    end
    
    self.ConfirmTitle.Text = text
    self.ConfirmOverlay.Visible = true
    
    self.currentConfirmConn = self.ConfirmYesBtn.MouseButton1Click:Connect(function()
        if self.currentConfirmConn then
            self.currentConfirmConn:Disconnect()
            self.currentConfirmConn = nil
        end
        self.ConfirmOverlay.Visible = false
        onYes()
    end)
end

function GUI:ShowQuantityPopup(itemData, onConfirm)
    self.PopupFrame.Visible = true
    local startValue = itemData.Default or 1
    local maxValue = itemData.Max or 999999
    
    self.PopupInput.Text = tostring(startValue)
    if self.StateManager.inputConnection then self.StateManager.inputConnection:Disconnect() end
    self.StateManager.inputConnection = self.Utils.SanitizeNumberInput(self.PopupInput, maxValue)
    
    local confirmConn
    confirmConn = self.PopupConfirm.MouseButton1Click:Connect(function()
        local quantity = tonumber(self.PopupInput.Text)
        if quantity and quantity > 0 and quantity <= maxValue then
            onConfirm(quantity)
            self.PopupFrame.Visible = false
            if self.StateManager.inputConnection then self.StateManager.inputConnection:Disconnect() end
        end
        confirmConn:Disconnect()
    end)
end

function GUI:ToggleWindow(state)
    if state == "Minimize" then
        self.MainFrame.Visible = false
        self.MiniIcon.Visible = true
    elseif state == "Open" then
        self.MainFrame.Visible = true
        self.MiniIcon.Visible = false
    elseif state == "Toggle" then
        if self.MainFrame.Visible then self:ToggleWindow("Minimize") else self:ToggleWindow("Open") end
    end
end

function GUI:SetupKeybind()
    local CONFIG = self.Config.CONFIG
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == CONFIG.TOGGLE_KEY then
            self:ToggleWindow("Toggle")
        end
    end)
end

function GUI:UpdateUIState()
    local THEME = self.Config.THEME
    
    self:UpdateSubTabs()
    self.DupeWarning.Visible = false
    self.PetActionBar.Visible = false
    self.CrateActionBar.Visible = false
    
    if self.InvContainer:FindFirstChild("UIGridLayout") then
        self.InvContainer:ClearAllChildren()
        local layout = Instance.new("UIListLayout", self.InvContainer)
        layout.Padding = UDim.new(0, self.Config.CONFIG.LIST_PADDING)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    self.InvContainer.Size = UDim2.new(1, -10, 1, -35)
    
    local SIDEBAR_WIDTH = 140
    
    if self.StateManager.currentMainTab == "Players" then
        self.SubMenuFrame.Visible = false
        self.InvFrame.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 50)
        self.InvFrame.Size = UDim2.new(1, -SIDEBAR_WIDTH - 10, 1, -80)
        self.InvHeader.Text = "Server Players (Force Trade)"
    elseif self.StateManager.currentMainTab == "Dupe" then
        self.SubMenuFrame.Visible = true
        self.InvFrame.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 50)
        self.InvFrame.Size = UDim2.new(1, -SIDEBAR_WIDTH - 10, 1, -80)
        self.InvHeader.Text = "✨ Magic Dupe (" .. self.StateManager.currentDupeTab .. ")"
        
        if self.StateManager.currentDupeTab == "Pets" then
            self.PetActionBar.Visible = true
            self.InvContainer.Size = UDim2.new(1, -10, 1, -80)
        elseif self.StateManager.currentDupeTab == "Crates" then
            self.CrateActionBar.Visible = true
            self.InvContainer.Size = UDim2.new(1, -10, 1, -80)
        else
            self.DupeWarning.Visible = true
            self.InvContainer.Size = UDim2.new(1, -10, 1, -95)
            local limitInfo = "SCROLLS: ~150 | TICKETS: 10k | POTIONS: 2k"
            self.DupeWarning.Text = "⚠️ WARNING: Do not exceed limits.\n" .. limitInfo .. "\nRisk of ban if hoarding excessive amounts."
        end
    end
    
    for name, btn in pairs(self.MainTabButtons) do
        local isSelected = (name == self.StateManager.currentMainTab)
        btn.BackgroundColor3 = isSelected and THEME.BtnMainTabSelected or THEME.BtnMainTab
        if name == "Dupe" and isSelected then btn.BackgroundColor3 = THEME.BtnDupe end
        btn.TextColor3 = isSelected and Color3.new(1, 1, 1) or THEME.TextGray
    end
    
    self:RefreshInventory()
end

function GUI:RefreshInventory()
    for _, child in pairs(self.InvContainer:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    
    if self.StateManager.currentMainTab == "Players" then
        self:RenderPlayersList()
    elseif self.StateManager.currentMainTab == "Dupe" then
        if self.StateManager.currentDupeTab == "Crates" then
            self:RenderCrateGrid()
        elseif self.StateManager.currentDupeTab == "Pets" then
            self:RenderPetDupeGrid()
        else
            self:RenderItemDupeGrid()
        end
    end
end

function GUI:RenderPlayersList()
    local THEME = self.Config.THEME
    
    self.StateManager.playerButtons = {}
    local isTrading = self.Utils.IsTradeActive()
    local count = 0
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = self.UIFactory.CreateButton({
                Size = UDim2.new(1, 0, 0, 35),
                BgColor = Color3.fromRGB(35, 35, 40),
                BgTransparency = 0.2,
                Text = "  👤 " .. plr.DisplayName .. " (@" .. plr.Name .. ")",
                TextColor = THEME.PlayerBtn,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlign = Enum.TextXAlignment.Left,
                CornerRadius = 6,
                Parent = self.InvContainer
            })
            
            local actionBtn = self.UIFactory.CreateButton({
                Size = UDim2.new(0, 80, 0, 25),
                Position = UDim2.new(1, -85, 0, 5),
                Text = "TRADE",
                BgColor = isTrading and THEME.BtnDisabled or THEME.BtnSelected,
                TextColor = isTrading and THEME.TextDisabled or THEME.TextWhite,
                Font = Enum.Font.GothamBold,
                CornerRadius = 4,
                Parent = btn
            })
            actionBtn.AutoButtonColor = not isTrading
            table.insert(self.StateManager.playerButtons, actionBtn)
            actionBtn:SetAttribute("OriginalColor", THEME.BtnSelected)
            actionBtn:SetAttribute("OriginalTextColor", THEME.TextWhite)
            
            actionBtn.MouseButton1Click:Connect(function()
                if self.Utils.IsTradeActive() then
                    self.StateManager:SetStatus("🔒 Trade is active! Finish it first.", THEME.ItemEquip, self.StatusLabel)
                    return
                end
                self.TradeManager.ForceTradeWith(plr, self.StatusLabel, self.StateManager, self.Utils)
            end)
            count = count + 1
        end
    end
    self.InvContainer.CanvasSize = UDim2.new(0, 0, 0, count * 38)
end

function GUI:RenderCrateGrid()
    local THEME = self.Config.THEME
    local CONFIG = self.Config.CONFIG
    
    self.InvContainer.ScrollBarThickness = 0
    self.InvContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.InvContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local containerPadding = self.InvContainer:FindFirstChild("UIPadding")
    if not containerPadding then
        containerPadding = Instance.new("UIPadding", self.InvContainer)
    end
    containerPadding.PaddingTop = UDim.new(0, 15)
    containerPadding.PaddingBottom = UDim.new(0, 15)
    containerPadding.PaddingLeft = UDim.new(0, 10)
    containerPadding.PaddingRight = UDim.new(0, 10)
    
    local replica = ReplicaListener:GetReplica()
    local playerData = replica and replica.Data
    local inventoryCrates = (playerData and playerData.CratesService and playerData.CratesService.Crates) or {}
    
    if self.InvContainer:FindFirstChild("UIListLayout") then
        self.InvContainer.UIListLayout:Destroy()
    end
    
    local layout = self.InvContainer:FindFirstChild("UIGridLayout")
    if not layout then
        layout = Instance.new("UIGridLayout", self.InvContainer)
        layout.CellPadding = UDim2.new(0, 8, 0, 8)
        layout.CellSize = UDim2.new(0, 95, 0, 105)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    
    local cratesList = {}
    for internalId, info in pairs(CratesInfo) do
        if type(info) == "table" then
            local displayName = info.Name or internalId
            if displayName ~= "KeKa Crate" then
                table.insert(cratesList, {
                    DisplayName = displayName,
                    InternalID = internalId,
                    Image = info.Image or "0"
                })
            end
        end
    end
    table.sort(cratesList, function(a, b) return a.DisplayName < b.DisplayName end)
    
    if self.AddAllConn then self.AddAllConn:Disconnect() end
    self.AddAllConn = self.BtnAddAll1k.MouseButton1Click:Connect(function()
        if not self.Utils.IsTradeActive() then
            self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
            return
        end
        
        self.BtnAddAll1k.Active = false
        self.BtnAddAll1k.Text = "ADDING..."
        self.StateManager:SetStatus("🚀 Adding all crates (1,000 each)...", THEME.BtnSelected, self.StatusLabel)
        
        task.spawn(function()
            local addedCount = 0
            for _, crate in ipairs(cratesList) do
                local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
                if amountInInv == nil then
                    self.TradeManager.SendTradeSignal("Add", {
                        Name = crate.DisplayName,
                        Service = "CratesService",
                        Category = "Crates"
                    }, 1000, self.StatusLabel, self.StateManager, self.Utils)
                    addedCount = addedCount + 1
                    task.wait(0.05)
                end
            end
            self.StateManager:SetStatus("✅ Added " .. addedCount .. " types!", THEME.Success, self.StatusLabel)
            self.BtnAddAll1k.Active = true
            self.BtnAddAll1k.Text = "✨ ADD 1K ALL"
            self:RefreshInventory()
        end)
    end)
    
    for _, crate in ipairs(cratesList) do
        local amountInInv = inventoryCrates[crate.DisplayName] or inventoryCrates[crate.InternalID]
        local isOwnedInSystem = (amountInInv ~= nil)
        local isSelected = self.StateManager.selectedCrates[crate.DisplayName] ~= nil
        local isInTrade = self.StateManager:IsInTrade(crate.DisplayName)
        local shouldHighlight = isSelected or isInTrade
        
        local Card = Instance.new("Frame")
        Card.Name = crate.DisplayName
        Card.Parent = self.InvContainer
        Card.BackgroundColor3 = isOwnedInSystem and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(35, 35, 40)
        Card.BackgroundTransparency = 0.1
        self.UIFactory.AddCorner(Card, 8)
        
        local strokeColor = Color3.fromRGB(60, 60, 65)
        if isOwnedInSystem then
            strokeColor = Color3.fromRGB(180, 40, 40)
        elseif shouldHighlight then
            strokeColor = THEME.CrateSelected
        end
        self.UIFactory.AddStroke(Card, strokeColor, 1.5, isOwnedInSystem and 0.3 or 0.2)
        
        local Image = Instance.new("ImageLabel")
        Image.Parent = Card
        Image.BackgroundTransparency = 1
        Image.Position = UDim2.new(0.5, -30, 0, 10)
        Image.Size = UDim2.new(0, 60, 0, 60)
        Image.ImageTransparency = isOwnedInSystem and 0.6 or 0
        local imgId = tostring(crate.Image)
        if not imgId:find("rbxassetid://") then imgId = "rbxassetid://" .. imgId end
        Image.Image = imgId
        Image.ScaleType = Enum.ScaleType.Fit
        Image.ZIndex = 2
        
        local NameLbl = Instance.new("TextLabel")
        NameLbl.Parent = Card
        NameLbl.BackgroundTransparency = 1
        NameLbl.Position = UDim2.new(0, 5, 0, 72)
        NameLbl.Size = UDim2.new(1, -10, 0, 28)
        NameLbl.Font = Enum.Font.GothamMedium
        
        if shouldHighlight then
            local amt = self.StateManager.selectedCrates[crate.DisplayName] or
                        (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 0
            NameLbl.Text = crate.DisplayName .. "\n<font color='#00FF64'>[x" .. amt .. "]</font>"
            NameLbl.TextColor3 = THEME.CrateSelected
        elseif isOwnedInSystem then
            NameLbl.Text = crate.DisplayName .. "\n<font color='#AAAAAA'>(OWNED)</font>"
            NameLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        else
            NameLbl.Text = crate.DisplayName
            NameLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
        end
        NameLbl.RichText = true
        NameLbl.TextSize = 9
        NameLbl.TextWrapped = true
        NameLbl.TextYAlignment = Enum.TextYAlignment.Top
        NameLbl.ZIndex = 2
        
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Parent = Card
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Size = UDim2.new(1, 0, 1, 0)
        ClickBtn.Text = ""
        ClickBtn.ZIndex = 10
        
        ClickBtn.MouseButton1Click:Connect(function()
            if not self.Utils.IsTradeActive() then
                self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
                return
            end
            if isOwnedInSystem then
                self.StateManager:SetStatus("🚫 Locked: You already own this crate.", Color3.fromRGB(255, 80, 80), self.StatusLabel)
                return
            end
            
            local isAlreadyAdded = self.StateManager.selectedCrates[crate.DisplayName] or self.StateManager:IsInTrade(crate.DisplayName)
            
            if isAlreadyAdded then
                local oldAmount = self.StateManager.selectedCrates[crate.DisplayName] or
                                (self.StateManager.itemsInTrade[crate.DisplayName] and self.StateManager.itemsInTrade[crate.DisplayName].Amount) or 1000
                self.StateManager:ToggleCrateSelection(crate.DisplayName, nil)
                self.TradeManager.SendTradeSignal("Remove", {
                    Name = crate.DisplayName,
                    Service = "CratesService",
                    Category = "Crates"
                }, oldAmount, self.StatusLabel, self.StateManager, self.Utils)
                self:RefreshInventory()
            else
                self:ShowQuantityPopup({Default = 1000, Max = 9999}, function(qty)
                    self.StateManager:ToggleCrateSelection(crate.DisplayName, qty)
                    self.TradeManager.SendTradeSignal("Add", {
                        Name = crate.DisplayName,
                        Service = "CratesService",
                        Category = "Crates"
                    }, qty, self.StatusLabel, self.StateManager, self.Utils)
                    self:RefreshInventory()
                end)
            end
        end)
    end
end

function GUI:RenderPetDupeGrid()
    local THEME = self.Config.THEME
    
    local ALLOWED_PETS = {
        ["Meowrrior"] = true,
        ["Batkin"] = true,
        ["Xmastree"] = true,
        ["Malame"] = true,
        ["Meowl"] = true,
        ["Medus"] = true,
        ["Flame"] = true,
        ["Mega Flame"] = true,
        ["Turbo Flame"] = true,
        ["Ultra Flame"] = true,
        ["I2Pet"] = true
    }
    
    if not self.TooltipRef then
        local tip = Instance.new("TextLabel")
        tip.Name = "GlobalTooltip"
        tip.Size = UDim2.new(0, 250, 0, 30)
        tip.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        tip.TextColor3 = Color3.new(1, 1, 1)
        tip.TextSize = 12
        tip.Font = Enum.Font.Code
        tip.ZIndex = 300
        tip.Visible = false
        tip.Parent = self.ScreenGui
        
        self.UIFactory.AddStroke(tip, THEME.BtnSelected, 1, 0.5)
        self.UIFactory.AddCorner(tip, 6)
        self.TooltipRef = tip
        
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and self.TooltipRef.Visible then
                self.TooltipRef.Position = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y + 15)
            end
        end)
    end
    
    self.InvContainer.ScrollBarThickness = 0
    self.InvContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.InvContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if not self.InvContainer:FindFirstChild("UIPadding") then
        local padding = Instance.new("UIPadding", self.InvContainer)
        padding.PaddingTop = UDim.new(0, 10)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
    end
    
    if self.InvContainer:FindFirstChild("UIListLayout") then
        self.InvContainer.UIListLayout:Destroy()
    end
    
    local layout = self.InvContainer:FindFirstChild("UIGridLayout")
    if not layout then
        layout = Instance.new("UIGridLayout", self.InvContainer)
        layout.CellSize = UDim2.new(0, 100, 0, 120)
        layout.CellPadding = UDim2.new(0, 10, 0, 10)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.SortOrder = Enum.SortOrder.LayoutOrder
    end
    
    local replica = ReplicaListener:GetReplica()
    local MyPetsData = replica and replica.Data.PetsService and replica.Data.PetsService.Pets
    local rawEquipped = replica and replica.Data.PetsService and replica.Data.PetsService.EquippedPets or {}
    local EquippedUUIDs = {}
    for _, uuid in pairs(rawEquipped) do EquippedUUIDs[uuid] = true end
    
    if not MyPetsData then return end
    
    local sortedPets = {}
    for uuid, data in pairs(MyPetsData) do
        if data.Name and ALLOWED_PETS[data.Name] then
            data.UUID = uuid
            table.insert(sortedPets, data)
        end
    end
    
    table.sort(sortedPets, function(a, b)
        local aEq = EquippedUUIDs[a.UUID] or false
        local bEq = EquippedUUIDs[b.UUID] or false
        if aEq ~= bEq then return aEq end
        local aEvo = a.Evolution or 0
        local bEvo = b.Evolution or 0
        if aEvo ~= bEvo then return aEvo > bEvo end
        return (a.Name or "") < (b.Name or "")
    end)
    
    for _, petData in ipairs(sortedPets) do
        local uuid = petData.UUID
        local petName = petData.Name or "Unknown"
        local evolution = petData.Evolution or 0
        local isEquipped = EquippedUUIDs[uuid] == true
        local isLocked = isEquipped
        
        local imageId = "rbxassetid://0"
        if PetsInfo[petName] and PetsInfo[petName].Image then
            imageId = "rbxassetid://" .. tostring(PetsInfo[petName].Image)
        end
        
        local Card = Instance.new("Frame")
        Card.Name = uuid
        Card.BackgroundColor3 = THEME.CardBg
        Card.Parent = self.InvContainer
        self.UIFactory.AddCorner(Card, 6)
        
        local Stroke = Instance.new("UIStroke")
        Stroke.Thickness = 2
        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        Stroke.Enabled = false
        Stroke.Parent = Card
        
        local OrderBadge = Instance.new("TextLabel")
        OrderBadge.Name = "OrderBadge"
        OrderBadge.Size = UDim2.new(0, 24, 0, 24)
        OrderBadge.Position = UDim2.new(1, -28, 0, 4)
        OrderBadge.BackgroundColor3 = THEME.BtnSelected
        OrderBadge.BackgroundTransparency = 0
        OrderBadge.TextColor3 = Color3.new(1, 1, 1)
        OrderBadge.Font = Enum.Font.GothamBold
        OrderBadge.TextSize = 14
        OrderBadge.Visible = false
        OrderBadge.ZIndex = 10
        OrderBadge.Parent = Card
        self.UIFactory.AddCorner(OrderBadge, 100)
        self.UIFactory.AddStroke(OrderBadge, Color3.new(1, 1, 1), 1, 0.5)
        
        local function UpdateState()
            local orderNum = self.StateManager.selectedPets[uuid]
            local isSelected = (orderNum ~= nil)
        
            if isLocked then
                Stroke.Color = THEME.CardStrokeLocked
                Stroke.Enabled = true
                OrderBadge.Visible = false
            elseif isSelected then
                Stroke.Color = THEME.CardStrokeSelected
                Stroke.Enabled = true
                OrderBadge.Text = tostring(orderNum)
                OrderBadge.Visible = true
            else
                Stroke.Enabled = false
                OrderBadge.Visible = false
            end
        end
        UpdateState()
        
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Size = UDim2.new(1, 0, 1, 0)
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""
        ClickBtn.ZIndex = 5
        ClickBtn.Parent = Card
        
        ClickBtn.MouseButton1Click:Connect(function()
            if isLocked then return end
            self.StateManager:TogglePetSelection(uuid)
            UpdateState()
            
            for _, otherCard in pairs(self.InvContainer:GetChildren()) do
                if otherCard:IsA("Frame") and otherCard:FindFirstChild("OrderBadge") then
                    local otherUUID = otherCard.Name
                    local otherOrder = self.StateManager.selectedPets[otherUUID]
                    local badge = otherCard.OrderBadge
                    local otherStroke = otherCard:FindFirstChild("UIStroke")
                    
                    if otherOrder then
                        badge.Text = tostring(otherOrder)
                        badge.Visible = true
                        if otherStroke then
                            otherStroke.Enabled = true
                            otherStroke.Color = THEME.CardStrokeSelected
                        end
                    else
                        badge.Visible = false
                        if not self.Utils.CheckIsEquipped(otherUUID, nil, "Pets", replica.Data) then
                            if otherStroke then otherStroke.Enabled = false end
                        end
                    end
                end
            end
            self:UpdateEvoButtonState()
        end)
        
        if isEquipped then
            local EqTag = Instance.new("TextLabel")
            EqTag.Text = "EQUIP"
            EqTag.Size = UDim2.new(0, 40, 0, 10)
            EqTag.Position = UDim2.new(1, -42, 0, 5)
            EqTag.BackgroundTransparency = 1
            EqTag.TextColor3 = THEME.CardStrokeLocked
            EqTag.Font = Enum.Font.GothamBlack
            EqTag.TextSize = 8
            EqTag.TextXAlignment = Enum.TextXAlignment.Right
            EqTag.ZIndex = 4
            EqTag.Parent = Card
        end
        
        if evolution > 0 then
            local StarContainer = Instance.new("Frame")
            StarContainer.Size = UDim2.new(0, 40, 0, 20)
            StarContainer.Position = UDim2.new(0, 4, 0, 4)
            StarContainer.BackgroundTransparency = 1
            StarContainer.ZIndex = 5
            StarContainer.Parent = Card
            
            local List = Instance.new("UIListLayout")
            List.FillDirection = Enum.FillDirection.Horizontal
            List.Padding = UDim.new(0, -3)
            List.Parent = StarContainer
            
            for i = 1, evolution do
                local Star = Instance.new("ImageLabel")
                Star.Size = UDim2.new(0, 14, 0, 14)
                Star.BackgroundTransparency = 1
                Star.Image = "rbxassetid://3926305904"
                Star.ImageRectOffset = Vector2.new(116, 4)
                Star.ImageRectSize = Vector2.new(24, 24)
                Star.ImageColor3 = THEME.StarColor
                Star.ZIndex = 6
                Star.Parent = StarContainer
            end
        end
        
        local Viewport = Instance.new("ImageLabel")
        Viewport.Size = UDim2.new(0, 65, 0, 65)
        Viewport.Position = UDim2.new(0.5, -32.5, 0, 15)
        Viewport.BackgroundTransparency = 1
        Viewport.Image = imageId
        Viewport.ScaleType = Enum.ScaleType.Fit
        Viewport.ZIndex = 2
        Viewport.Parent = Card
        
        local NameLbl = Instance.new("TextLabel")
        NameLbl.Text = petName
        NameLbl.Size = UDim2.new(1, -4, 0, 30)
        NameLbl.Position = UDim2.new(0, 2, 0, 78)
        NameLbl.BackgroundTransparency = 1
        NameLbl.TextColor3 = Color3.new(1, 1, 1)
        NameLbl.Font = Enum.Font.GothamBold
        NameLbl.TextSize = 10
        NameLbl.TextWrapped = true
        NameLbl.TextYAlignment = Enum.TextYAlignment.Top
        NameLbl.Parent = Card
        
        local shortID = uuid:sub(1, 5) .. ".." .. uuid:sub(#uuid - 4, #uuid)
        local UUIDDisplay = Instance.new("TextLabel")
        UUIDDisplay.Text = shortID
        UUIDDisplay.Size = UDim2.new(1, -8, 0, 16)
        UUIDDisplay.Position = UDim2.new(0, 4, 1, -20)
        UUIDDisplay.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        UUIDDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
        UUIDDisplay.Font = Enum.Font.Code
        UUIDDisplay.TextSize = 10
        UUIDDisplay.ZIndex = 3
        UUIDDisplay.Parent = Card
        self.UIFactory.AddCorner(UUIDDisplay, 4)
        self.UIFactory.AddStroke(UUIDDisplay, Color3.fromRGB(60, 60, 60), 1, 0.5)
        
        local HoverTrigger = Instance.new("TextButton")
        HoverTrigger.Text = ""
        HoverTrigger.BackgroundTransparency = 1
        HoverTrigger.Size = UDim2.new(1, 0, 1, 0)
        HoverTrigger.Parent = UUIDDisplay
        HoverTrigger.ZIndex = 10
        
        HoverTrigger.MouseButton1Click:Connect(function()
            if setclipboard then
                setclipboard(uuid)
                local originalText = shortID
                UUIDDisplay.Text = "COPIED!"
                UUIDDisplay.TextColor3 = Color3.fromRGB(0, 255, 127)
                self.StateManager:SetStatus("✅ Copied UUID to clipboard!", Color3.fromRGB(0, 255, 127), self.StatusLabel)
                task.delay(1, function()
                    if UUIDDisplay and UUIDDisplay.Parent then
                        UUIDDisplay.Text = originalText
                        UUIDDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end)
            else
                self.StateManager:SetStatus("⚠️ Executor not support clipboard", Color3.fromRGB(255, 100, 100), self.StatusLabel)
            end
        end)
        
        HoverTrigger.MouseEnter:Connect(function()
            if self.TooltipRef then
                self.TooltipRef.Text = " UUID: " .. uuid .. " "
                self.TooltipRef.Visible = true
                if UUIDDisplay:FindFirstChild("UIStroke") then
                    UUIDDisplay.UIStroke.Color = THEME.BtnSelected
                end
            end
        end)
        
        HoverTrigger.MouseLeave:Connect(function()
            if self.TooltipRef then
                self.TooltipRef.Visible = false
                if UUIDDisplay:FindFirstChild("UIStroke") then
                    UUIDDisplay.UIStroke.Color = Color3.fromRGB(60, 60, 60)
                end
            end
        end)
    end
end

function GUI:RenderItemDupeGrid()
    local THEME = self.Config.THEME
    local DUPE_RECIPES = self.Config.DUPE_RECIPES
    
    self.InvContainer.ScrollBarThickness = 0
    self.InvContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    self.InvContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    local padding = self.InvContainer:FindFirstChild("UIPadding")
    if not padding then
        padding = Instance.new("UIPadding", self.InvContainer)
        padding.PaddingTop = UDim.new(0, 15)
        padding.PaddingBottom = UDim.new(0, 15)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)
    end
    
    if self.InvContainer:FindFirstChild("UIListLayout") then
        self.InvContainer.UIListLayout:Destroy()
    end
    
    local layout = self.InvContainer:FindFirstChild("UIGridLayout")
    if not layout then
        layout = Instance.new("UIGridLayout", self.InvContainer)
        layout.CellPadding = UDim2.new(0, 8, 0, 8)
        layout.CellSize = UDim2.new(0, 95, 0, 120)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end
    
    local recipes = DUPE_RECIPES.Items or {}
    local playerData = self.InventoryManager.GetPlayerData()
    
    for _, recipe in ipairs(recipes) do
        local serviceName = recipe.Service
        
        local isOwned = false
        if playerData and playerData.ItemsService and playerData.ItemsService.Inventory then
            local inv = playerData.ItemsService.Inventory[serviceName]
            if inv then
                local amt = inv[tostring(recipe.Tier)] or inv[tonumber(recipe.Tier)] or 0
                if amt > 0 then isOwned = true end
            end
        end
        
        local totalNeeded, foundCount = 0, 0
        local isPotion = (serviceName == "Strawberry" or serviceName:find("Potion"))
        
        if isPotion then
            totalNeeded = #recipe.RequiredTiers
            for _, tier in ipairs(recipe.RequiredTiers) do
                if self.InventoryManager.HasItem(serviceName, tier, playerData) then
                    foundCount = foundCount + 1
                end
            end
        else
            totalNeeded = 2
            for _, tier in ipairs(recipe.RequiredTiers) do
                local tNum = tonumber(tier)
                if tNum > 2 and tNum ~= tonumber(recipe.Tier) then
                    if self.InventoryManager.HasItem(serviceName, tNum, playerData) then
                        foundCount = foundCount + 1
                    end
                end
            end
        end
        
        local isReady = (not isOwned) and (foundCount >= totalNeeded)
        
        local Card = Instance.new("Frame")
        Card.Name = recipe.Name
        Card.Parent = self.InvContainer
        Card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        Card.BackgroundTransparency = 0.1
        self.UIFactory.AddCorner(Card, 8)
        
        local statusColor = Color3.fromRGB(60, 60, 65)
        local statusText = ""
        
        if isOwned then
            statusColor = THEME.Fail
            statusText = "<font color='#ff5555' size='9'>(OWNED)</font>"
        elseif isReady then
            statusColor = THEME.DupeReady
            statusText = "<font color='#00ffaa' size='10'>READY</font>"
        else
            statusColor = Color3.fromRGB(255, 200, 50)
            statusText = string.format("<font color='#ffcc33' size='9'>Missing: %d/%d</font>", foundCount, totalNeeded)
        end
        
        self.UIFactory.AddStroke(Card, statusColor, 1.5, 0.3)
        
        local Image = Instance.new("ImageLabel")
        Image.Parent = Card
        Image.BackgroundTransparency = 1
        Image.Position = UDim2.new(0.5, -30, 0, 8)
        Image.Size = UDim2.new(0, 60, 0, 60)
        Image.Image = "rbxassetid://" .. (recipe.Image or "0")
        Image.ScaleType = Enum.ScaleType.Fit
        if isOwned then Image.ImageColor3 = Color3.fromRGB(100, 100, 100) end
        
        local NameLbl = Instance.new("TextLabel")
        NameLbl.Parent = Card
        NameLbl.BackgroundTransparency = 1
        NameLbl.Position = UDim2.new(0, 4, 0, 70)
        NameLbl.Size = UDim2.new(1, -8, 0, 45)
        NameLbl.Font = Enum.Font.GothamMedium
        NameLbl.TextSize = 10
        NameLbl.TextWrapped = true
        NameLbl.TextYAlignment = Enum.TextYAlignment.Top
        NameLbl.RichText = true
        NameLbl.Text = recipe.Name .. "\n" .. statusText
        NameLbl.TextColor3 = isOwned and Color3.fromRGB(150, 150, 150) or Color3.new(1, 1, 1)
        
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Parent = Card
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Size = UDim2.new(1, 0, 1, 0)
        ClickBtn.Text = ""
        
        ClickBtn.MouseButton1Click:Connect(function()
            if self.TradeManager.IsProcessing then return end
            if not self.Utils.IsTradeActive() then
                self.StateManager:SetStatus("⚠️ Open Trade Menu first!", THEME.Fail, self.StatusLabel)
                return
            end
            if isOwned then
                self.StateManager:SetStatus("❌ Already Owned!", THEME.Fail, self.StatusLabel)
                return
            end
            if not isReady then
                self.StateManager:SetStatus("⚠️ Missing Ingredients (" .. foundCount .. "/" .. totalNeeded .. ")", Color3.fromRGB(255, 200, 50), self.StatusLabel)
                return
            end
            
            local startVal, currentMax = 99, 100
            if serviceName == "Scrolls" then
                startVal, currentMax = 99, 120
            elseif serviceName == "Tickets" then
                startVal, currentMax = 5000, 10000
            else
                startVal, currentMax = 500, 1000
            end
            
            self:ShowQuantityPopup({Default = startVal, Max = currentMax}, function(quantity)
                self.TradeManager.ExecuteMagicDupe(recipe, self.StatusLabel, quantity, self.StateManager, self.Utils, self.InventoryManager)
            end)
        end)
    end
end

function GUI:UpdateEvoButtonState()
    if not self.BtnEvoPet then return end
    
    local THEME = self.Config.THEME
    local replica = ReplicaListener:GetReplica()
    local myPets = replica and replica.Data.PetsService and replica.Data.PetsService.Pets or {}
    
    local selectedPetsData = {}
    local count = 0
    
    for uuid, _ in pairs(self.StateManager.selectedPets) do
        if myPets[uuid] then
            table.insert(selectedPetsData, myPets[uuid])
            count = count + 1
        end
    end
    
    local btnText = "EVOLVE (0/3)"
    local isValid = false
    local failReason = ""
    
    if count ~= 3 then
        btnText = "SELECT 3 (" .. count .. "/3)"
        failReason = "Need exactly 3 pets"
    else
        local firstPet = selectedPetsData[1]
        local allSameName = true
        local allSameEvo = true
        local notMaxLevel = true
        
        for i = 2, #selectedPetsData do
            if selectedPetsData[i].Name ~= firstPet.Name then
                allSameName = false
            end
            if (selectedPetsData[i].Evolution or 0) ~= (firstPet.Evolution or 0) then
                allSameEvo = false
            end
        end
        
        if (firstPet.Evolution or 0) >= 2 then
            notMaxLevel = false
        end
        
        if not allSameName then
            btnText = "MISMATCH NAME"
            failReason = "Names must match"
        elseif not allSameEvo then
            btnText = "MISMATCH EVO"
            failReason = "Evolution tier must match"
        elseif not notMaxLevel then
            btnText = "MAX LEVEL"
            failReason = "Cannot evolve max tier (2)"
        else
            btnText = "🧬 EVOLVE NOW"
            isValid = true
        end
    end
    
    self.BtnEvoPet.Text = btnText
    
    if isValid then
        self.BtnEvoPet.BackgroundColor3 = THEME.BtnSelected
        self.BtnEvoPet.AutoButtonColor = true
        self.BtnEvoPet.TextTransparency = 0
    else
        self.BtnEvoPet.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        self.BtnEvoPet.AutoButtonColor = false
        self.BtnEvoPet.TextTransparency = 0.5
    end
    
    self.BtnEvoPet:SetAttribute("IsValid", isValid)
    self.BtnEvoPet:SetAttribute("Reason", failReason)
end

function GUI:UpdatePlayerButtonStates()
    local THEME = self.Config.THEME
    local tradeActive = self.Utils.IsTradeActive()
    
    for _, btn in pairs(self.StateManager.playerButtons) do
        if btn and btn.Parent then
            if tradeActive then
                btn.BackgroundColor3 = THEME.BtnDisabled
                btn.TextColor3 = THEME.TextDisabled
                btn.AutoButtonColor = false
            else
                if btn:GetAttribute("OriginalColor") then
                    btn.BackgroundColor3 = btn:GetAttribute("OriginalColor")
                end
                if btn:GetAttribute("OriginalTextColor") then
                    btn.TextColor3 = btn:GetAttribute("OriginalTextColor")
                end
                btn.AutoButtonColor = true
            end
        end
    end
end

function GUI:StartMonitoring()
    local CONFIG = self.Config.CONFIG
    local THEME = self.Config.THEME
    
    task.spawn(function()
        local missingCounter = 0
        while self.ScreenGui.Parent do
            self:UpdatePlayerButtonStates()
            if self.Utils.IsTradeActive() then
                missingCounter = 0
            else
                missingCounter = missingCounter + 1
            end
            if missingCounter > CONFIG.TRADE_RESET_THRESHOLD then
                self.TradeManager.IsProcessing = false
                if next(self.StateManager.itemsInTrade) ~= nil then
                    self.StateManager:ResetTrade()
                    self.StateManager:SetStatus("Trade closed → Reset.", THEME.TextGray, self.StatusLabel)
                    self:RefreshInventory()
                end
            end
            task.wait(CONFIG.BUTTON_CHECK_INTERVAL)
        end
    end)
    
    Players.PlayerAdded:Connect(function()
        if self.StateManager.currentMainTab == "Players" then
            self:RefreshInventory()
        end
    end)
    
    Players.PlayerRemoving:Connect(function()
        if self.StateManager.currentMainTab == "Players" then
            self:RefreshInventory()
        end
    end)
end

return GUI