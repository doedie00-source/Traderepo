-- tab_players.lua
local Players = game:GetService("Players")
local Tab = {}
Tab.__index = Tab

function Tab.new(deps)
    local self = setmetatable({}, Tab)
    self.Config = deps.Config
    self.UIFactory = deps.UIFactory
    self.TradeManager = deps.TradeManager
    self.StateManager = deps.StateManager
    self.Utils = deps.Utils
    return self
end

function Tab:Render(parentFrame, statusLabel)
    self.ParentFrame = parentFrame
    self.StatusLabel = statusLabel
    
    local THEME = self.Config.THEME
    
    -- Header
    self.UIFactory.CreateLabel({
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 5),
        Text = "Active Players",
        TextXAlign = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        Parent = parentFrame
    })

    -- List Container
    self.ListContainer = self.UIFactory.CreateScrollingFrame({
        Size = UDim2.new(1, -20, 1, -60),
        Position = UDim2.new(0, 10, 0, 40),
        Parent = parentFrame
    })
    
    local layout = Instance.new("UIListLayout", self.ListContainer)
    layout.Padding = UDim.new(0, 5)
    
    -- Connect Events
    self.Connections = {}
    table.insert(self.Connections, Players.PlayerAdded:Connect(function() self:Refresh() end))
    table.insert(self.Connections, Players.PlayerRemoving:Connect(function() self:Refresh() end))
    
    self:Refresh()
end

function Tab:Refresh()
    if not self.ListContainer or not self.ListContainer.Parent then return end
    
    -- Clear Old
    for _, child in pairs(self.ListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local THEME = self.Config.THEME
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local card = self.UIFactory.CreateFrame({
                Size = UDim2.new(1, -5, 0, 55),
                BgColor = THEME.PanelBg,
                BgTransparency = 0.5,
                Parent = self.ListContainer,
                CornerRadius = 6,
                Stroke = true
            })
            
            -- Avatar
            local avatar = self.UIFactory.CreateImage({
                Size = UDim2.new(0, 40, 0, 40),
                Position = UDim2.new(0, 8, 0, 7),
                Image = "rbxasset://textures/ui/GuiImagePlaceholder.png", -- Default placeholder
                Parent = card,
                CornerRadius = 20
            })
            -- Try load actual avatar
            task.spawn(function()
                local content = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                avatar.Image = content
            end)
            
            -- Name
            self.UIFactory.CreateLabel({
                Text = plr.DisplayName,
                Size = UDim2.new(0, 200, 0, 20),
                Position = UDim2.new(0, 60, 0, 8),
                TextXAlign = Enum.TextXAlignment.Left,
                Font = Enum.Font.GothamBold,
                Parent = card
            })
            
            self.UIFactory.CreateLabel({
                Text = "@" .. plr.Name,
                Size = UDim2.new(0, 200, 0, 15),
                Position = UDim2.new(0, 60, 0, 28),
                TextXAlign = Enum.TextXAlignment.Left,
                TextColor = THEME.TextGray,
                TextSize = 11,
                Parent = card
            })
            
            -- Trade Button
            local btn = self.UIFactory.CreateButton({
                Text = "TRADE",
                Size = UDim2.new(0, 90, 0, 32),
                Position = UDim2.new(1, -100, 0.5, -16),
                BgColor = THEME.BtnMainTab,
                Parent = card,
                OnClick = function()
                    self.TradeManager.ForceTradeWith(plr, self.StatusLabel, self.StateManager, self.Utils)
                end
            })
        end
    end
end

return Tab
