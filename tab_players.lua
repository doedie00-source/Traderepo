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

function Tab:Render(parentFrame)
    local THEME = self.Config.THEME
    
    -- Header
    self.UIFactory.CreateLabel({
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.new(0, 10, 0, 5),
        Text = "Active Players",
        TextXAlign = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        Parent = parentFrame
    })

    -- Scroll List Container
    local container = self.UIFactory.CreateScrollingFrame({
        Size = UDim2.new(1, -20, 1, -50),
        Position = UDim2.new(0, 10, 0, 40),
        Parent = parentFrame
    })
    
    self.ListContainer = container
    self:RefreshList()
end

function Tab:RefreshList()
    -- ล้างลิสต์เก่า
    for _, child in pairs(self.ListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local THEME = self.Config.THEME
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local card = self.UIFactory.CreateFrame({
                Size = UDim2.new(1, -5, 0, 50),
                BgColor = THEME.PanelBg,
                Parent = self.ListContainer,
                CornerRadius = 6
            })
            
            -- Avatar
            local avatar = self.UIFactory.CreateImage({
                Size = UDim2.new(0, 40, 0, 40),
                Position = UDim2.new(0, 5, 0, 5),
                Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100),
                Parent = card,
                CornerRadius = 20
            })
            
            -- Name
            self.UIFactory.CreateLabel({
                Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
                Size = UDim2.new(0, 200, 0, 20),
                Position = UDim2.new(0, 55, 0, 5),
                TextXAlign = Enum.TextXAlignment.Left,
                Parent = card
            })
            
            -- Trade Button
            self.UIFactory.CreateButton({
                Text = "TRADE",
                Size = UDim2.new(0, 80, 0, 30),
                Position = UDim2.new(1, -90, 0.5, -15),
                BgColor = THEME.BtnMainTab,
                Parent = card,
                OnClick = function()
                    -- เรียกใช้ Logic เดิม
                    self.TradeManager.ForceTradeWith(plr, nil, self.StateManager, self.Utils)
                end
            })
        end
    end
end

return Tab
