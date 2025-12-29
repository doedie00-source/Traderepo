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
        Size = UDim2.new(1, -8, 0, 28),
        Position = UDim2.new(0, 8, 0, 0),
        TextColor = THEME.TextWhite,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    local subHeader = self.UIFactory.CreateLabel({
        Parent = parent,
        Text = "Force trade with any player in the server",
        Size = UDim2.new(1, -8, 0, 16),
        Position = UDim2.new(0, 8, 0, 28),
        TextColor = THEME.TextDim,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlign = Enum.TextXAlignment.Left
    })
    
    -- Scrolling Frame
    self.Container = self.UIFactory.CreateScrollingFrame({
        Parent = parent,
        Size = UDim2.new(1, 0, 1, -50),
        Position = UDim2.new(0, 0, 0, 48)
    })
    
    self:RefreshList()
end

function PlayersTab:RefreshList()
    local THEME = self.Config.THEME
    
    -- Clear old
    for _, child in pairs(self.Container:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    self.PlayerButtons = {}
    
    -- Add padding to container
    local padding = self.Container:FindFirstChild("UIPadding") or Instance.new("UIPadding", self.Container)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.PaddingTop = UDim.new(0, 4)
    
    local isTrading = self.Utils.IsTradeActive()
    local count = 0
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            -- Card Frame
            local card = Instance.new("Frame", self.Container)
            card.Name = plr.Name
            card.Size = UDim2.new(1, -16, 0, 58)
            card.BackgroundColor3 = THEME.CardBg
            card.BackgroundTransparency = 0.3
            card.BorderSizePixel = 0
            
            self.UIFactory.AddCorner(card, 8)
            self.UIFactory.AddStroke(card, THEME.GlassStroke, 1, 0.7)
            
            -- Player Info
            local avatar = Instance.new("ImageLabel", card)
            avatar.Size = UDim2.new(0, 40, 0, 40)
            avatar.Position = UDim2.new(0, 9, 0.5, -20)
            avatar.BackgroundTransparency = 1
            avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=150&height=150&format=png"
            self.UIFactory.AddCorner(avatar, 8)
            
            local nameLabel = self.UIFactory.CreateLabel({
                Parent = card,
                Text = plr.DisplayName,
                Size = UDim2.new(0, 280, 0, 18),
                Position = UDim2.new(0, 56, 0, 10),
                TextColor = THEME.TextWhite,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextXAlign = Enum.TextXAlignment.Left
            })
            
            local usernameLabel = self.UIFactory.CreateLabel({
                Parent = card,
                Text = "@" .. plr.Name,
                Size = UDim2.new(0, 280, 0, 14),
                Position = UDim2.new(0, 56, 0, 30),
                TextColor = THEME.TextDim,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlign = Enum.TextXAlignment.Left
            })
            
            -- Trade Button
            local tradeBtn = self.UIFactory.CreateButton({
                Size = UDim2.new(0, 85, 0, 32),
                Position = UDim2.new(1, -92, 0.5, -16),
                Text = isTrading and "LOCKED" or "TRADE",
                BgColor = isTrading and THEME.BtnDisabled or THEME.AccentPurple,
                TextColor = isTrading and THEME.TextDisabled or THEME.TextWhite,
                Font = Enum.Font.GothamBold,
                TextSize = 11,
                CornerRadius = 6,
                Parent = card
            })
            tradeBtn.AutoButtonColor = not isTrading
            
            table.insert(self.PlayerButtons, tradeBtn)
            tradeBtn:SetAttribute("OriginalColor", THEME.AccentPurple)
            tradeBtn:SetAttribute("OriginalTextColor", THEME.TextWhite)
            
            -- คัดลอกตั้งแต่ท่อนนี้ไปวางแทนของเก่าได้เลยครับ
            tradeBtn.MouseButton1Click:Connect(function()
                if self.Utils.IsTradeActive() then
                    self.StateManager:SetStatus("🔒 Trade is active! Finish it first", THEME.Fail, self.StatusLabel)
                    return
                end
                
                -- 1. สั่งเริ่มเทรด
                self.TradeManager.ForceTradeWith(plr, self.StatusLabel, self.StateManager, self.Utils)
                
                -- 2. เพิ่มโค้ดเช็คเพื่อสลับหน้า (วาร์ปหน้า)
                task.spawn(function()
                    local timer = 0
                    while timer < 10 do -- เช็คซ้ำๆ เป็นเวลา 5 วินาที
                        if self.Utils.IsTradeActive() then
                            if _G.ModernGUI then 
                                _G.ModernGUI:SwitchTab("Inventory") -- สั่งเปลี่ยนหน้า
                            end
                            break -- เจอแล้วให้หยุดเช็ค
                        end
                        timer = timer + 1
                        task.wait(0.5)
                    end
                end)
            end) -- <--- จบฟังก์ชันปุ่มกด
            
            count = count + 1
        end -- <--- จบ if plr ~= LocalPlayer
    end -- <--- จบ for loop (วนลูปผู้เล่น)
    
    self.Container.CanvasSize = UDim2.new(0, 0, 0, count * 62)
end -- <--- จบฟังก์ชัน RefreshList

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
