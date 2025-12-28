-- tabs/players_tab.lua
-- Players Tab Module

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PlayersTab = {}
PlayersTab.__index = PlayersTab

function PlayersTab.new(deps)
    local self = setmetatable({}, PlayersTab)
    
    self.UIFactory = deps.UIFactory
    self.StateManager = deps.StateManager
    self.TradeManager = deps.TradeManager
    self.Utils = deps.Utils
    self.Config = deps.Config
    self.StatusLabel = deps.StatusLabel
    
    self.Container = nil
    self.PlayerButtons = {}
    
    return self
end

function PlayersTab:Init(parent)
    local THEME = self.Config.THEME
    
    -- Header
    local header = self.UIFactory.CreateLabel({
        Parent = parent,
        Text = "👥 Server Players",
        Size = UDim2.new(1, 0, 0, 40),
        TextColor = THEME.TextWhite,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local subHeader = self.UIFactory.CreateLabel({
        Parent = parent,
        Text = "Force trade with any player in the server",
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 40),
        TextColor = THEME.TextDim,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Scrolling Frame
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -70),
        Position = UDim2.new(0, 0, 0, 65)
    })
    
    self:RefreshList()
end

function PlayersTab:RefreshList()
    local THEME = self.Config.THEME
    
    -- Clear old
    for _, child in pairs(self.Container:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    self.PlayerButtons = {}
    
    local isTrading = self.Utils.IsTradeActive()
    local count = 0
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            -- Card Frame
            local card = Instance.new("Frame", self.Container)
            card.Name = plr.Name
            card.Size = UDim2.new(1, 0, 0, 65)
            card.BackgroundColor3 = THEME.CardBg
            card.BackgroundTransparency = 0.3
            card.BorderSizePixel = 0
            
            self.UIFactory.AddCorner(card, 10)
            self.UIFactory.AddStroke(card, THEME.GlassStroke, 1, 0.7)
            
            -- Player Info
            local avatar = Instance.new("ImageLabel", card)
            avatar.Size = UDim2.new(0, 45, 0, 45)
            avatar.Position = UDim2.new(0, 10, 0.5, -22.5)
            avatar.BackgroundTransparency = 1
            avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"
            self.UIFactory.AddCorner(avatar, 10)
            
            local nameLabel = self.UIFactory.CreateLabel({
                Parent = card,
                Text = plr.DisplayName,
                Size = UDim2.new(0, 300, 0, 20),
                Position = UDim2.new(0, 65, 0, 12),
                TextColor = THEME.TextWhite,
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextXAlign = Enum.TextXAlignment.Left
            })
            
            local usernameLabel = self.UIFactory.CreateLabel({
                Parent = card,
                Text = "@" .. plr.Name,
                Size = UDim2.new(0, 300, 0, 16),
                Position = UDim2.new(0, 65, 0, 33),
                TextColor = THEME.TextDim,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlign = Enum.TextXAlignment.Left
            })
            
            -- Trade Button
            local tradeBtn = self.UIFactory.CreateButton({
                Size = UDim2.new(0, 100, 0, 35),
                Position = UDim2.new(1, -110, 0.5, -17.5),
                Text = isTrading and "LOCKED" or "TRADE",
                BgColor = isTrading and THEME.BtnDisabled or THEME.AccentPurple,
                TextColor = isTrading and THEME.TextDisabled or THEME.TextWhite,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                CornerRadius = 8,
                Parent = card
            })
            tradeBtn.AutoButtonColor = not isTrading
            
            table.insert(self.PlayerButtons, tradeBtn)
            tradeBtn:SetAttribute("OriginalColor", THEME.AccentPurple)
            tradeBtn:SetAttribute("OriginalTextColor", THEME.TextWhite)
            
            tradeBtn.MouseButton1Click:Connect(function()
                if self.Utils.IsTradeActive() then
                    self.StateManager:SetStatus("🔒 Trade is active! Finish it first", THEME.Fail, self.StatusLabel)
                    return
                end
                self.TradeManager.ForceTradeWith(plr, self.StatusLabel, self.StateManager, self.Utils)
            end)
            
            count = count + 1
        end
    end
    
    self.Container.CanvasSize = UDim2.new(0, 0, 0, count * 68)
end

function PlayersTab:UpdateButtonStates()
    local THEME = self.Config.THEME
    local tradeActive = self.Utils.IsTradeActive()
    
    for _, btn in pairs(self.PlayerButtons) do
        if btn and btn.Parent then
            if tradeActive then
                btn.BackgroundColor3 = THEME.BtnDisabled
                btn.TextColor3 = THEME.TextDisabled
                btn.Text = "LOCKED"
                btn.AutoButtonColor = false
            else
                if btn:GetAttribute("OriginalColor") then
                    btn.BackgroundColor3 = btn:GetAttribute("OriginalColor")
                end
                if btn:GetAttribute("OriginalTextColor") then
                    btn.TextColor3 = btn:GetAttribute("OriginalTextColor")
                end
                btn.Text = "TRADE"
                btn.AutoButtonColor = true
            end
        end
    end
end

return PlayersTab
